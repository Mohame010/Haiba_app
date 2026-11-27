import '../../../core/errors/failure.dart';
import '../../../core/network/api_result.dart';
import '../../domain/entities/home_summary_entity.dart';
import '../../domain/entities/leaderboard_result_entity.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/home_remote_data_source.dart';

class HomeRepositoryImpl implements HomeRepository {
  final HomeRemoteDataSource _remoteDataSource;

  HomeRepositoryImpl(this._remoteDataSource);

  @override
  Future<ApiResult<HomeSummaryEntity>> getHomeSummary() async {
    try {
      final model = await _remoteDataSource.getHomeSummary();
      return ApiResult.success(model.toEntity());
    } catch (_) {
      return const ApiResult.failure(
        ServerFailure('تعذر تحميل بيانات الصفحة الرئيسية'),
      );
    }
  }

  @override
  Future<ApiResult<LeaderboardResultEntity>> getLeaderboard({
    String? examId,
    String? grade,
    String? stage,
    bool challengesOnly = false,
  }) async {
    try {
      final model = await _remoteDataSource.getLeaderboard(
        examId: examId,
        grade: grade,
        stage: stage,
        challengesOnly: challengesOnly,
      );
      return ApiResult.success(model.toEntity());
    } catch (_) {
      return const ApiResult.failure(
        ServerFailure('تعذر تحميل لوحة المتصدرين'),
      );
    }
  }
}
