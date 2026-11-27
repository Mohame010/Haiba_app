import '../../../core/network/api_result.dart';
import '../entities/exam_entity.dart';
import '../repositories/exams_repository.dart';

class GetExamsUseCase {
  final ExamsRepository _repository;

  const GetExamsUseCase(this._repository);

  Future<ApiResult<List<ExamEntity>>> call() {
    return _repository.getExams();
  }
}
