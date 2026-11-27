import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/app_logger.dart';
import '../routing/app_router.dart';
import 'app_preferences.dart';
import 'notifcations/firebase_messaging_service.dart';

class DeviceSessionService with WidgetsBindingObserver {
  final SupabaseClient _client;
  final DeviceInfoPlugin _deviceInfo;

  RealtimeChannel? _deviceChannel;
  String? _deviceId;
  bool _isForcingLogout = false;

  DeviceSessionService(this._client, {DeviceInfoPlugin? deviceInfo})
    : _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  String? get deviceId => _deviceId;

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    _deviceId = await AppPreferences.getOrCreateDeviceId();
    if (_client.auth.currentUser != null) {
      await validateCurrentDevice();
    }
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _removeDeviceChannel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _client.auth.currentUser != null) {
      unawaited(validateCurrentDevice());
    }
  }

  Future<void> registerCurrentDevice() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('يجب تسجيل الدخول أولاً');
    }

    final currentDeviceId = _deviceId ??=
        await AppPreferences.getOrCreateDeviceId();
    try {
      await _client.rpc(
        'register_student_device',
        params: {
          'p_device_id': currentDeviceId,
          'p_device_name': await _getDeviceName(),
        },
      );
      await _subscribeToCurrentDevice(user.id, currentDeviceId);
      AppLogger.authLog(
        'Device session registered',
        data: {'userId': user.id, 'deviceId': _maskedDeviceId(currentDeviceId)},
      );
    } catch (error, stackTrace) {
      AppLogger.authLog(
        'Device session registration failed',
        error: error,
        stackTrace: stackTrace,
      );
      await _client.auth.signOut(scope: SignOutScope.local);
      final isBlocked =
          error is PostgrestException &&
          error.message.toLowerCase().contains('student_blocked');
      throw AuthException(
        isBlocked
            ? 'تم حظر حسابك بواسطة المدرس'
            : 'تعذر تسجيل هذا الجهاز، يرجى المحاولة مرة أخرى',
      );
    }
  }

  Future<bool> validateCurrentDevice() async {
    final user = _client.auth.currentUser;
    if (user == null || _isForcingLogout) return false;

    final currentDeviceId = _deviceId ??=
        await AppPreferences.getOrCreateDeviceId();
    try {
      final result = await _client.rpc(
        'validate_student_device',
        params: {'p_device_id': currentDeviceId},
      );
      final isValid = result == true;
      if (!isValid) {
        await _forceLocalLogout(
          message: 'انتهت جلستك، أعد تسجيل الدخول مرة أخرى',
        );
        return false;
      }
      await _subscribeToCurrentDevice(user.id, currentDeviceId);
      return true;
    } catch (error, stackTrace) {
      // A temporary network outage must not destroy a valid local session.
      AppLogger.authLog(
        'Device session validation deferred',
        error: error,
        stackTrace: stackTrace,
      );
      return true;
    }
  }

  Future<void> signOutCurrentDevice() async {
    await FirebaseMessagingService.instance.unregisterCurrentDevice();
    final currentDeviceId = _deviceId ??=
        await AppPreferences.getOrCreateDeviceId();
    if (_client.auth.currentUser != null) {
      try {
        await _client
            .rpc(
              'deactivate_student_device',
              params: {'p_device_id': currentDeviceId},
            )
            .timeout(const Duration(seconds: 3));
      } catch (error) {
        AppLogger.authLog(
          'Could not deactivate device before logout',
          error: error,
        );
      }
    }
    try {
      await _removeDeviceChannel().timeout(const Duration(seconds: 2));
    } catch (error) {
      AppLogger.authLog(
        'Could not remove device channel before logout',
        error: error,
      );
    }
    await _client.auth
        .signOut(scope: SignOutScope.local)
        .timeout(const Duration(seconds: 5));
  }

  Future<void> _subscribeToCurrentDevice(
    String userId,
    String currentDeviceId,
  ) async {
    await _removeDeviceChannel();
    _deviceChannel = _client
        .channel('student-device-$userId-$currentDeviceId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'student_devices',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'device_id',
            value: currentDeviceId,
          ),
          callback: (payload) {
            if (payload.newRecord['is_active'] == false) {
              final isBlocked =
                  payload.newRecord['revocation_reason'] == 'blocked';
              unawaited(
                _forceLocalLogout(
                  message: isBlocked
                      ? 'تم حظر حسابك بواسطة المدرس'
                      : 'انتهت جلستك، أعد تسجيل الدخول مرة أخرى',
                ),
              );
            }
          },
        )
        .subscribe();
  }

  Future<void> _forceLocalLogout({
    String message = 'انتهت جلستك، أعد تسجيل الدخول مرة أخرى',
  }) async {
    if (_isForcingLogout) return;
    _isForcingLogout = true;
    try {
      await FirebaseMessagingService.instance.unregisterCurrentDevice();
      await _removeDeviceChannel();
      await AppPreferences.setForcedLogoutMessage(message);
      await _client.auth.signOut(scope: SignOutScope.local);
      AppRouter.pushLoginAndClearStack();
    } finally {
      _isForcingLogout = false;
    }
  }

  Future<void> _removeDeviceChannel() async {
    final channel = _deviceChannel;
    _deviceChannel = null;
    if (channel != null) {
      await _client.removeChannel(channel);
    }
  }

  Future<String> _getDeviceName() async {
    try {
      if (kIsWeb) {
        final info = await _deviceInfo.webBrowserInfo;
        return '${info.browserName.name} - Web';
      }
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final info = await _deviceInfo.androidInfo;
          return '${info.manufacturer} ${info.model}'.trim();
        case TargetPlatform.iOS:
          final info = await _deviceInfo.iosInfo;
          return '${info.name} (${info.model})';
        case TargetPlatform.windows:
          final info = await _deviceInfo.windowsInfo;
          return '${info.computerName} (${info.productName})';
        case TargetPlatform.macOS:
          final info = await _deviceInfo.macOsInfo;
          return '${info.computerName} (${info.model})';
        case TargetPlatform.linux:
          final info = await _deviceInfo.linuxInfo;
          return info.prettyName;
        case TargetPlatform.fuchsia:
          return 'Fuchsia device';
      }
    } catch (error) {
      AppLogger.authLog('Could not read device name', error: error);
      return 'Unknown device';
    }
  }

  String _maskedDeviceId(String value) {
    if (value.length <= 12) return value;
    return '${value.substring(0, 6)}...${value.substring(value.length - 6)}';
  }
}
