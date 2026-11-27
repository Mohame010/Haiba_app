import '../../../core/errors/failure.dart';
import '../../../core/network/api_result.dart';
import '../../domain/entities/exam_entity.dart';
import '../../domain/entities/exam_submission_entity.dart';
import '../../domain/repositories/exams_repository.dart';
import '../datasources/exams_remote_data_source.dart';

class ExamsRepositoryImpl implements ExamsRepository {
  final ExamsRemoteDataSource _remoteDataSource;
  final Map<String, int> _examTimerCache = {};
  final Map<String, Map<String, String>> _examAnswersCache = {};

  ExamsRepositoryImpl(this._remoteDataSource);

  @override
  Future<ApiResult<List<ExamEntity>>> getExams() async {
    try {
      final models = await _remoteDataSource.getExams();
      return ApiResult.success(models.map((model) => model.toEntity()).toList());
    } catch (_) {
      return const ApiResult.failure(ServerFailure('تعذر تحميل الامتحانات والتحديات'));
    }
  }

  @override
  Future<ApiResult<ExamEntity>> getExamDetails(String examId) async {
    try {
      final model = await _remoteDataSource.getExamDetails(examId);
      return ApiResult.success(model.toEntity());
    } catch (_) {
      return const ApiResult.failure(ServerFailure('تعذر تحميل تفاصيل الاختبار'));
    }
  }

  @override
  Future<ApiResult<ExamSubmissionEntity>> submitExam({
    required String examId,
    required Map<String, String> answers,
    required int timeTakenSeconds,
  }) async {
    try {
      final model = await _remoteDataSource.submitExam(
        examId: examId,
        answers: answers,
        timeTakenSeconds: timeTakenSeconds,
      );
      _examTimerCache.remove(examId);
      _examAnswersCache.remove(examId);
      return ApiResult.success(model.toEntity());
    } catch (_) {
      return const ApiResult.failure(ServerFailure('تعذر إرسال الإجابات'));
    }
  }

  @override
  Future<ApiResult<int>> getSavedExamTime(String examId) async =>
      ApiResult.success(_examTimerCache[examId] ?? 0);

  @override
  Future<ApiResult<void>> saveExamProgress(
    String examId,
    int elapsedSeconds,
    Map<String, String> currentAnswers,
  ) async {
    _examTimerCache[examId] = elapsedSeconds;
    _examAnswersCache[examId] = Map.of(currentAnswers);
    return const ApiResult.success(null);
  }
}
