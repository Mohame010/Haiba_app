import '../../../core/network/api_result.dart';
import '../entities/exam_entity.dart';
import '../entities/exam_submission_entity.dart';
import '../repositories/exams_repository.dart';

class GetExamDetailsUseCase {
  final ExamsRepository _repository;

  const GetExamDetailsUseCase(this._repository);

  Future<ApiResult<ExamEntity>> call(String examId) {
    return _repository.getExamDetails(examId);
  }
}

class SubmitExamUseCase {
  final ExamsRepository _repository;

  const SubmitExamUseCase(this._repository);

  Future<ApiResult<ExamSubmissionEntity>> call({
    required String examId,
    required Map<String, String> answers,
    required int timeTakenSeconds,
  }) {
    return _repository.submitExam(
      examId: examId,
      answers: answers,
      timeTakenSeconds: timeTakenSeconds,
    );
  }
}
