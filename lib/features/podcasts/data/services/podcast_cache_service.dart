import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/podcast_entity.dart';

/// Secure local cache service for Podcasts.
/// Caches podcast episodes, audio files, and word timestamps to prevent
/// redundant Supabase calls and allow instant, offline-capable playback.
class PodcastCacheService {
  PodcastCacheService._();
  static final PodcastCacheService instance = PodcastCacheService._();

  Directory? _baseDir;
  final Set<String> _activeAudioDownloads = <String>{};

  Future<Directory> _getBaseDirectory() async {
    if (_baseDir != null && await _baseDir!.exists()) {
      return _baseDir!;
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/podcast_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _baseDir = dir;
    return dir;
  }

  Future<Directory> _getSubDirectory(String name) async {
    final base = await _getBaseDirectory();
    final sub = Directory('${base.path}/$name');
    if (!await sub.exists()) {
      await sub.create(recursive: true);
    }
    return sub;
  }

  /// Atomically writes bytes to [targetFile] via a temporary file to avoid corruption.
  Future<void> _atomicWriteBytes(File targetFile, List<int> bytes) async {
    final tempFile = File('${targetFile.path}.tmp');
    try {
      await tempFile.writeAsBytes(bytes, flush: true);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetFile.path);
    } catch (e) {
      if (await tempFile.exists()) {
        await tempFile.delete().catchError((_) => tempFile);
      }
      rethrow;
    }
  }

  /// Atomically writes string to [targetFile].
  Future<void> _atomicWriteString(File targetFile, String content) async {
    await _atomicWriteBytes(targetFile, utf8.encode(content));
  }

  // ──────────────────────── Episode Metadata Caching ────────────────────────

  /// Saves a podcast episode metadata securely into local cache.
  Future<void> saveEpisode(PodcastEpisode episode) async {
    try {
      if (episode.id.trim().isEmpty) return;
      final dir = await _getSubDirectory('episodes');
      final file = File('${dir.path}/${episode.id}.json');
      final jsonMap = episode.toMap();
      await _atomicWriteString(file, jsonEncode(jsonMap));
    } catch (e) {
      debugPrint('[PodcastCacheService] Error caching episode (${episode.id}): $e');
    }
  }

  /// Retrieves a cached podcast episode by ID, or null if not in cache.
  Future<PodcastEpisode?> getEpisode(String id) async {
    try {
      if (id.trim().isEmpty) return null;
      final dir = await _getSubDirectory('episodes');
      final file = File('${dir.path}/$id.json');
      if (await file.exists() && await file.length() > 0) {
        final content = await file.readAsString();
        final map = jsonDecode(content);
        if (map is Map<String, dynamic>) {
          return PodcastEpisode.fromMap(map);
        } else if (map is Map) {
          return PodcastEpisode.fromMap(Map<String, dynamic>.from(map));
        }
      }
    } catch (e) {
      debugPrint('[PodcastCacheService] Error reading cached episode ($id): $e');
    }
    return null;
  }

  /// Saves the list of episodes to index cache for fast startup & offline use.
  Future<void> saveEpisodesList(List<PodcastEpisode> episodes) async {
    try {
      final base = await _getBaseDirectory();
      final file = File('${base.path}/episodes_index.json');
      final list = episodes.map((e) => e.toMap()).toList();
      await _atomicWriteString(file, jsonEncode(list));

      // Also cache each individual episode
      for (final ep in episodes) {
        unawaited(saveEpisode(ep));
      }
    } catch (e) {
      debugPrint('[PodcastCacheService] Error caching episodes list: $e');
    }
  }

  /// Retrieves the cached episodes list.
  Future<List<PodcastEpisode>> getCachedEpisodesList() async {
    try {
      final base = await _getBaseDirectory();
      final file = File('${base.path}/episodes_index.json');
      if (await file.exists() && await file.length() > 0) {
        final content = await file.readAsString();
        final decoded = jsonDecode(content);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((m) => PodcastEpisode.fromMap(Map<String, dynamic>.from(m)))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[PodcastCacheService] Error reading cached episodes list: $e');
    }
    return const [];
  }

  // ──────────────────────── Audio File Caching ────────────────────────

  /// Returns the local cached audio file for [episodeId] if it exists and is complete.
  Future<File?> getCachedAudioFile(String episodeId) async {
    try {
      if (episodeId.trim().isEmpty) return null;
      final dir = await _getSubDirectory('audio');
      final file = File('${dir.path}/$episodeId.mp3');
      if (await file.exists() && await file.length() > 1024) {
        return file;
      }
    } catch (_) {}
    return null;
  }

  /// Downloads and caches the audio file in the background so future plays
  /// don't consume network bandwidth or require Supabase hits.
  Future<File?> cacheAudioFile(String episodeId, String audioUrl) async {
    if (episodeId.trim().isEmpty || audioUrl.trim().isEmpty) return null;

    final existing = await getCachedAudioFile(episodeId);
    if (existing != null) return existing;

    if (_activeAudioDownloads.contains(episodeId)) {
      return null;
    }

    _activeAudioDownloads.add(episodeId);
    try {
      final cleanUrl = audioUrl.trim().replaceAll(' ', '%20');
      final uri = Uri.tryParse(cleanUrl);
      if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
        return null;
      }

      final response = await http.get(uri).timeout(const Duration(minutes: 5));
      if (response.statusCode == 200 && response.bodyBytes.length > 1024) {
        final dir = await _getSubDirectory('audio');
        final file = File('${dir.path}/$episodeId.mp3');
        await _atomicWriteBytes(file, response.bodyBytes);
        return file;
      }
    } catch (e) {
      debugPrint('[PodcastCacheService] Audio caching failed for $episodeId: $e');
    } finally {
      _activeAudioDownloads.remove(episodeId);
    }
    return null;
  }

  // ──────────────────────── Timestamps Caching ────────────────────────

  /// Retrieves cached timestamps JSON for [episodeId], or downloads & caches them.
  Future<dynamic> getOrFetchTimestamps(PodcastEpisode episode) async {
    // 1. If embedded directly, return
    if (episode.audioTimestampsData != null) {
      unawaited(saveTimestamps(episode.id, episode.audioTimestampsData));
      return episode.audioTimestampsData;
    }

    // 2. Check local disk cache
    try {
      final dir = await _getSubDirectory('timestamps');
      final file = File('${dir.path}/${episode.id}.json');
      if (await file.exists() && await file.length() > 0) {
        final content = await file.readAsString();
        final decoded = jsonDecode(content);
        if (decoded != null) return decoded;
      }
    } catch (_) {}

    // 3. Download from audioTimestampsUrl if available
    final rawUrl = episode.audioTimestampsUrl?.trim();
    if (rawUrl != null && rawUrl.isNotEmpty) {
      try {
        final url = rawUrl.replaceAll(' ', '%20');
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          final decoded = jsonDecode(utf8.decode(res.bodyBytes));
          if (decoded != null) {
            unawaited(saveTimestamps(episode.id, decoded));
            return decoded;
          }
        }
      } catch (e) {
        debugPrint('[PodcastCacheService] Error fetching timestamps for ${episode.id}: $e');
      }
    }

    return null;
  }

  /// Saves timestamps JSON to cache.
  Future<void> saveTimestamps(String episodeId, dynamic timestamps) async {
    try {
      if (episodeId.trim().isEmpty || timestamps == null) return;
      final dir = await _getSubDirectory('timestamps');
      final file = File('${dir.path}/$episodeId.json');
      await _atomicWriteString(file, jsonEncode(timestamps));
    } catch (e) {
      debugPrint('[PodcastCacheService] Error caching timestamps: $e');
    }
  }
}
