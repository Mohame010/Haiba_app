import '../../../core/network/api_result.dart';
import '../entities/leaderboard_result_entity.dart';
import '../repositories/home_repository.dart';

class GetLeaderboardUseCase {
  final HomeRepository _repository;

  const GetLeaderboardUseCase(this._repository);

  Future<ApiResult<LeaderboardResultEntity>> call({
    String? examId,
    String? grade,
    String? stage,
    bool challengesOnly = false,
  }) {
    return _repository.getLeaderboard(
      examId: examId,
      grade: grade,
      stage: stage,
      challengesOnly: challengesOnly,
    );
  }
}

