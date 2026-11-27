import 'package:flutter/services.dart';

/// Reference-counted protection keeps nested protected routes secure.
class ScreenProtectionService {
  ScreenProtectionService._();

  static const _channel = MethodChannel('q360education/screen_protection');
  static int _holders = 0;

  static Future<void> acquire() async {
    _holders++;
    if (_holders != 1) return;
    try {
      await _channel.invokeMethod<void>('enable');
    } catch (_) {}
  }

  static Future<void> release() async {
    if (_holders > 0) _holders--;
    if (_holders != 0) return;
    try {
      await _channel.invokeMethod<void>('disable');
    } catch (_) {}
  }
}
