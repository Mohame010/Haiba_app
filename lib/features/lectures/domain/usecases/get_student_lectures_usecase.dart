import '../../../core/network/api_result.dart';
import '../entities/lecture_entity.dart';
import '../repositories/lectures_repository.dart';

class GetStudentLecturesUseCase {
  final LecturesRepository _repository;

  const GetStudentLecturesUseCase(this._repository);

  Future<ApiResult<List<LectureEntity>>> call() {
    return _repository.getStudentLectures();
  }
}
