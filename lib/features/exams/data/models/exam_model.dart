import '../../domain/entities/exam_entity.dart';
import '../../domain/entities/exam_submission_entity.dart';
import 'exam_question_model.dart';

class ExamModel {
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
  final String? expiresAt;
  final bool allowResume;
  final String examType;
  final int maxAttempts;
  final int attemptsUsed;
  final List<ExamQuestionModel> questions;

  const ExamModel({
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

  factory ExamModel.fromJson(Map<String, dynamic> json) {
    final questionsRaw = json['exam_questions'] as List<dynamic>? ?? [];
    final questionsList = questionsRaw
        .map((e) => ExamQuestionModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return ExamModel(
      id: json['id'] as String? ?? '',
      lectureId: json['lecture_id'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      chapter: json['chapter'] as String? ?? '',
      stage: json['stage'] as String? ?? '',
      grade: json['grade'] as String? ?? '',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
      totalScore: (json['total_score'] as num?)?.toInt() ?? 0,
      passScore: (json['pass_score'] as num?)?.toInt() ?? 0,
      questionsCount:
          (json['questions_count'] as num?)?.toInt() ?? questionsList.length,
      scheduledDate: json['scheduled_date'] as String? ?? '',
      expiresAt: json['expires_at'] as String?,
      allowResume: json['allow_resume'] != false,
      examType: json['exam_type'] as String? ?? 'exam',
      maxAttempts: (json['max_attempts'] as num?)?.toInt() ?? 1,
      attemptsUsed: (json['exam_submissions'] as List<dynamic>?)?.length ?? 0,
      questions: questionsList,
    );
  }

  ExamEntity toEntity() {
    return ExamEntity(
      id: id,
      lectureId: lectureId,
      title: title,
      description: description,
      chapter: chapter,
      stage: stage,
      grade: grade,
      durationMinutes: durationMinutes,
      totalScore: totalScore,
      passScore: passScore,
      questionsCount: questionsCount,
      scheduledDate: scheduledDate,
      expiresAt: expiresAt != null ? DateTime.tryParse(expiresAt!) : null,
      allowResume: allowResume,
      examType: examType,
      maxAttempts: maxAttempts,
      attemptsUsed: attemptsUsed,
      questions: questions.map((e) => e.toEntity()).toList(),
    );
  }
}

class ExamSubmissionModel {
  final String id;
  final String examId;
  final String studentId;
  final String studentName;
  final int score;
  final int totalScore;
  final int timeTakenSeconds;
  final Map<String, String> answers;
  final String submittedAt;

  const ExamSubmissionModel({
    required this.id,
    required this.examId,
    required this.studentId,
    required this.studentName,
    required this.score,
    required this.totalScore,
    required this.timeTakenSeconds,
    required this.answers,
    required this.submittedAt,
  });

  factory ExamSubmissionModel.fromJson(Map<String, dynamic> json) {
    Map<String, String> answersMap = {};
    if (json['answers'] is Map) {
      answersMap = (json['answers'] as Map).map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    }

    return ExamSubmissionModel(
      id: json['id'] as String? ?? '',
      examId: json['exam_id'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      totalScore: (json['total_score'] as num?)?.toInt() ?? 20,
      timeTakenSeconds: (json['time_taken_seconds'] as num?)?.toInt() ?? 0,
      answers: answersMap,
      submittedAt:
          json['submitted_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  ExamSubmissionEntity toEntity() {
    return ExamSubmissionEntity(
      id: id,
      examId: examId,
      studentId: studentId,
      studentName: studentName,
      score: score,
      totalScore: totalScore,
      timeTakenSeconds: timeTakenSeconds,
      answers: answers,
      submittedAt: DateTime.tryParse(submittedAt) ?? DateTime.now(),
    );
  }
}
