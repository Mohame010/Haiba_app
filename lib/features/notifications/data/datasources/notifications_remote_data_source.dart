import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/helpers/app_logger.dart';
import '../models/notification_model.dart';

abstract class NotificationsRemoteDataSource {
  Future<List<NotificationModel>> getNotifications();
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();
  Future<int> getUnreadCount();
}

class NotificationsRemoteDataSourceImpl
    implements NotificationsRemoteDataSource {
  final SupabaseClient _supabaseClient;

  NotificationsRemoteDataSourceImpl(this._supabaseClient);

  String? get _currentUserId => _supabaseClient.auth.currentUser?.id;

  @override
  Future<List<NotificationModel>> getNotifications() async {
    AppLogger.authLog('Fetching notifications from Supabase');
    final userId = _currentUserId;

    if (userId == null) throw const AuthException('يجب تسجيل الدخول أولاً');
    final List<dynamic> data = await _supabaseClient
        .from('notifications')
        .select()
        .eq('student_id', userId)
        .order('created_at', ascending: false);
    return data
        .map(
          (json) => NotificationModel.fromJson(
            Map<String, dynamic>.from(json as Map),
          ),
        )
        .toList();
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await _supabaseClient
        .from('notifications')
        .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
        .eq('id', notificationId)
        .eq('student_id', _currentUserId!);
  }

  @override
  Future<void> markAllAsRead() async {
    final userId = _currentUserId;
    if (userId == null) throw const AuthException('يجب تسجيل الدخول أولاً');
    await _supabaseClient
        .from('notifications')
        .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
        .eq('student_id', userId)
        .eq('is_read', false);
  }

  @override
  Future<int> getUnreadCount() async {
    final userId = _currentUserId;
    if (userId == null) return 0;
    final List<dynamic> data = await _supabaseClient
        .from('notifications')
        .select('id')
        .eq('student_id', userId)
        .eq('is_read', false);
    return data.length;
  }
}
