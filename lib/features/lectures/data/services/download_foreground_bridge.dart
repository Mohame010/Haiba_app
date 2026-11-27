import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class DownloadForegroundBridge {
  DownloadForegroundBridge._();

  static const MethodChannel _channel = MethodChannel(
    'q360education/downloads',
  );
  static final StreamController<String> _cancelRequests =
      StreamController<String>.broadcast();
  static bool _initialized = false;

  static Stream<String> get cancelRequests => _cancelRequests.stream;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'cancelRequested') {
        final id = call.arguments?.toString();
        if (id != null && id.isNotEmpty) _cancelRequests.add(id);
      }
    });
    if (Platform.isAndroid) await _channel.invokeMethod<void>('ready');
  }

  static Future<void> start(String lectureId, String title) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('start', {
      'lectureId': lectureId,
      'title': title,
    });
  }

  static Future<void> update(
    String lectureId,
    String title,
    double progress,
  ) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('progress', {
      'lectureId': lectureId,
      'title': title,
      'progress': (progress * 100).round().clamp(0, 100),
    });
  }

  static Future<void> complete(String lectureId, String title) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('complete', {
      'lectureId': lectureId,
      'title': title,
    });
  }

  static Future<void> stop(String lectureId) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('stop', {'lectureId': lectureId});
  }

  static Future<String> downloadIosHls({
    required String lectureId,
    required String title,
    required String url,
    required void Function(double progress) onProgress,
    required bool Function() isCancelled,
  }) async {
    if (!Platform.isIOS) throw UnsupportedError('iOS only');
    await _channel.invokeMethod<void>('startIosHls', {
      'lectureId': lectureId,
      'title': title,
      'url': url,
    });

    while (true) {
      if (isCancelled()) {
        await _channel.invokeMethod<void>('cancelIosHls', {
          'lectureId': lectureId,
        });
        throw const IosDownloadCancelledException();
      }
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'iosDownloadStatus',
        {'lectureId': lectureId},
      );
      final status = raw?['status']?.toString() ?? 'downloading';
      final progress = (raw?['progress'] as num?)?.toDouble() ?? 0;
      onProgress(progress.clamp(0, 1));
      if (status == 'completed') {
        final path = raw?['path']?.toString();
        if (path == null || path.isEmpty) {
          throw StateError('اكتمل تنزيل iOS بدون مسار محلي');
        }
        return path;
      }
      if (status == 'failed' || status == 'cancelled') {
        throw StateError(raw?['error']?.toString() ?? 'فشل تنزيل الفيديو');
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }
}

class IosDownloadCancelledException implements Exception {
  const IosDownloadCancelledException();
}
