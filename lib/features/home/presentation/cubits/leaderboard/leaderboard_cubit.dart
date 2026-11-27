import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_result.dart';
import '../../../domain/usecases/get_leaderboard_usecase.dart';
import 'leaderboard_state.dart';

class LeaderboardCubit extends Cubit<LeaderboardState> {
  final GetLeaderboardUseCase _getLeaderboardUseCase;
  String? _currentGrade;

  LeaderboardCubit(this._getLeaderboardUseCase) : super(const LeaderboardInitial());

  String? get currentGrade => _currentGrade;

  Future<void> loadLeaderboard({
    String? examId,
    String? grade,
    String? stage,
    bool challengesOnly = false,
  }) async {
    _currentGrade = grade;
    emit(LeaderboardLoading(selectedGrade: grade));

    final result = await _getLeaderboardUseCase(
      examId: examId,
      grade: grade,
      stage: stage,
      challengesOnly: challengesOnly,
    );

    switch (result) {
      case ApiSuccess(:final data):
        emit(
          LeaderboardLoaded(
            entries: data.entries,
            totalCount: data.totalCount,
            currentUserEntry: data.currentUserEntry,
            selectedGrade: grade ?? data.currentGrade,
          ),
        );
      case ApiError(:final failure):
        emit(LeaderboardError(failure.message, selectedGrade: grade));
    }
  }
}

