import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NovelListeningQuota {
  static const dailyFreeSeconds = 180;
  static const _boxName = 'novel_listening_usage';

  Future<NovelListeningStatus> loadStatus({DateTime? now}) async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser != null) {
      try {
        await _syncPending(client);
        final raw = await client.rpc('get_library_subscription_status');
        final data = Map<String, dynamic>.from(raw as Map);
        final cache = await _openBox();
        final expiry = (data['plan'] as Map?)?['expires_at'];
        if (expiry != null)
          await cache.put(
            'subscription_expires_at:${client.auth.currentUser!.id}',
            expiry.toString(),
          );
        final plan = data['plan'] as Map?;
        if (plan != null) {
          await cache.put(
            'subscription_limit:${client.auth.currentUser!.id}',
            plan['listening_limit_seconds'],
          );
          await cache.put(
            'subscription_period:${client.auth.currentUser!.id}',
            plan['listening_period']?.toString(),
          );
        }
        return NovelListeningStatus(
          secondsUsed: (data['seconds_used'] as num?)?.toInt() ?? 0,
          hasSubscription: data['has_subscription'] == true,
          allowed: true,
        );
      } catch (_) {
        return _offlineStatus(now: now);
      }
    }
    final box = await _openBox();
    final used = (box.get(_key(now ?? DateTime.now())) as num?)?.toInt() ?? 0;
    return NovelListeningStatus(
      secondsUsed: used,
      hasSubscription: false,
      allowed: used < dailyFreeSeconds,
    );
  }

  Future<NovelListeningStatus> consumeSeconds(
    int seconds, {
    DateTime? now,
  }) async {
    if (seconds < 1 || seconds > 10) {
      throw RangeError.range(seconds, 1, 10, 'seconds');
    }
    final client = Supabase.instance.client;
    if (client.auth.currentUser != null) {
      try {
        await _syncPending(client);
        final raw = await client.rpc(
          'consume_library_listening_seconds',
          params: {'p_seconds': seconds},
        );
        final data = Map<String, dynamic>.from(raw as Map);
        final cache = await _openBox();
        final expiry = (data['plan'] as Map?)?['expires_at'];
        if (expiry != null)
          await cache.put(
            'subscription_expires_at:${client.auth.currentUser!.id}',
            expiry.toString(),
          );
        final plan = data['plan'] as Map?;
        if (plan != null) {
          await cache.put(
            'subscription_limit:${client.auth.currentUser!.id}',
            plan['listening_limit_seconds'],
          );
          await cache.put(
            'subscription_period:${client.auth.currentUser!.id}',
            plan['listening_period']?.toString(),
          );
        }
        return NovelListeningStatus(
          secondsUsed: (data['seconds_used'] as num?)?.toInt() ?? 0,
          hasSubscription: data['has_subscription'] == true,
          allowed: data['allowed'] != false,
        );
      } catch (_) {
        return _offlineConsume(seconds, now: now);
      }
    }
    final box = await _openBox();
    final key = _key(now ?? DateTime.now());
    final current = (box.get(key) as num?)?.toInt() ?? 0;
    if (!_acceptClock(box, now ?? DateTime.now())) {
      return NovelListeningStatus(
        secondsUsed: current,
        hasSubscription: false,
        allowed: false,
      );
    }
    if (current + seconds > dailyFreeSeconds) {
      return NovelListeningStatus(
        secondsUsed: current,
        hasSubscription: false,
        allowed: false,
      );
    }
    final updated = current + seconds;
    await box.put(key, updated);
    return NovelListeningStatus(
      secondsUsed: updated,
      hasSubscription: false,
      allowed: true,
    );
  }

  Future<NovelListeningStatus> _offlineStatus({DateTime? now}) async {
    final box = await _openBox();
    final date = now ?? DateTime.now();
    final used = _offlinePeriodUsed(box, date);
    final subscribed = _offlineSubscriptionActive(box, date);
    final limit = _offlineLimit(box);
    return NovelListeningStatus(
      secondsUsed: used,
      hasSubscription: subscribed,
      allowed: subscribed
          ? (limit == null || used < limit)
          : (used < dailyFreeSeconds && _acceptClock(box, date)),
    );
  }

  Future<NovelListeningStatus> _offlineConsume(
    int seconds, {
    DateTime? now,
  }) async {
    final box = await _openBox();
    final date = now ?? DateTime.now();
    final key = _key(date);
    final current = _offlinePeriodUsed(box, date);
    final subscribed = _offlineSubscriptionActive(box, date);
    final limit = subscribed ? _offlineLimit(box) : dailyFreeSeconds;
    if (!_acceptClock(box, date) ||
        (limit != null && current + seconds > limit)) {
      return NovelListeningStatus(
        secondsUsed: current,
        hasSubscription: subscribed,
        allowed: false,
      );
    }
    await box.put(key, current + seconds);
    await box.put(
      'pending:${Supabase.instance.client.auth.currentUser?.id ?? 'guest'}',
      ((box.get('pending:${Supabase.instance.client.auth.currentUser?.id ?? 'guest'}')
                      as num?)
                  ?.toInt() ??
              0) +
          seconds,
    );
    return NovelListeningStatus(
      secondsUsed: current + seconds,
      hasSubscription: subscribed,
      allowed: true,
    );
  }

  bool _offlineSubscriptionActive(Box<dynamic> box, DateTime date) {
    final id = Supabase.instance.client.auth.currentUser?.id;
    if (id == null) return false;
    final raw = box.get('subscription_expires_at:$id')?.toString();
    final expiry = raw == null ? null : DateTime.tryParse(raw);
    return expiry != null && expiry.isAfter(date.toUtc());
  }

  int? _offlineLimit(Box<dynamic> box) {
    final raw = box.get(
      'subscription_limit:${Supabase.instance.client.auth.currentUser?.id}',
    );
    return raw is num ? raw.toInt() : null;
  }

  int _offlinePeriodUsed(Box<dynamic> box, DateTime date) {
    final period = box
        .get(
          'subscription_period:${Supabase.instance.client.auth.currentUser?.id}',
        )
        ?.toString();
    final start = period == 'week'
        ? date.subtract(Duration(days: date.weekday - 1))
        : date;
    var total = 0;
    for (
      var day = DateTime(start.year, start.month, start.day);
      !day.isAfter(date);
      day = day.add(const Duration(days: 1))
    ) {
      total += (box.get(_key(day)) as num?)?.toInt() ?? 0;
    }
    return total;
  }

  bool _acceptClock(Box<dynamic> box, DateTime date) {
    final epoch = date.millisecondsSinceEpoch;
    final last = (box.get('last_clock_epoch') as num?)?.toInt();
    if (last != null && epoch + 30000 < last) return false;
    box.put('last_clock_epoch', epoch);
    return true;
  }

  Future<void> _syncPending(SupabaseClient client) async {
    final box = await _openBox();
    final key = 'pending:${client.auth.currentUser?.id ?? 'guest'}';
    var pending = (box.get(key) as num?)?.toInt() ?? 0;
    while (pending > 0) {
      final step = pending.clamp(1, 10);
      final raw = await client.rpc(
        'consume_library_listening_seconds',
        params: {'p_seconds': step},
      );
      final data = Map<String, dynamic>.from(raw as Map);
      if (data['allowed'] == false) break;
      pending -= step;
      await box.put(key, pending);
    }
  }

  Future<Box<dynamic>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box<dynamic>(_boxName);
    return Hive.openBox<dynamic>(_boxName);
  }

  String _key(DateTime date) {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    final localDate =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return '$userId:$localDate';
  }
}

class NovelListeningStatus {
  const NovelListeningStatus({
    required this.secondsUsed,
    required this.hasSubscription,
    required this.allowed,
  });

  final int secondsUsed;
  final bool hasSubscription;
  final bool allowed;
}
