import '../../domain/entities/leaderboard_entry_entity.dart';

class LeaderboardEntryModel {
  final String studentId;
  final String name;
  final int rank;
  final int points;
  final String? avatarUrl;
  final String? grade;
  final String? educationLevel;
  final bool isCurrentUser;

  const LeaderboardEntryModel({
    required this.studentId,
    required this.name,
    required this.rank,
    required this.points,
    this.avatarUrl,
    this.grade,
    this.educationLevel,
    this.isCurrentUser = false,
  });

  factory LeaderboardEntryModel.fromJson(
    Map<String, dynamic> json, {
    int rank = 1,
    String? currentUserId,
  }) {
    final studentId = json['student_id'] as String? ?? json['id'] as String? ?? '';
    return LeaderboardEntryModel(
      studentId: studentId,
      name: json['student_name'] as String? ?? json['name'] as String? ?? '',
      rank: (json['rank'] as num?)?.toInt() ?? rank,
      points: (json['points'] as num?)?.toInt() ?? (json['score'] as num?)?.toInt() ?? 0,
      avatarUrl: json['avatar_url'] as String?,
      grade: json['grade'] as String?,
      educationLevel: json['education_level'] as String?,
      isCurrentUser: currentUserId != null && currentUserId == studentId,
    );
  }

  LeaderboardEntryEntity toEntity() {
    return LeaderboardEntryEntity(
      studentId: studentId,
      name: name,
      rank: rank,
      points: points,
      avatarUrl: avatarUrl,
      grade: grade,
      educationLevel: educationLevel,
      isCurrentUser: isCurrentUser,
    );
  }
}

