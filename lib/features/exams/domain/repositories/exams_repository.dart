import '../../../core/network/api_result.dart';
import '../entities/exam_entity.dart';
import '../entities/exam_submission_entity.dart';

abstract class ExamsRepository {
  Future<ApiResult<List<ExamEntity>>> getExams();

  Future<ApiResult<ExamEntity>> getExamDetails(String examId);

  Future<ApiResult<ExamSubmissionEntity>> submitExam({
    required String examId,
    required Map<String, String> answers,
    required int timeTakenSeconds,
  });

  Future<ApiResult<int>> getSavedExamTime(String examId);

  Future<ApiResult<void>> saveExamProgress(String examId, int elapsedSeconds, Map<String, String> currentAnswers);
}
