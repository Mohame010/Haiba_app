import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class TtsCacheService {
  TtsCacheService._();
  static final TtsCacheService instance = TtsCacheService._();

  Directory? _cacheDir;

  Future<Directory> _getCacheDirectory() async {
    if (_cacheDir != null && await _cacheDir!.exists()) {
      return _cacheDir!;
    }
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/tts_audio_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  /// Returns cached audio file for [word] if exists, or downloads it via Google Translate TTS.
  Future<File?> getOrFetchWordAudio(String word, {String? language}) async {
    final clean = word.trim().toLowerCase();
    if (clean.isEmpty) return null;

    final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(clean);
    final lang = language ?? (isArabic ? 'ar' : 'en');

    final dir = await _getCacheDirectory();
    final hash = md5.convert(utf8.encode('$lang:$clean')).toString();
    final file = File('${dir.path}/$hash.mp3');

    if (await file.exists() && await file.length() > 0) {
      return file;
    }

    try {
      final googleUrl =
          'https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=$lang&q=${Uri.encodeComponent(clean)}';
      final response = await http
          .get(
            Uri.parse(googleUrl),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final tempFile = File('${file.path}.tmp');
        await tempFile.writeAsBytes(response.bodyBytes, flush: true);
        if (await file.exists()) {
          await file.delete();
        }
        await tempFile.rename(file.path);
        return file;
      }
    } catch (_) {
      // Network error or timeout: if temporary file was left, clean it up
    }

    return null;
  }

  /// Pronounces the given [word] using the cached Google Translate TTS audio,
  /// with fallback to direct URL playback if caching fails.
  Future<void> pronounce(
    AudioPlayer player,
    String word, {
    String? language,
    void Function()? onPlaybackStarted,
  }) async {
    final clean = word.trim();
    if (clean.isEmpty) return;

    final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(clean);
    final lang = language ?? (isArabic ? 'ar' : 'en');

    final cachedFile = await getOrFetchWordAudio(clean, language: lang);
    await player.stop();

    if (cachedFile != null && await cachedFile.exists()) {
      await player.setFilePath(cachedFile.path);
    } else {
      // Fallback directly to stream URL
      final googleUrl =
          'https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=$lang&q=${Uri.encodeComponent(clean)}';
      await player.setUrl(googleUrl);
    }

    final completed = player.processingStateStream
        .firstWhere(
          (state) =>
              state == ProcessingState.completed ||
              state == ProcessingState.idle,
        )
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => ProcessingState.completed,
        );

    await player.play();
    onPlaybackStarted?.call();
    await completed;
  }
}
