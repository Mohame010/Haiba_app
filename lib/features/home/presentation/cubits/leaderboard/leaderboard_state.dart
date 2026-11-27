import '../../../domain/entities/leaderboard_entry_entity.dart';

sealed class LeaderboardState {
  const LeaderboardState();
}

final class LeaderboardInitial extends LeaderboardState {
  const LeaderboardInitial();
}

final class LeaderboardLoading extends LeaderboardState {
  final String? selectedGrade;
  const LeaderboardLoading({this.selectedGrade});
}

final class LeaderboardLoaded extends LeaderboardState {
  final List<LeaderboardEntryEntity> entries;
  final int totalCount;
  final LeaderboardEntryEntity? currentUserEntry;
  final String? selectedGrade;

  const LeaderboardLoaded({
    required this.entries,
    required this.totalCount,
    this.currentUserEntry,
    this.selectedGrade,
  });
}

final class LeaderboardError extends LeaderboardState {
  final String message;
  final String? selectedGrade;

  const LeaderboardError(this.message, {this.selectedGrade});
}

