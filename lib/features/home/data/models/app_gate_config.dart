import 'dart:convert';

enum AppGateMode { open, maintenance, forceUpdate }

class AppGateDecision {
  const AppGateDecision._(this.mode, this.config);

  const AppGateDecision.open() : this._(AppGateMode.open, null);

  const AppGateDecision.maintenance(AppGateConfig config)
    : this._(AppGateMode.maintenance, config);

  const AppGateDecision.forceUpdate(AppGateConfig config)
    : this._(AppGateMode.forceUpdate, config);

  final AppGateMode mode;
  final AppGateConfig? config;
}

class AppGateConfig {
  const AppGateConfig({
    required this.maintenance,
    required this.updates,
    this.fetchedAt,
  });

  const AppGateConfig.disabled()
    : maintenance = const MaintenanceConfig.disabled(),
      updates = const <String, UpdateConfig>{},
      fetchedAt = null;

  final MaintenanceConfig maintenance;
  final Map<String, UpdateConfig> updates;
  final DateTime? fetchedAt;

  factory AppGateConfig.fromCache(Map<String, dynamic> json) {
    return AppGateConfig(
      maintenance: MaintenanceConfig.fromJson(_asMap(json['maintenance'])),
      updates: _parseUpdates(_asMap(json['updates'])),
      fetchedAt: DateTime.tryParse(json['fetched_at']?.toString() ?? ''),
    );
  }

  /// Applies only rows that arrived and parsed successfully. Missing/malformed
  /// rows retain their cached value, so going offline cannot clear a gate.
  AppGateConfig mergeRows(List<dynamic> rows) {
    var nextMaintenance = maintenance;
    var nextUpdates = updates;

    for (final rawRow in rows) {
      if (rawRow is! Map) continue;
      final row = Map<String, dynamic>.from(rawRow);
      final value = _decodeValue(row['value']);
      if (value == null) continue;

      switch (row['key']) {
        case 'app_maintenance':
          nextMaintenance = MaintenanceConfig.fromJson(value);
        case 'app_force_update':
          nextUpdates = _parseUpdates(value);
      }
    }

    return AppGateConfig(
      maintenance: nextMaintenance,
      updates: nextUpdates,
      fetchedAt: DateTime.now().toUtc(),
    );
  }

  AppGateDecision decide({
    required String platform,
    required String installedVersion,
    required int installedBuild,
  }) {
    if (maintenance.enabled && maintenance.appliesTo(platform)) {
      return AppGateDecision.maintenance(this);
    }

    final update = updates[platform];
    if (update != null &&
        update.enabled &&
        (isVersionLower(installedVersion, update.minimumVersion) ||
            (compareVersions(installedVersion, update.minimumVersion) == 0 &&
                installedBuild < update.minimumBuild))) {
      return AppGateDecision.forceUpdate(this);
    }
    return const AppGateDecision.open();
  }

  UpdateConfig? updateFor(String platform) => updates[platform];

  Map<String, dynamic> toJson() => {
    'maintenance': maintenance.toJson(),
    'updates': updates.map((key, value) => MapEntry(key, value.toJson())),
    'fetched_at': fetchedAt?.toIso8601String(),
  };

  static bool isVersionLower(String current, String minimum) =>
      compareVersions(current, minimum) < 0;

  static int compareVersions(String left, String right) {
    final leftParts = _versionParts(left);
    final rightParts = _versionParts(right);
    final length = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;
    for (var index = 0; index < length; index++) {
      final leftValue = index < leftParts.length ? leftParts[index] : 0;
      final rightValue = index < rightParts.length ? rightParts[index] : 0;
      if (leftValue != rightValue) return leftValue.compareTo(rightValue);
    }
    return 0;
  }

  static List<int> _versionParts(String value) {
    final version = value.split('+').first.split('-').first;
    return version
        .split('.')
        .map(
          (part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        )
        .toList(growable: false);
  }

  static Map<String, UpdateConfig> _parseUpdates(Map<String, dynamic> json) {
    final result = <String, UpdateConfig>{};
    for (final platform in const ['android', 'ios']) {
      final value = _asMap(json[platform]);
      if (value.isNotEmpty) result[platform] = UpdateConfig.fromJson(value);
    }
    return result;
  }

  static Map<String, dynamic>? _decodeValue(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  static Map<String, dynamic> _asMap(dynamic value) => value is Map
      ? Map<String, dynamic>.from(value)
      : const <String, dynamic>{};
}

class MaintenanceConfig {
  const MaintenanceConfig({
    required this.enabled,
    required this.platforms,
    required this.message,
    required this.expectedTime,
  });

  const MaintenanceConfig.disabled()
    : enabled = false,
      platforms = const {'android', 'ios'},
      message = 'نجري بعض التحسينات الآن، وسنعود إليك في أقرب وقت.',
      expectedTime = '';

  factory MaintenanceConfig.fromJson(Map<String, dynamic> json) {
    final rawPlatforms = json['platforms'];
    final platforms = rawPlatforms is List
        ? rawPlatforms.map((item) => item.toString().toLowerCase()).toSet()
        : const {'android', 'ios'};
    return MaintenanceConfig(
      enabled: json['enabled'] == true,
      platforms: platforms,
      message: json['message']?.toString().trim().isNotEmpty == true
          ? json['message'].toString().trim()
          : 'نجري بعض التحسينات الآن، وسنعود إليك في أقرب وقت.',
      expectedTime: json['expected_time']?.toString().trim() ?? '',
    );
  }

  final bool enabled;
  final Set<String> platforms;
  final String message;
  final String expectedTime;

  bool appliesTo(String platform) =>
      platforms.isEmpty || platforms.contains(platform);

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'platforms': platforms.toList(growable: false),
    'message': message,
    'expected_time': expectedTime,
  };
}

class UpdateConfig {
  const UpdateConfig({
    required this.enabled,
    required this.minimumVersion,
    required this.minimumBuild,
    required this.storeUrl,
  });

  factory UpdateConfig.fromJson(Map<String, dynamic> json) => UpdateConfig(
    enabled: json['enabled'] == true,
    minimumVersion: json['minimum_version']?.toString().trim() ?? '0.0.0',
    minimumBuild: int.tryParse(json['minimum_build']?.toString() ?? '') ?? 0,
    storeUrl: json['store_url']?.toString().trim() ?? '',
  );

  final bool enabled;
  final String minimumVersion;
  final int minimumBuild;
  final String storeUrl;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'minimum_version': minimumVersion,
    'minimum_build': minimumBuild,
    'store_url': storeUrl,
  };
}
