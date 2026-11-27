import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/app_preferences.dart';
import '../models/app_gate_config.dart';

class AppGateService {
  AppGateService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const _keys = ['app_maintenance', 'app_force_update'];
  final SupabaseClient _client;

  AppGateConfig? readCached() {
    final cached = AppPreferences.getAppGateConfig();
    return cached == null ? null : AppGateConfig.fromCache(cached);
  }

  Future<AppGateConfig?> refresh() async {
    final rows = await _client
        .from('app_settings')
        .select('key,value,updated_at')
        .inFilter('key', _keys)
        .timeout(const Duration(seconds: 4));
    if (rows.isEmpty) return readCached();

    final config = (readCached() ?? const AppGateConfig.disabled()).mergeRows(
      rows,
    );
    await AppPreferences.setAppGateConfig(config.toJson());
    return config;
  }

  Future<AppGateDecision> decide(AppGateConfig? config) async {
    if (config == null) return const AppGateDecision.open();
    final info = await PackageInfo.fromPlatform();
    return config.decide(
      platform: currentPlatform,
      installedVersion: info.version,
      installedBuild: int.tryParse(info.buildNumber) ?? 0,
    );
  }

  static String get currentPlatform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }
}
