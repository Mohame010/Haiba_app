import '../../../core/network/api_result.dart';
import '../repositories/notifications_repository.dart';

class MarkAllAsReadUseCase {
  final NotificationsRepository _repository;

  MarkAllAsReadUseCase(this._repository);

  Future<ApiResult<void>> call() {
    return _repository.markAllAsRead();
  }
}
