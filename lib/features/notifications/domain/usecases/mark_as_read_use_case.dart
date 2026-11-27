import '../../../core/network/api_result.dart';
import '../repositories/notifications_repository.dart';

class MarkAsReadUseCase {
  final NotificationsRepository _repository;

  MarkAsReadUseCase(this._repository);

  Future<ApiResult<void>> call(String notificationId) {
    return _repository.markAsRead(notificationId);
  }
}
