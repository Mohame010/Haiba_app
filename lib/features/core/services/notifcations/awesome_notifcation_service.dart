import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/helpers/app_logger.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/app_routes.dart';

class AwesomeNotificationService {
  AwesomeNotificationService._();

  // ─── Channel Keys ──────────────────────────────────────────────────────────
  static const String mainChannel = 'education_notifications';
  static const String examChannel = 'exam_reminders';
  static const String channelGroup = 'education_group';

  static RealtimeChannel? _supabaseSubscription;

  // ─── Initialize ──────────────────────────────────────────────────────────
  static Future<void> initializeNotification() async {
    try {
      await AwesomeNotifications().initialize(
        null, // uses default app icon
        [
          NotificationChannel(
            channelGroupKey: channelGroup,
            channelKey: mainChannel,
            channelName: 'إشعارات المنصة التعليمية',
            channelDescription: 'إشعارات الدروس، الامتحانات، والتنبيهات العامة',
            importance: NotificationImportance.Max,
            channelShowBadge: true,
            onlyAlertOnce: false,
            playSound: true,
            enableVibration: true,
            defaultColor: const Color(0xFF7C3AED),
            ledColor: const Color(0xFF7C3AED),
            criticalAlerts: false,
          ),
          NotificationChannel(
            channelGroupKey: channelGroup,
            channelKey: examChannel,
            channelName: 'تذكيرات الامتحانات والمهام',
            channelDescription: 'تنبيهات مواعيد الامتحانات والواجبات الهامة',
            importance: NotificationImportance.Max,
            channelShowBadge: true,
            onlyAlertOnce: false,
            playSound: true,
            enableVibration: true,
            defaultColor: const Color(0xFFF59E0B),
            ledColor: const Color(0xFFF59E0B),
            criticalAlerts: false,
          ),
        ],
        channelGroups: [
          NotificationChannelGroup(
            channelGroupKey: channelGroup,
            channelGroupName: 'مجموعة إشعارات التعليم',
          ),
        ],
        debug: false,
      );

      // Request base permissions
      await requestPermissions();

      // Listen for user taps on notifications
      await AwesomeNotifications().setListeners(
        onActionReceivedMethod: onActionReceivedMethod,
        onNotificationCreatedMethod: onNotificationCreatedMethod,
        onNotificationDisplayedMethod: onNotificationDisplayedMethod,
        onDismissActionReceivedMethod: onDismissActionReceivedMethod,
      );
    } catch (e) {
      AppLogger.authLog(
        'Error initializing Awesome Notifications',
        error: e.toString(),
      );
    }
  }

  // ─── Request Permissions ──────────────────────────────────────────────────
  static Future<bool> requestPermissions() async {
    try {
      final isAllowed = await AwesomeNotifications().isNotificationAllowed();
      if (!isAllowed) {
        return await AwesomeNotifications()
            .requestPermissionToSendNotifications(
              permissions: [
                NotificationPermission.Alert,
                NotificationPermission.Sound,
                NotificationPermission.Badge,
                NotificationPermission.Vibration,
                NotificationPermission.Light,
              ],
            );
      }
      return true;
    } catch (e) {
      AppLogger.authLog(
        'Error requesting notification permissions',
        error: e.toString(),
      );
      return false;
    }
  }

  // ─── Notification Callbacks ──────────────────────────────────────────────
  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(
    ReceivedNotification receivedNotification,
  ) async {
    AppLogger.authLog('Notification created: ${receivedNotification.id}');
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(
    ReceivedNotification receivedNotification,
  ) async {
    AppLogger.authLog('Notification displayed: ${receivedNotification.id}');
  }

  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    AppLogger.authLog('Notification dismissed: ${receivedAction.id}');
  }

  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    try {
      final payload = receivedAction.payload ?? const <String, String?>{};
      final actionRoute = payload['action_route'] ?? AppRoutes.notifications;
      AppLogger.authLog('Notification clicked -> Route: $actionRoute');

      // Navigate inside the app
      AppRouter.openNotificationDestination(
        route: actionRoute,
        actionId: payload['action_id'],
      );
    } catch (e) {
      AppLogger.authLog(
        'Error navigating on notification tap',
        error: e.toString(),
      );
    }
  }

  // ─── Show Notification ───────────────────────────────────────────────────
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? actionRoute,
    String channelKey = mainChannel,
    Map<String, String>? extraPayload,
  }) async {
    final payload = <String, String>{
      'action_route': actionRoute ?? AppRoutes.notifications,
      if (extraPayload != null) ...extraPayload,
    };

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: channelKey,
        title: title,
        body: body,
        payload: payload,
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Message,
        wakeUpScreen: true,
        fullScreenIntent: false,
        autoDismissible: true,
      ),
    );
  }

  // ─── Supabase Realtime Listener ──────────────────────────────────────────
  static void listenToSupabaseRealtimeNotifications(String? studentId) {
    if (_supabaseSubscription != null) {
      Supabase.instance.client.removeChannel(_supabaseSubscription!);
    }

    try {
      _supabaseSubscription = Supabase.instance.client
          .channel('public:notifications')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            callback: (payload) {
              final newRecord = payload.newRecord;
              final recordStudentId = newRecord['student_id'] as String?;

              // Check if notification is for this student or broadcast (null)
              if (recordStudentId == null || recordStudentId == studentId) {
                final id = DateTime.now().millisecondsSinceEpoch % 100000;
                final title = newRecord['title'] as String? ?? 'إشعار جديد 🔔';
                final body = newRecord['body'] as String? ?? '';
                final actionRoute =
                    newRecord['action_route'] as String? ??
                    AppRoutes.notifications;

                showNotification(
                  id: id,
                  title: title,
                  body: body,
                  actionRoute: actionRoute,
                );
              }
            },
          )
          .subscribe();
    } catch (e) {
      AppLogger.authLog(
        'Error setting up Supabase Realtime notifications',
        error: e.toString(),
      );
    }
  }

  static void dispose() {
    if (_supabaseSubscription != null) {
      Supabase.instance.client.removeChannel(_supabaseSubscription!);
    }
  }
}
