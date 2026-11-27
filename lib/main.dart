import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:material_ui/material_ui.dart';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdfrx/pdfrx.dart';

import 'features/core/app/app.dart';
import 'features/core/app/env.dart';

import 'features/core/constants/app_constants.dart';
import 'features/core/di/dependency_injection.dart';
import 'features/core/network/internet_connection_mixin.dart';

import 'features/core/services/app_preferences.dart';
import 'features/core/services/device_session_service.dart';
import 'features/core/services/notifcations/awesome_notifcation_service.dart';
import 'features/core/services/notifcations/firebase_messaging_service.dart';
import 'features/core/routing/app_router.dart';
import 'features/core/routing/app_routes.dart';
import 'features/lectures/data/services/download_foreground_bridge.dart';
import 'features/lectures/data/services/offline_lecture_service.dart';

/// ---------------------------------------------------------------------------
/// Q360 Education Platform - Teacher Scoped Application
/// Set [AppConstants.activeTeacherId] to scope this app to a specific teacher.
/// ---------------------------------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Only local, deterministic work is allowed to delay the first Flutter frame.
  await Hive.initFlutter();
  await AppPreferences.init();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: anonKey,
    httpClient: InternetCheckedHttpClient(),
  );
  await setupDependencyInjection();
  runApp(const App());

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  unawaited(_initializeDeferredServices());

  DownloadForegroundBridge.cancelRequests.listen(_handleDownloadCancelRequest);
  unawaited(DownloadForegroundBridge.initialize());
}

Future<void> _initializeDeferredServices() async {
  try {
    await pdfrxFlutterInitialize().timeout(const Duration(seconds: 4));
  } catch (_) {}

  try {
    await getIt<DeviceSessionService>().initialize().timeout(
      const Duration(seconds: 5),
    );
  } catch (_) {
    // Offline startup keeps the locally persisted Supabase session usable.
  }

  try {
    await initializeFirebaseOnce().timeout(const Duration(seconds: 5));
    await AwesomeNotificationService.initializeNotification().timeout(
      const Duration(seconds: 5),
    );
    unawaited(FirebaseMessagingService.instance.initialize());
  } catch (_) {
    // Notifications are optional and can initialize on a later app launch.
  }
}

Future<void> _handleDownloadCancelRequest(String lectureId) async {
  // The novel speech model uses the same Android foreground channel as
  // lecture downloads, but it must be cancelled by MediaPipeNovelAudioService
  // without opening a lecture details screen or showing the video dialog.
  if (lectureId == 'novel-phonon-model') return;

  AppRouter.router.push(AppRoutes.lectureDetails, extra: lectureId);
  await Future<void>.delayed(const Duration(milliseconds: 450));
  final context = AppRouter.rootNavigatorKey.currentContext;
  if (context == null || !context.mounted) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('إلغاء التنزيل'),
      content: const Text('هل أنت متأكد من أنك تريد إلغاء تحميل الفيديو؟'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('متابعة التنزيل'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('نعم، إلغاء وحذف'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await OfflineLectureService.instance.cancelDownload(lectureId);
  }
}
