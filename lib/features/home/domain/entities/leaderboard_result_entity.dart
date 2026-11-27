import 'leaderboard_entry_entity.dart';

class LeaderboardResultEntity {
  final List<LeaderboardEntryEntity> entries;
  final int totalCount;
  final LeaderboardEntryEntity? currentUserEntry;
  final String? currentGrade;

  const LeaderboardResultEntity({
    required this.entries,
    required this.totalCount,
    this.currentUserEntry,
    this.currentGrade,
  });
}
