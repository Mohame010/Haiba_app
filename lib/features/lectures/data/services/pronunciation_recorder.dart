import 'dart:io';

import 'package:flutter/services.dart';

class RecordedPronunciation {
  const RecordedPronunciation({
    required this.path,
    required this.durationMs,
    required this.fileSizeBytes,
  });

  final String path;
  final int durationMs;
  final int fileSizeBytes;
}

class PronunciationRecorder {
  static const _channel = MethodChannel('q360education/pronunciation_recorder');

  Future<bool> requestPermission() async =>
      await _channel.invokeMethod<bool>('requestPermission') ?? false;

  Future<void> start({
    required String path,
    required int maxDurationSeconds,
  }) async {
    await _channel.invokeMethod<void>('start', {
      'path': path,
      'maxDurationSeconds': maxDurationSeconds,
    });
  }

  Future<double> amplitude() async =>
      await _channel.invokeMethod<double>('amplitude') ?? 0;

  Future<RecordedPronunciation?> stop() async {
    final result = await _channel.invokeMapMethod<String, dynamic>('stop');
    final path = result?['path'] as String?;
    if (path == null || path.isEmpty) return null;

    final file = File(path);
    if (!await file.exists()) return null;
    return RecordedPronunciation(
      path: path,
      durationMs: (result?['durationMs'] as num?)?.toInt() ?? 0,
      fileSizeBytes: await file.length(),
    );
  }
}
