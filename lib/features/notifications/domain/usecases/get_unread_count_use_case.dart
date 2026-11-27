import '../../../core/network/api_result.dart';
import '../repositories/notifications_repository.dart';

class GetUnreadCountUseCase {
  final NotificationsRepository _repository;

  GetUnreadCountUseCase(this._repository);

  Future<ApiResult<int>> call() {
    return _repository.getUnreadCount();
  }
}
