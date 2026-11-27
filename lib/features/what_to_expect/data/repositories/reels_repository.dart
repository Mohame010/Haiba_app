import 'dart:convert';
import 'dart:math';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/reel_entity.dart';
import '../models/reel_model.dart';

class ReelsPage {
  final List<ReelEntity> reels;
  final bool hasMore;

  const ReelsPage({required this.reels, required this.hasMore});
}

class ReelsAuthRequired implements Exception {
  const ReelsAuthRequired();
}

class ReelLikeSnapshot {
  final bool isLiked;
  final int likesCount;

  const ReelLikeSnapshot({required this.isLiked, required this.likesCount});
}

abstract interface class ReelsRepositoryContract {
  bool get isAuthenticated;

  Future<ReelsPage> getPage({int? beforeSequence});

  Future<ReelEntity?> getRandom();

  Future<List<ReelEntity>> getCached();

  ReelEntity? randomFrom(List<ReelEntity> reels);

  Future<ReelLikeSnapshot> setLiked(String reelId, {required bool liked});
}

class ReelsRepository implements ReelsRepositoryContract {
  static const _cacheBoxName = 'what_to_expect_cache';
  static const _cacheKey = 'latest_reels';
  static const pageSize = 8;

  final SupabaseClient _client;

  ReelsRepository(this._client);

  @override
  bool get isAuthenticated => _client.auth.currentUser != null;

  @override
  Future<ReelsPage> getPage({int? beforeSequence}) async {
    final List<dynamic> rows;
    const columns =
        'id, sequence_id, title, description, video_url, thumbnail_url, '
        'duration_seconds, likes_count';
    if (beforeSequence == null) {
      rows = await _client
          .from('reels')
          .select(columns)
          .eq('is_published', true)
          .order('sequence_id', ascending: false)
          .limit(pageSize);
    } else {
      rows = await _client
          .from('reels')
          .select(columns)
          .eq('is_published', true)
          .lt('sequence_id', beforeSequence)
          .order('sequence_id', ascending: false)
          .limit(pageSize);
    }
    final reels = await _withLikeState(rows);
    if (beforeSequence == null && reels.isNotEmpty) {
      await _cache(reels);
    }
    return ReelsPage(reels: reels, hasMore: rows.length == pageSize);
  }

  @override
  Future<ReelEntity?> getRandom() async {
    final rows = await _client.rpc('get_random_reel');
    if (rows is! List || rows.isEmpty) return null;
    return (await _withLikeState(rows)).firstOrNull;
  }

  @override
  Future<List<ReelEntity>> getCached() async {
    try {
      final box = Hive.isBoxOpen(_cacheBoxName)
          ? Hive.box(_cacheBoxName)
          : await Hive.openBox(_cacheBoxName);
      final raw = box.get(_cacheKey) as String?;
      if (raw == null) return const [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (item) => ReelModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ).toEntity(),
          )
          .where((item) => item.id.isNotEmpty && item.videoUrl.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  @override
  ReelEntity? randomFrom(List<ReelEntity> reels) =>
      reels.isEmpty ? null : reels[Random.secure().nextInt(reels.length)];

  @override
  Future<ReelLikeSnapshot> setLiked(
    String reelId, {
    required bool liked,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const ReelsAuthRequired();
    final result = await _client.rpc(
      'set_reel_like',
      params: {'p_reel_id': reelId, 'p_liked': liked},
    );
    final Map<String, dynamic> row;
    if (result is List && result.isNotEmpty) {
      row = Map<String, dynamic>.from(result.first as Map);
    } else if (result is Map) {
      row = Map<String, dynamic>.from(result);
    } else {
      throw const FormatException('Invalid reel like response');
    }
    return ReelLikeSnapshot(
      isLiked: row['is_liked'] as bool? ?? liked,
      likesCount: (row['likes_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<List<ReelEntity>> _withLikeState(List<dynamic> rows) async {
    final models = rows
        .map((row) => ReelModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .where((model) => model.id.isNotEmpty && model.videoUrl.isNotEmpty)
        .toList(growable: false);
    final user = _client.auth.currentUser;
    if (user == null || models.isEmpty) {
      return models.map((model) => model.toEntity()).toList(growable: false);
    }
    final likeRows = await _client
        .from('reel_likes')
        .select('reel_id')
        .eq('user_id', user.id)
        .inFilter('reel_id', models.map((model) => model.id).toList());
    final likedIds = (likeRows as List<dynamic>)
        .map((row) => (row as Map)['reel_id'] as String?)
        .whereType<String>()
        .toSet();
    return models
        .map((model) => model.toEntity(isLiked: likedIds.contains(model.id)))
        .toList(growable: false);
  }

  Future<void> _cache(List<ReelEntity> reels) async {
    try {
      final box = Hive.isBoxOpen(_cacheBoxName)
          ? Hive.box(_cacheBoxName)
          : await Hive.openBox(_cacheBoxName);
      final models = reels.map(
        (item) => {
          'id': item.id,
          'sequence_id': item.sequenceId,
          'title': item.title,
          'description': item.description,
          'video_url': item.videoUrl,
          'thumbnail_url': item.thumbnailUrl,
          'duration_seconds': item.durationSeconds,
          'likes_count': item.likesCount,
        },
      );
      await box.put(_cacheKey, jsonEncode(models.toList()));
    } catch (_) {
      // A cache failure must never block the feed.
    }
  }
}
