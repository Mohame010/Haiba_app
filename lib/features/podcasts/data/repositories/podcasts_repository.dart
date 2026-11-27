import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/podcast_entity.dart';
import '../services/podcast_cache_service.dart';

class PodcastsRepository {
  PodcastsRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Fetches published podcast episodes directly from the Supabase `podcasts` table,
  /// with automatic offline caching and fallback.
  Future<List<PodcastEpisode>> fetchEpisodes({
    String? category,
    bool? isFeatured,
    int? limit,
    int? offset,
  }) async {
    try {
      var query = _client.from('podcasts').select().eq('is_published', true);

      if (category != null && category.trim().isNotEmpty) {
        query = query.eq('category', category.trim());
      }
      if (isFeatured != null) {
        query = query.eq('is_featured', isFeatured);
      }

      var orderedQuery = query
          .order('sort_order', ascending: true)
          .order('created_at', ascending: false);

      if (offset != null && limit != null) {
        orderedQuery = orderedQuery.range(offset, offset + limit - 1);
      } else if (limit != null) {
        orderedQuery = orderedQuery.limit(limit);
      }

      final rows = await orderedQuery;

      final resolvedRows = await Future.wait(
        rows.whereType<Map>().map(
          (row) => _resolveRowMedia(Map<String, dynamic>.from(row)),
        ),
      );

      final episodes = resolvedRows.map(PodcastEpisode.fromMap).toList();
      if (category == null &&
          isFeatured == null &&
          (offset == null || offset == 0)) {
        unawaited(PodcastCacheService.instance.saveEpisodesList(episodes));
      }
      return episodes;
    } catch (e, stack) {
      debugPrint(
        '[PodcastsRepository] Error fetching podcasts from Supabase: $e\n$stack',
      );
      // Offline fallback: load from secure local cache
      final cached = await PodcastCacheService.instance.getCachedEpisodesList();
      if (cached.isNotEmpty) {
        return cached;
      }
      return const [];
    }
  }

  /// Fetches a single podcast episode by its unique id, prioritizing local secure cache
  /// to minimize redundant Supabase network requests.
  Future<PodcastEpisode?> fetchEpisodeById(String id) async {
    try {
      final cached = await PodcastCacheService.instance.getEpisode(id);
      if (cached != null) {
        return cached;
      }

      final row = await _client
          .from('podcasts')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (row != null) {
        final resolved = await _resolveRowMedia(Map<String, dynamic>.from(row));
        final episode = PodcastEpisode.fromMap(resolved);
        unawaited(PodcastCacheService.instance.saveEpisode(episode));
        return episode;
      }
    } catch (e, stack) {
      debugPrint(
        '[PodcastsRepository] Error fetching podcast episode ($id): $e\n$stack',
      );
      return await PodcastCacheService.instance.getEpisode(id);
    }
    return null;
  }

  /// Fetches all distinct categories of published podcasts from Supabase.
  Future<List<String>> fetchCategories() async {
    try {
      final rows = await _client
          .from('podcasts')
          .select('category')
          .eq('is_published', true);

      final categories = <String>{};
      for (final r in rows) {
        final cat = r['category']?.toString();
        if (cat != null && cat.trim().isNotEmpty) {
          categories.add(cat.trim());
        }
      }
      return categories.toList();
    } catch (e) {
      debugPrint('[PodcastsRepository] Error fetching categories: $e');
      return const [];
    }
  }

  /// Resolves media fields safely without breaking full public URLs.
  Future<Map<String, dynamic>> _resolveRowMedia(
    Map<String, dynamic> row,
  ) async {
    final copy = Map<String, dynamic>.from(row);

    copy['audio_url'] = await _resolveMediaUrl(
      copy['audio_url']?.toString(),
      defaultBucket: 'podcasts',
    );

    if (copy['cover_url'] != null) {
      copy['cover_url'] = await _resolveMediaUrl(
        copy['cover_url']?.toString(),
        defaultBucket: 'podcasts',
      );
    }

    if (copy['audio_timestamps_url'] != null) {
      copy['audio_timestamps_url'] = await _resolveMediaUrl(
        copy['audio_timestamps_url']?.toString(),
        defaultBucket: 'podcasts',
      );
    }

    final segments = copy['video_segments'];
    if (segments is List) {
      copy['video_segments'] = await Future.wait(
        segments.map((seg) async {
          if (seg is Map) {
            final segCopy = Map<String, dynamic>.from(seg);
            segCopy['video_url'] = await _resolveMediaUrl(
              segCopy['video_url']?.toString(),
              defaultBucket: 'podcasts',
            );
            if (segCopy['thumbnail_url'] != null) {
              segCopy['thumbnail_url'] = await _resolveMediaUrl(
                segCopy['thumbnail_url']?.toString(),
                defaultBucket: 'podcasts',
              );
            }
            return segCopy;
          }
          return seg;
        }),
      );
    }

    return copy;
  }

  /// Resolves URLs and paths:
  /// - If already an http/https URL, preserves it and ensures spaces are encoded (%20).
  /// - If a relative path, generates signed/public URL from storage.
  Future<String> _resolveMediaUrl(
    String? value, {
    String defaultBucket = 'podcasts',
  }) async {
    if (value == null || value.trim().isEmpty) return '';
    final trimmed = value.trim();

    // 1. If it's already a full HTTP/HTTPS URL, preserve it untouched!
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed.replaceAll(' ', '%20');
    }

    // 2. Relative storage path
    var clean = trimmed.replaceFirst(RegExp(r'^/+'), '');
    String bucket = defaultBucket;
    String objectPath = clean;

    if (clean.startsWith('novel-audio/')) {
      bucket = 'novel-audio';
      objectPath = clean.substring('novel-audio/'.length);
    } else if (clean.startsWith('podcasts/')) {
      bucket = 'podcasts';
      objectPath = clean.substring('podcasts/'.length);
    }

    // Try signed URL first
    try {
      final signedUrl = await _client.storage
          .from(bucket)
          .createSignedUrl(objectPath, 86400);
      if (signedUrl.isNotEmpty) {
        return signedUrl.replaceAll(' ', '%20');
      }
    } catch (_) {}

    // Fallback to public URL
    try {
      final publicUrl = _client.storage.from(bucket).getPublicUrl(objectPath);
      return publicUrl.replaceAll(' ', '%20');
    } catch (_) {
      return trimmed.replaceAll(' ', '%20');
    }
  }
}
