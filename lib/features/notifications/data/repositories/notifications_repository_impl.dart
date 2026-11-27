import '../../../core/network/api_result.dart';
import '../../../core/errors/failure.dart';
import '../datasources/notifications_remote_data_source.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notifications_repository.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(this._remoteDataSource);

  final NotificationsRemoteDataSource _remoteDataSource;

  @override
  Future<ApiResult<List<NotificationEntity>>> getNotifications() async {
    try {
      final models = await _remoteDataSource.getNotifications();
      return ApiResult.success(
        models.map((model) => model.toEntity()).toList(),
      );
    } catch (_) {
      return const ApiResult.failure(
        NetworkFailure('تعذر تحميل الإشعارات، اسحب لأسفل للمحاولة مرة أخرى'),
      );
    }
  }

  @override
  Future<ApiResult<void>> markAsRead(String notificationId) async {
    try {
      await _remoteDataSource.markAsRead(notificationId);
      return const ApiResult.success(null);
    } catch (_) {
      return const ApiResult.failure(ServerFailure('تعذر تحديث الإشعار'));
    }
  }

  @override
  Future<ApiResult<void>> markAllAsRead() async {
    try {
      await _remoteDataSource.markAllAsRead();
      return const ApiResult.success(null);
    } catch (_) {
      return const ApiResult.failure(ServerFailure('تعذر تحديث الإشعارات'));
    }
  }

  @override
  Future<ApiResult<int>> getUnreadCount() async {
    try {
      return ApiResult.success(await _remoteDataSource.getUnreadCount());
    } catch (_) {
      return const ApiResult.failure(ServerFailure('تعذر تحميل العدد'));
    }
  }
}
