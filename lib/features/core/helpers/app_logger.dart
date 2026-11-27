import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger._();

  static void log(
    String message, {
    String name = 'Q360_APP',
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      developer.log(message, name: name, error: error, stackTrace: stackTrace);
      // Also print to console for direct IDE terminal visibility
      debugPrint('[$name] $message');
      if (error != null) {
        debugPrint('[$name] [ERROR] $error');
      }
    }
  }

  static void authLog(
    String message, {
    Object? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      final buffer = StringBuffer('🔐 [AUTH] $message');
      if (data != null) {
        buffer.write('\n📦 Data: $data');
      }
      if (error != null) {
        buffer.write('\n❌ Error: $error');
      }
      if (stackTrace != null) {
        buffer.write('\n📍 StackTrace: $stackTrace');
      }
      debugPrint(buffer.toString());
    }
  }

  static String maskedPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 4) return '***';
    return '***${digits.substring(digits.length - 4)}';
  }
}
