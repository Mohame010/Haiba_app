import '../../domain/entities/leaderboard_result_entity.dart';
import 'leaderboard_entry_model.dart';

class LeaderboardResultModel {
  final List<LeaderboardEntryModel> entries;
  final int totalCount;
  final LeaderboardEntryModel? currentUserEntry;
  final String? currentGrade;

  const LeaderboardResultModel({
    required this.entries,
    required this.totalCount,
    this.currentUserEntry,
    this.currentGrade,
  });

  LeaderboardResultEntity toEntity() {
    return LeaderboardResultEntity(
      entries: entries.map((e) => e.toEntity()).toList(),
      totalCount: totalCount,
      currentUserEntry: currentUserEntry?.toEntity(),
      currentGrade: currentGrade,
    );
  }
}
