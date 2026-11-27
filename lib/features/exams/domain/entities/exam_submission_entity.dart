class QuestionAnswerEntity {
  final String questionId;
  final String answerText;
  final bool? isCorrect;
  final int earnedScore;

  const QuestionAnswerEntity({
    required this.questionId,
    required this.answerText,
    this.isCorrect,
    this.earnedScore = 0,
  });
}

class ExamSubmissionEntity {
  final String id;
  final String examId;
  final String studentId;
  final String studentName;
  final int score;
  final int totalScore;
  final int timeTakenSeconds;
  final Map<String, String> answers;
  final DateTime submittedAt;

  const ExamSubmissionEntity({
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
}
