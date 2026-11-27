import 'dart:math';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';

class PlatformFeedbackDraft {
  final int platformRating;
  final String platformFeedback;
  final int lecturerRating;
  final String lecturerFeedback;
  final String learningSuggestion;

  const PlatformFeedbackDraft({
    required this.platformRating,
    required this.platformFeedback,
    required this.lecturerRating,
    required this.lecturerFeedback,
    required this.learningSuggestion,
  });
}

class PlatformFeedbackService {
  PlatformFeedbackService._();

  static final instance = PlatformFeedbackService._();
  static const _boxName = 'platform_feedback';
  static const _pendingKey = 'pending_submissions';
  static const _period = Duration(days: 7);
  static const initialFeedbackDelay = Duration(days: 3);

  static bool isInitialFeedbackEligible({
    required DateTime accountCreatedAt,
    DateTime? now,
  }) {
    final currentTime = (now ?? DateTime.now()).toUtc();
    return !currentTime.isBefore(
      accountCreatedAt.toUtc().add(initialFeedbackDelay),
    );
  }

  Future<Box<dynamic>> get _box async => Hive.isBoxOpen(_boxName)
      ? Hive.box<dynamic>(_boxName)
      : Hive.openBox<dynamic>(_boxName);

  String _userKey(String prefix, String userId) => '${prefix}_$userId';

  Future<bool> isDue(String userId) async {
    final box = await _box;
    final raw = box.get(_userKey('last_prompt_at', userId)) as String?;
    final lastPrompt = raw == null ? null : DateTime.tryParse(raw);
    return lastPrompt == null ||
        DateTime.now().difference(lastPrompt) >= _period;
  }

  Future<bool> hasCompletedInitialFeedback(String userId) async {
    final box = await _box;
    return box.get(_userKey('completed_initial', userId), defaultValue: false)
        as bool;
  }

  Future<void> refreshStatusFromRemote(String userId) async {
    try {
      final rows = await Supabase.instance.client
          .from('platform_feedback')
          .select('submitted_at')
          .eq('user_id', userId)
          .order('submitted_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return;
      final submittedAt = rows.first['submitted_at'] as String?;
      final box = await _box;
      await box.put(_userKey('completed_initial', userId), true);
      if (submittedAt != null &&
          box.get(_userKey('last_prompt_at', userId)) == null) {
        await box.put(_userKey('last_prompt_at', userId), submittedAt);
      }
    } catch (_) {
      // Local state remains authoritative while offline.
    }
  }

  Future<void> markSkipped(String userId) async {
    final box = await _box;
    await box.put(
      _userKey('last_prompt_at', userId),
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  /// Returns true when the submission reached Supabase immediately. A false
  /// result means it is safely queued locally and will be retried.
  Future<bool> submit({
    required String userId,
    required String studentName,
    required PlatformFeedbackDraft draft,
  }) async {
    final now = DateTime.now().toUtc();
    final random = Random.secure();
    final payload = <String, dynamic>{
      'client_submission_id':
          '$userId-${now.microsecondsSinceEpoch}-${random.nextInt(1 << 32)}',
      'user_id': userId,
      'student_name': studentName.trim(),
      'teacher_id': AppConstants.activeTeacherId,
      'platform_rating': draft.platformRating,
      'platform_feedback': draft.platformFeedback.trim(),
      'lecturer_rating': draft.lecturerRating,
      'lecturer_feedback': draft.lecturerFeedback.trim(),
      'learning_suggestion': draft.learningSuggestion.trim(),
      'submitted_at': now.toIso8601String(),
    };

    final box = await _box;
    final pending = _pending(box)..add(payload);
    await box.put(_pendingKey, pending);
    await box.put(_userKey('completed_initial', userId), true);
    await box.put(_userKey('last_prompt_at', userId), now.toIso8601String());

    return (await syncPending()) > 0;
  }

  Future<int> syncPending() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return 0;

    final box = await _box;
    final pending = _pending(box);
    if (pending.isEmpty) return 0;

    var uploaded = 0;
    final remaining = <Map<String, dynamic>>[];
    for (final payload in pending) {
      if (payload['user_id'] != currentUserId) {
        remaining.add(payload);
        continue;
      }
      try {
        await Supabase.instance.client
            .from('platform_feedback')
            .upsert(payload, onConflict: 'client_submission_id');
        uploaded++;
      } catch (_) {
        remaining.add(payload);
      }
    }
    await box.put(_pendingKey, remaining);
    return uploaded;
  }

  List<Map<String, dynamic>> _pending(Box<dynamic> box) {
    final raw = box.get(_pendingKey, defaultValue: const <dynamic>[]);
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
