import 'exam_question_entity.dart';

class ExamEntity {
  final String id;
  final String? lectureId;
  final String title;
  final String description;
  final String chapter;
  final String stage;
  final String grade;
  final int durationMinutes;
  final int totalScore;
  final int passScore;
  final int questionsCount;
  final String scheduledDate;
  final DateTime? expiresAt;
  final bool allowResume;
  final String examType;
  final int maxAttempts;
  final int attemptsUsed;
  final List<ExamQuestionEntity> questions;

  const ExamEntity({
    required this.id,
    this.lectureId,
    required this.title,
    required this.description,
    this.chapter = 'الفصل الثالث',
    this.stage = 'ثانوي',
    this.grade = 'الصف الأول الثانوي',
    this.durationMinutes = 45,
    this.totalScore = 20,
    this.passScore = 10,
    this.questionsCount = 20,
    this.scheduledDate = 'السبت 24 مايو - 10:00 ص',
    this.expiresAt,
    this.allowResume = true,
    this.examType = 'exam',
    this.maxAttempts = 1,
    this.attemptsUsed = 0,
    this.questions = const [],
  });

  bool get isChallenge => examType == 'challenge';
  bool get hasAttemptsRemaining => attemptsUsed < maxAttempts;

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
}
