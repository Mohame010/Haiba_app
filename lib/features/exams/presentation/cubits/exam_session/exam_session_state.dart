import '../../../domain/entities/exam_entity.dart';
import '../../../domain/entities/exam_submission_entity.dart';

sealed class ExamSessionState {
  const ExamSessionState();
}

final class ExamSessionInitial extends ExamSessionState {
  const ExamSessionInitial();
}

final class ExamSessionLoading extends ExamSessionState {
  const ExamSessionLoading();
}

final class ExamSessionActive extends ExamSessionState {
  final ExamEntity exam;
  final int currentQuestionIndex;
  final Map<String, String> answers;
  final int remainingSeconds;
  final bool isSubmitting;

  const ExamSessionActive({
    required this.exam,
    this.currentQuestionIndex = 0,
    this.answers = const {},
    required this.remainingSeconds,
    this.isSubmitting = false,
  });

  ExamSessionActive copyWith({
    ExamEntity? exam,
    int? currentQuestionIndex,
    Map<String, String>? answers,
    int? remainingSeconds,
    bool? isSubmitting,
  }) {
    return ExamSessionActive(
      exam: exam ?? this.exam,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      answers: answers ?? this.answers,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

final class ExamSessionSubmitted extends ExamSessionState {
  final ExamSubmissionEntity submission;
  final ExamEntity exam;

  const ExamSessionSubmitted({
    required this.submission,
    required this.exam,
  });
}

final class ExamSessionError extends ExamSessionState {
  final String message;
  const ExamSessionError(this.message);
}
