import '../../../core/network/api_result.dart';
import '../entities/home_summary_entity.dart';
import '../entities/leaderboard_result_entity.dart';

abstract class HomeRepository {
  Future<ApiResult<HomeSummaryEntity>> getHomeSummary();

  Future<ApiResult<LeaderboardResultEntity>> getLeaderboard({
    String? examId,
    String? grade,
    String? stage,
    bool challengesOnly = false,
  });
}

