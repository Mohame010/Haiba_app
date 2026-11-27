import '../../../core/network/api_result.dart';
import '../entities/notification_entity.dart';

abstract class NotificationsRepository {
  Future<ApiResult<List<NotificationEntity>>> getNotifications();
  Future<ApiResult<void>> markAsRead(String notificationId);
  Future<ApiResult<void>> markAllAsRead();
  Future<ApiResult<int>> getUnreadCount();
}
