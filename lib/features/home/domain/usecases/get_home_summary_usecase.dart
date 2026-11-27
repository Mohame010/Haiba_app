import '../../../core/network/api_result.dart';
import '../entities/home_summary_entity.dart';
import '../repositories/home_repository.dart';

class GetHomeSummaryUseCase {
  final HomeRepository _repository;

  const GetHomeSummaryUseCase(this._repository);

  Future<ApiResult<HomeSummaryEntity>> call() {
    return _repository.getHomeSummary();
  }
}
