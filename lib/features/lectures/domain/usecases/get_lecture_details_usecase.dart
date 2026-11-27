import '../../../core/network/api_result.dart';
import '../entities/lecture_entity.dart';
import '../repositories/lectures_repository.dart';

class GetLectureDetailsUseCase {
  final LecturesRepository _repository;

  const GetLectureDetailsUseCase(this._repository);

  Future<ApiResult<LectureEntity>> call(String lectureId) {
    return _repository.getLectureDetails(lectureId);
  }
}
