import '../../domain/entities/exam_question_entity.dart';

class ExamQuestionModel {
  final String id;
  final String examId;
  final int questionNumber;
  final String questionType;
  final String answerType;
  final String questionText;
  final List<String> options;
  final String? correctAnswer;
  final String? imageUrl;
  final String? audioUrl;
  final int points;
  final String? explanation;

  const ExamQuestionModel({
    required this.id,
    required this.examId,
    required this.questionNumber,
    required this.questionType,
    this.answerType = 'mcq',
    required this.questionText,
    this.options = const [],
    this.correctAnswer,
    this.imageUrl,
    this.audioUrl,
    this.points = 5,
    this.explanation,
  });

  factory ExamQuestionModel.fromJson(Map<String, dynamic> json) {
    List<String> optionsList = [];
    if (json['options'] is List) {
      optionsList = (json['options'] as List).map((e) => e.toString()).toList();
    }

    return ExamQuestionModel(
      id: json['id'] as String? ?? '',
      examId: json['exam_id'] as String? ?? '',
      questionNumber: (json['question_number'] as num?)?.toInt() ?? 1,
      questionType: json['question_type'] as String? ?? 'mcq',
      answerType:
          json['answer_type'] as String? ??
          ((json['question_type'] as String?) == 'essay' ? 'essay' : 'mcq'),
      questionText: json['question_text'] as String? ?? '',
      options: optionsList,
      correctAnswer: json['correct_answer'] as String?,
      imageUrl: json['image_url'] as String?,
      audioUrl: json['audio_url'] as String?,
      points: (json['points'] as num?)?.toInt() ?? 5,
      explanation: json['explanation'] as String?,
    );
  }

  ExamQuestionEntity toEntity() {
    QuestionType type;
    if (imageUrl?.isNotEmpty == true) {
      type = QuestionType.image;
    } else if (audioUrl?.isNotEmpty == true) {
      type = QuestionType.audio;
    } else {
      switch (questionType.toLowerCase()) {
        case 'essay':
          type = QuestionType.essay;
          break;
        case 'image':
          type = QuestionType.image;
          break;
        case 'audio':
          type = QuestionType.audio;
          break;
        case 'mcq':
        default:
          type = QuestionType.mcq;
          break;
      }
    }

    return ExamQuestionEntity(
      id: id,
      examId: examId,
      questionNumber: questionNumber,
      questionType: type,
      answerType: answerType == 'essay'
          ? QuestionAnswerType.essay
          : QuestionAnswerType.mcq,
      questionText: questionText,
      options: options,
      correctAnswer: correctAnswer,
      imageUrl: imageUrl,
      audioUrl: audioUrl,
      points: points,
      explanation: explanation,
    );
  }
}
