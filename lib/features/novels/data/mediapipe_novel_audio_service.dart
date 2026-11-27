import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/network/internet_connection_mixin.dart';
import '../domain/novel_audio_timestamps.dart';

class NovelSpeechAudio {
  const NovelSpeechAudio({
    required this.path,
    required this.duration,
    required this.wordTimestamps,
    this.sourceAudioStart = Duration.zero,
    this.sourceAudioEnd,
  });

  final String path;
  final Duration duration;
  final List<WordTimestamp> wordTimestamps;
  final Duration sourceAudioStart;
  final Duration? sourceAudioEnd;
}

class MediaPipeNovelAudioService with InternetConnectionMixin {
  MediaPipeNovelAudioService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, Future<http.Response>> _serverDownloads = {};
  bool _disposed = false;
  String? _lastPreGeneratedAudioError;

  String? get lastPreGeneratedAudioError => _lastPreGeneratedAudioError;

  /// Downloads and caches pre-generated audio from the server.
  ///
  /// Returns [NovelSpeechAudio] with timestamps if both the audio file and
  /// timestamps JSON are successfully downloaded (or already cached).
  /// Returns `null` on failure and exposes the cause through
  /// [lastPreGeneratedAudioError]. A configured recording must not silently
  /// fall back to on-device TTS.
  Future<NovelSpeechAudio?> downloadPreGeneratedAudio({
    required String audioUrl,
    required String timestampsUrl,
    required String cacheId,
    required String chapterText,
  }) async {
    _checkNotDisposed();
    _lastPreGeneratedAudioError = null;
    // 1. Check local cache first.
    final cached = await loadCached(cacheId);
    if (cached != null) return cached;

    try {
      final supportDirectory = await getApplicationSupportDirectory();
      final safeId = cacheId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final cacheDirectory = Directory(
        '${supportDirectory.path}${Platform.pathSeparator}novel_audio_cache',
      );
      await cacheDirectory.create(recursive: true);
      final extension = _audioFileExtension(audioUrl);
      final audioFile = File(
        '${cacheDirectory.path}${Platform.pathSeparator}novel_voice_$safeId$extension',
      );
      final metadataFile = File('${audioFile.path}.json');

      // 2. Download both files in parallel.
      final audioResponse = _serverDownloads.putIfAbsent(
        audioUrl,
        () => runWithInternetConnection(() => _client.get(Uri.parse(audioUrl))),
      );
      final timestampsResponse = _serverDownloads.putIfAbsent(
        timestampsUrl,
        () => runWithInternetConnection(
          () => _client.get(Uri.parse(timestampsUrl)),
        ),
      );
      final responses = await Future.wait([audioResponse, timestampsResponse]);

      final audioRes = responses[0];
      final tsRes = responses[1];
      if (audioRes.statusCode != 200 || tsRes.statusCode != 200) {
        _lastPreGeneratedAudioError =
            'فشل تنزيل الصوت (${audioRes.statusCode}) أو ملف التوقيت (${tsRes.statusCode}).';
        return null;
      }

      // 3. Parse timestamps first to validate the format.
      final timingData = parseNovelAudioTimings(
        jsonDecode(tsRes.body),
        chapterText: chapterText,
      );
      final timestamps = [
        for (final item in timingData.words)
          WordTimestamp(
            word: item.word,
            start: item.sourceStart,
            end: item.sourceEnd,
            startSeconds: item.startSeconds,
            endSeconds: item.endSeconds,
          ),
      ];

      // 4. Write both files to cache.
      await audioFile.writeAsBytes(audioRes.bodyBytes, flush: true);
      await metadataFile.writeAsString(
        jsonEncode({
          'durationMs': timingData.durationMs,
          'sourceAudioStartMs': timingData.sourceAudioStartMs,
          'sourceAudioEndMs': timingData.sourceAudioEndMs,
          'timestamps': [for (final item in timingData.words) item.toMap()],
        }),
        flush: true,
      );

      return NovelSpeechAudio(
        path: audioFile.path,
        duration: Duration(milliseconds: timingData.durationMs),
        wordTimestamps: timestamps,
        sourceAudioStart: Duration(milliseconds: timingData.sourceAudioStartMs),
        sourceAudioEnd: Duration(milliseconds: timingData.sourceAudioEndMs),
      );
    } catch (error) {
      _lastPreGeneratedAudioError = error.toString();
      return null;
    }
  }

  Future<NovelSpeechAudio> synthesize(
    String text, {
    required String fileId,
    String voiceId = 'lucas',
  }) {
    throw UnsupportedError(
      'تم إيقاف القراءة الصوتية المحلية؛ استخدم تسجيل الفصل من السيرفر.',
    );
  }

  Future<NovelSpeechAudio> synthesizeWord({
    required String word,
    String voiceId = 'lucas',
  }) async {
    throw UnsupportedError(
      'تم إيقاف نطق الكلمات المحلي؛ استخدم صوت الكلمة من مصدر خارجي.',
    );
  }

  Future<NovelSpeechAudio?> loadCached(String fileId) async {
    _checkNotDisposed();
    final supportDirectory = await getApplicationSupportDirectory();
    final safeFileId = fileId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final cacheDirectory = Directory(
      '${supportDirectory.path}${Platform.pathSeparator}novel_audio_cache',
    );
    if (!await cacheDirectory.exists()) return null;
    final prefix =
        '${cacheDirectory.path}${Platform.pathSeparator}novel_voice_$safeFileId.';
    File? file;
    await for (final entity in cacheDirectory.list()) {
      if (entity is File &&
          entity.path.startsWith(prefix) &&
          !entity.path.endsWith('.json') &&
          await File('${entity.path}.json').exists()) {
        file = entity;
        break;
      }
    }
    if (file == null) return null;
    final metadataFile = File('${file.path}.json');
    if (!await file.exists() || !await metadataFile.exists()) return null;
    try {
      final metadata = jsonDecode(await metadataFile.readAsString());
      final timestamps = (metadata['timestamps'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => WordTimestamp(
              word: item['word']?.toString() ?? '',
              start: (item['start'] as num?)?.toInt() ?? 0,
              end: (item['end'] as num?)?.toInt() ?? 0,
              startSeconds: (item['startSeconds'] as num?)?.toDouble() ?? 0,
              endSeconds: (item['endSeconds'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList();
      return NovelSpeechAudio(
        path: file.path,
        duration: Duration(
          milliseconds: (metadata['durationMs'] as num).toInt(),
        ),
        wordTimestamps: timestamps,
        sourceAudioStart: Duration(
          milliseconds: (metadata['sourceAudioStartMs'] as num?)?.toInt() ?? 0,
        ),
        sourceAudioEnd: metadata['sourceAudioEndMs'] is num
            ? Duration(
                milliseconds: (metadata['sourceAudioEndMs'] as num).toInt(),
              )
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<NovelSpeechAudio> extractWordClip({
    required NovelSpeechAudio sourceAudio,
    required String fileId,
    required double startSeconds,
    required double endSeconds,
  }) async {
    _checkNotDisposed();
    final cached = await loadCached(fileId);
    if (cached != null) return cached;
    if (!startSeconds.isFinite ||
        !endSeconds.isFinite ||
        startSeconds < 0 ||
        endSeconds <= startSeconds ||
        endSeconds >
            sourceAudio.duration.inMicroseconds /
                Duration.microsecondsPerSecond) {
      throw RangeError('توقيت مقطع الكلمة خارج مدة صوت الرواية.');
    }

    final supportDirectory = await getApplicationSupportDirectory();
    final safeFileId = fileId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final cacheDirectory = Directory(
      '${supportDirectory.path}${Platform.pathSeparator}novel_audio_cache',
    );
    await cacheDirectory.create(recursive: true);
    final outputFile = File(
      '${cacheDirectory.path}${Platform.pathSeparator}'
      'novel_voice_$safeFileId.wav',
    );
    final metadataFile = File('${outputFile.path}.json');
    final sourceBytes = await File(sourceAudio.path).readAsBytes();
    final clipBytes = await Isolate.run(
      () => extractNovelSpeechWavSegment(
        sourceBytes,
        startSeconds: startSeconds,
        endSeconds: endSeconds,
      ),
    );
    await outputFile.writeAsBytes(clipBytes, flush: true);

    final header = ByteData.sublistView(clipBytes);
    final duration = Duration(
      microseconds:
          (header.getUint32(40, Endian.little) /
                  header.getUint32(28, Endian.little) *
                  Duration.microsecondsPerSecond)
              .round(),
    );
    await metadataFile.writeAsString(
      jsonEncode({
        'durationMs': duration.inMilliseconds,
        'timestamps': const <Object>[],
      }),
      flush: true,
    );
    return NovelSpeechAudio(
      path: outputFile.path,
      duration: duration,
      wordTimestamps: const [],
    );
  }

  void _checkNotDisposed() {
    if (_disposed) throw StateError('خدمة الصوت أُغلقت.');
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _client.close();
    _serverDownloads.clear();
  }
}

String _audioFileExtension(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
  for (final extension in const ['.mp3', '.m4a', '.mp4', '.wav']) {
    if (path.endsWith(extension)) return extension;
  }
  return '.audio';
}

Uint8List extractNovelSpeechWavSegment(
  Uint8List wav, {
  required double startSeconds,
  required double endSeconds,
}) {
  if (!startSeconds.isFinite ||
      !endSeconds.isFinite ||
      startSeconds < 0 ||
      endSeconds <= startSeconds) {
    throw RangeError('توقيت مقطع الكلمة غير صالح.');
  }
  if (wav.length < 44 ||
      String.fromCharCodes(wav.sublist(0, 4)) != 'RIFF' ||
      String.fromCharCodes(wav.sublist(8, 12)) != 'WAVE' ||
      String.fromCharCodes(wav.sublist(12, 16)) != 'fmt ' ||
      String.fromCharCodes(wav.sublist(36, 40)) != 'data') {
    throw const FormatException('ملف صوت الرواية ليس WAV صالحًا.');
  }

  final header = ByteData.sublistView(wav);
  final format = header.getUint16(20, Endian.little);
  final channels = header.getUint16(22, Endian.little);
  final sampleRate = header.getUint32(24, Endian.little);
  final blockAlign = header.getUint16(32, Endian.little);
  final bitsPerSample = header.getUint16(34, Endian.little);
  final dataLength = header.getUint32(40, Endian.little);
  if (format != 1 ||
      channels != 1 ||
      bitsPerSample != 16 ||
      blockAlign != 2 ||
      sampleRate == 0 ||
      header.getUint32(28, Endian.little) != sampleRate * blockAlign ||
      dataLength > wav.length - 44) {
    throw const FormatException('صيغة صوت الرواية غير مدعومة لقصّ الكلمة.');
  }

  final totalSamples = dataLength ~/ blockAlign;
  final firstSample = (startSeconds * sampleRate).floor().clamp(
    0,
    totalSamples,
  );
  final lastSample = (endSeconds * sampleRate).ceil().clamp(
    firstSample,
    totalSamples,
  );
  if (lastSample <= firstSample) {
    throw const FormatException('مقطع الكلمة فارغ.');
  }

  final firstByte = 44 + firstSample * blockAlign;
  final clipLength = (lastSample - firstSample) * blockAlign;
  final clip = Uint8List(44 + clipLength);
  clip.setRange(0, 44, wav);
  clip.setRange(44, clip.length, wav, firstByte);
  final clipHeader = ByteData.sublistView(clip);
  clipHeader.setUint32(4, 36 + clipLength, Endian.little);
  clipHeader.setUint32(28, sampleRate * blockAlign, Endian.little);
  clipHeader.setUint32(40, clipLength, Endian.little);
  return clip;
}

Uint8List encodeNovelSpeechWav(Float32List samples, int sampleRate) {
  final dataLength = samples.length * 2;
  final bytes = Uint8List(44 + dataLength);
  final header = ByteData.sublistView(bytes);
  void writeAscii(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      bytes[offset + index] = value.codeUnitAt(index);
    }
  }

  writeAscii(0, 'RIFF');
  header.setUint32(4, 36 + dataLength, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  writeAscii(36, 'data');
  header.setUint32(40, dataLength, Endian.little);
  for (var index = 0; index < samples.length; index++) {
    final pcm = (samples[index].clamp(-1, 1) * 32767).round();
    header.setInt16(44 + index * 2, pcm, Endian.little);
  }
  return bytes;
}

Uint8List encodeCompactNovelWordWav(Float32List samples, int sampleRate) {
  const targetRate = 12000;
  if (sampleRate <= targetRate) {
    return encodeNovelSpeechWav(samples, sampleRate);
  }
  final ratio = sampleRate / targetRate;
  final compact = Float32List((samples.length / ratio).ceil());
  for (var index = 0; index < compact.length; index++) {
    final start = (index * ratio).floor();
    final end = math.min(((index + 1) * ratio).ceil(), samples.length);
    var sum = 0.0;
    for (var source = start; source < end; source++) {
      sum += samples[source];
    }
    compact[index] = end > start ? sum / (end - start) : 0;
  }
  return encodeNovelSpeechWav8Bit(compact, targetRate);
}

Uint8List encodeNovelSpeechWav8Bit(Float32List samples, int sampleRate) {
  final dataLength = samples.length;
  final bytes = Uint8List(44 + dataLength);
  final header = ByteData.sublistView(bytes);
  void writeAscii(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      bytes[offset + index] = value.codeUnitAt(index);
    }
  }

  writeAscii(0, 'RIFF');
  header.setUint32(4, 36 + dataLength, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate, Endian.little);
  header.setUint16(32, 1, Endian.little);
  header.setUint16(34, 8, Endian.little);
  writeAscii(36, 'data');
  header.setUint32(40, dataLength, Endian.little);
  for (var index = 0; index < samples.length; index++) {
    final normalized = samples[index].clamp(-1.0, 1.0).toDouble();
    bytes[44 + index] = ((normalized + 1) * 127.5)
        .round()
        .clamp(0, 255)
        .toInt();
  }
  return bytes;
}
