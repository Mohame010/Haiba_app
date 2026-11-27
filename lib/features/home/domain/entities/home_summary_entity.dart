import 'banner_entity.dart';
import 'leaderboard_entry_entity.dart';
import 'teacher_entity.dart';

class UpcomingExamEntity {
  final String id;
  final String title;
  final String chapter;
  final String scheduledDate;
  final String daysRemaining;
  final int durationMinutes;
  final int totalScore;

  const UpcomingExamEntity({
    required this.id,
    required this.title,
    required this.chapter,
    required this.scheduledDate,
    required this.daysRemaining,
    required this.durationMinutes,
    required this.totalScore,
  });
}

class HomeSummaryEntity {
  final String studentName;
  final String grade;
  final String educationLevel;
  final int points;
  final int unreadNotificationsCount;
  final List<BannerEntity> banners;
  final UpcomingExamEntity? upcomingExam;
  final List<LeaderboardEntryEntity> topLeaderboard;
  final int userRank;
  final int totalStudentsCount;
  final TeacherEntity? teacher;

  const HomeSummaryEntity({
    required this.studentName,
    required this.grade,
    required this.educationLevel,
    required this.points,
    this.unreadNotificationsCount = 3,
    required this.banners,
    this.upcomingExam,
    required this.topLeaderboard,
    this.userRank = 1,
    this.totalStudentsCount = 150,
    this.teacher,
  });
}

