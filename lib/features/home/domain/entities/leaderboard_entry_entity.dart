class LeaderboardEntryEntity {
  final String studentId;
  final String name;
  final int rank;
  final int points;
  final String? avatarUrl;
  final String? grade;
  final String? educationLevel;
  final bool isCurrentUser;

  const LeaderboardEntryEntity({
    required this.studentId,
    required this.name,
    required this.rank,
    required this.points,
    this.avatarUrl,
    this.grade,
    this.educationLevel,
    this.isCurrentUser = false,
  });
}
