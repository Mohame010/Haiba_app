import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../firebase_options.dart';
import '../../constants/app_constants.dart';
import '../../helpers/app_logger.dart';
import '../../routing/app_router.dart';
import '../app_preferences.dart';
import 'awesome_notifcation_service.dart';

/// Firebase can already have a native `[DEFAULT]` app after a hot restart or
/// background-isolate bootstrap. Reuse it instead of initializing it twice.
Future<FirebaseApp> initializeFirebaseOnce() async {
  if (Firebase.apps.isNotEmpty) return Firebase.app();
  try {
    // Android already creates [DEFAULT] from google-services.json. Passing
    // options again can report duplicate-app after a hot restart/cache reuse.
    // iOS currently has no GoogleService-Info.plist, so it still needs options.
    return await Firebase.initializeApp(
      options: defaultTargetPlatform == TargetPlatform.android
          ? null
          : DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (error) {
    if (error.code == 'duplicate-app') return Firebase.app();
    rethrow;
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await initializeFirebaseOnce();
  // Android/iOS displays the notification payload. Its durable inbox copy was
  // already stored by the sending Edge Function.
}

class FirebaseMessagingService {
  FirebaseMessagingService._();

  static final FirebaseMessagingService instance = FirebaseMessagingService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  String? _currentToken;
  bool _initialized = false;

  String get _topic =>
      'teacher_${AppConstants.activeTeacherId.replaceAll('-', '')}';

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize() async {
    if (_initialized || !_isMobile) return;
    _initialized = true;

    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );

      _tokenSubscription = _messaging.onTokenRefresh.listen(
        (token) => unawaited(_syncToken(token)),
        onError: (Object error) =>
            AppLogger.authLog('FCM token refresh failed', error: error),
      );
      _authSubscription = _supabase.auth.onAuthStateChange.listen((state) {
        if (state.session != null) {
          unawaited(syncCurrentDevice());
        } else {
          unawaited(_messaging.unsubscribeFromTopic(_topic));
        }
      });
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _showForegroundMessage,
      );
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _openMessage,
      );

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _openMessage(initialMessage),
        );
      }
      if (_supabase.auth.currentUser != null) await syncCurrentDevice();
    } catch (error, stackTrace) {
      // Push setup must never prevent the user from entering the app.
      AppLogger.authLog(
        'FCM initialization deferred',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> syncCurrentDevice() async {
    if (!_isMobile || _supabase.auth.currentUser == null) return;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        for (var attempt = 0; attempt < 6; attempt++) {
          if (await _messaging.getAPNSToken() != null) break;
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      await _syncToken(token);
    } catch (error, stackTrace) {
      AppLogger.authLog(
        'Could not sync FCM token',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _syncToken(String token) async {
    if (_supabase.auth.currentUser == null) return;
    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : 'android';
    await _supabase.rpc(
      'register_student_fcm_token',
      params: {
        'p_token': token,
        'p_platform': platform,
        'p_device_id': await AppPreferences.getOrCreateDeviceId(),
      },
    );
    _currentToken = token;
    await _messaging.subscribeToTopic(_topic);
    AppLogger.authLog(
      'FCM device registered',
      data: {'platform': platform, 'topic': _topic},
    );
  }

  Future<void> unregisterCurrentDevice() async {
    if (!_isMobile) return;
    try {
      final token = _currentToken ?? await _messaging.getToken();
      if (token != null && _supabase.auth.currentUser != null) {
        await _supabase.rpc(
          'deactivate_student_fcm_token',
          params: {'p_token': token},
        );
      }
      await _messaging.unsubscribeFromTopic(_topic);
      _currentToken = null;
    } catch (error) {
      AppLogger.authLog('Could not unregister FCM device', error: error);
    }
  }

  Future<void> _showForegroundMessage(RemoteMessage message) async {
    final title = message.notification?.title ?? message.data['title'];
    final body = message.notification?.body ?? message.data['body'];
    if (title == null || body == null) return;
    await AwesomeNotificationService.showNotification(
      id:
          message.messageId?.hashCode.abs() ??
          DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: title,
      body: body,
      actionRoute: message.data['action_route']?.toString() ?? '/notifications',
      extraPayload: {
        if (message.data['action_id'] != null)
          'action_id': message.data['action_id'].toString(),
      },
    );
  }

  void _openMessage(RemoteMessage message) => _navigate(message.data);

  static void navigateFromPayload(Map<String, String?> payload) {
    instance._navigate(payload);
  }

  void _navigate(Map<String, dynamic> payload) {
    AppRouter.openNotificationDestination(
      route: payload['action_route']?.toString() ?? '/notifications',
      actionId: payload['action_id']?.toString(),
    );
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _authSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    _initialized = false;
  }
}
