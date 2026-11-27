enum QuestionType { mcq, essay, image, audio }

enum QuestionAnswerType { mcq, essay }

class ExamQuestionEntity {
  final String id;
  final String examId;
  final int questionNumber;
  final QuestionType questionType;
  final QuestionAnswerType answerType;
  final String questionText;
  final List<String> options;
  final String? correctAnswer;
  final String? imageUrl;
  final String? audioUrl;
  final int points;
  final String? explanation;

  const ExamQuestionEntity({
    required this.id,
    required this.examId,
    required this.questionNumber,
    required this.questionType,
    this.answerType = QuestionAnswerType.mcq,
    required this.questionText,
    this.options = const [],
    this.correctAnswer,
    this.imageUrl,
    this.audioUrl,
    this.points = 5,
    this.explanation,
  });
}
