import '../../domain/entities/home_summary_entity.dart';
import 'banner_model.dart';
import 'leaderboard_entry_model.dart';
import 'teacher_model.dart';

class UpcomingExamModel {
  final String id;
  final String title;
  final String chapter;
  final String scheduledDate;
  final String daysRemaining;
  final int durationMinutes;
  final int totalScore;

  const UpcomingExamModel({
    required this.id,
    required this.title,
    required this.chapter,
    required this.scheduledDate,
    required this.daysRemaining,
    required this.durationMinutes,
    required this.totalScore,
  });

  factory UpcomingExamModel.fromJson(Map<String, dynamic> json) {
    String scheduledDate = json['scheduled_date'] as String? ?? '';
    String daysRemaining = json['days_remaining'] as String? ?? '';

    final scheduledAtStr = json['scheduled_at'] as String?;
    final expiresAtStr = json['expires_at'] as String?;

    if (scheduledAtStr != null && scheduledDate.isEmpty) {
      final scheduledDateObj = DateTime.tryParse(scheduledAtStr);
      if (scheduledDateObj != null) {
        final local = scheduledDateObj.toLocal();
        const arabicMonths = [
          'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
          'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
        ];
        const arabicDays = [
          'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'
        ];
        final dayName = arabicDays[local.weekday - 1];
        final monthName = arabicMonths[local.month - 1];
        final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
        final period = local.hour >= 12 ? 'م' : 'ص';
        final minute = local.minute.toString().padLeft(2, '0');
        scheduledDate = '$dayName ${local.day} $monthName - $hour:$minute $period';
      }
    }

    if (expiresAtStr != null && daysRemaining.isEmpty) {
      final expiryDate = DateTime.tryParse(expiresAtStr);
      if (expiryDate != null) {
        final diffDays = expiryDate.difference(DateTime.now()).inDays;
        if (diffDays > 0) {
          daysRemaining = '$diffDays أيام متبقية';
        } else if (diffDays == 0) {
          daysRemaining = 'اليوم الأخير';
        } else {
          daysRemaining = 'منتهي';
        }
      }
    }

    return UpcomingExamModel(
      id: json['id'] as String? ?? '44444444-4444-4444-4444-444444444444',
      title: json['title'] as String? ?? 'امتحان الفيزياء',
      chapter: json['chapter'] as String? ?? 'الفصل الثالث - الكهرباء والمغناطيسية',
      scheduledDate: scheduledDate.isNotEmpty ? scheduledDate : 'السبت 24 مايو - 10:00 ص',
      daysRemaining: daysRemaining.isNotEmpty ? daysRemaining : '3 أيام متبقية',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 45,
      totalScore: (json['total_score'] as num?)?.toInt() ?? 20,
    );
  }

  UpcomingExamEntity toEntity() {
    return UpcomingExamEntity(
      id: id,
      title: title,
      chapter: chapter,
      scheduledDate: scheduledDate,
      daysRemaining: daysRemaining,
      durationMinutes: durationMinutes,
      totalScore: totalScore,
    );
  }
}

class HomeSummaryModel {
  final String studentName;
  final String grade;
  final String educationLevel;
  final int points;
  final int unreadNotificationsCount;
  final List<BannerModel> banners;
  final UpcomingExamModel? upcomingExam;
  final List<LeaderboardEntryModel> topLeaderboard;
  final int userRank;
  final int totalStudentsCount;
  final TeacherModel? teacher;

  const HomeSummaryModel({
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

  HomeSummaryEntity toEntity() {
    return HomeSummaryEntity(
      studentName: studentName,
      grade: grade,
      educationLevel: educationLevel,
      points: points,
      unreadNotificationsCount: unreadNotificationsCount,
      banners: banners.map((e) => e.toEntity()).toList(),
      upcomingExam: upcomingExam?.toEntity(),
      topLeaderboard: topLeaderboard.map((e) => e.toEntity()).toList(),
      userRank: userRank,
      totalStudentsCount: totalStudentsCount,
      teacher: teacher,
    );
  }
}

