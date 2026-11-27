import 'dart:math';
import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

class AppPreferences {
  static const String _boxName = 'app_preferences';
  static const String _onboardingKey = 'is_onboarding_completed';
  static const String _deviceIdKey = 'device_installation_id';
  static const String _forcedLogoutMessageKey = 'forced_logout_message';
  static const String _whatToExpectSeenKey = 'what_to_expect_seen';
  static const String _appGateConfigKey = 'app_gate_config_v1';

  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  static bool isOnboardingCompleted() {
    if (!Hive.isBoxOpen(_boxName)) {
      return false;
    }
    final box = Hive.box(_boxName);
    return box.get(_onboardingKey, defaultValue: false) as bool;
  }

  static Future<void> setOnboardingCompleted(bool completed) async {
    final box = Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);
    await box.put(_onboardingKey, completed);
  }

  static bool hasSeenWhatToExpect() {
    if (!Hive.isBoxOpen(_boxName)) return false;
    return Hive.box(_boxName).get(_whatToExpectSeenKey, defaultValue: false)
        as bool;
  }

  static Future<void> setWhatToExpectSeen() async {
    final box = Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);
    await box.put(_whatToExpectSeenKey, true);
  }

  static Future<String> getOrCreateDeviceId() async {
    final box = Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);
    final savedId = box.get(_deviceIdKey) as String?;
    if (savedId != null && savedId.isNotEmpty) return savedId;

    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    final generatedId = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    await box.put(_deviceIdKey, generatedId);
    return generatedId;
  }

  static Future<void> setForcedLogoutMessage(String message) async {
    final box = Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);
    await box.put(_forcedLogoutMessageKey, message);
  }

  static Future<String?> takeForcedLogoutMessage() async {
    final box = Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);
    final message = box.get(_forcedLogoutMessageKey) as String?;
    await box.delete(_forcedLogoutMessageKey);
    return message;
  }

  static Map<String, dynamic>? getAppGateConfig() {
    if (!Hive.isBoxOpen(_boxName)) return null;
    final raw = Hive.box(_boxName).get(_appGateConfigKey) as String?;
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } on FormatException {
      return null;
    }
  }

  static Future<void> setAppGateConfig(Map<String, dynamic> config) async {
    final box = Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);
    await box.put(_appGateConfigKey, jsonEncode(config));
  }
}
