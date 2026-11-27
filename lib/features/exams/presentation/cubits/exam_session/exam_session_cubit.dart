import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_result.dart';
import '../../../domain/usecases/get_exam_details_usecase.dart';
import 'exam_session_state.dart';

class ExamSessionCubit extends Cubit<ExamSessionState> {
  final GetExamDetailsUseCase _getExamDetailsUseCase;
  final SubmitExamUseCase _submitExamUseCase;
  Timer? _countdownTimer;

  ExamSessionCubit({
    required GetExamDetailsUseCase getExamDetailsUseCase,
    required SubmitExamUseCase submitExamUseCase,
  })  : _getExamDetailsUseCase = getExamDetailsUseCase,
        _submitExamUseCase = submitExamUseCase,
        super(const ExamSessionInitial());

  @override
  Future<void> close() {
    _countdownTimer?.cancel();
    return super.close();
  }

  Future<void> startExam(String examId) async {
    emit(const ExamSessionLoading());
    final result = await _getExamDetailsUseCase(examId);

    switch (result) {
      case ApiSuccess(:final data):
        final initialSeconds = data.durationMinutes * 60;
        emit(
          ExamSessionActive(
            exam: data,
            currentQuestionIndex: 0,
            answers: const {},
            remainingSeconds: initialSeconds,
          ),
        );
        _startTimer();
      case ApiError(:final failure):
        emit(ExamSessionError(failure.message));
    }
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state is! ExamSessionActive) {
        timer.cancel();
        return;
      }

      final activeState = state as ExamSessionActive;
      if (activeState.remainingSeconds > 0) {
        emit(activeState.copyWith(remainingSeconds: activeState.remainingSeconds - 1));
      } else {
        timer.cancel();
        submitExam();
      }
    });
  }

  void selectAnswer(String questionId, String answer) {
    if (state is ExamSessionActive) {
      final current = state as ExamSessionActive;
      final newAnswers = Map<String, String>.from(current.answers);
      newAnswers[questionId] = answer;
      emit(current.copyWith(answers: newAnswers));
    }
  }

  void goToQuestion(int index) {
    if (state is ExamSessionActive) {
      final current = state as ExamSessionActive;
      if (index >= 0 && index < current.exam.questions.length) {
        emit(current.copyWith(currentQuestionIndex: index));
      }
    }
  }

  void nextQuestion() {
    if (state is ExamSessionActive) {
      final current = state as ExamSessionActive;
      if (current.currentQuestionIndex < current.exam.questions.length - 1) {
        emit(current.copyWith(currentQuestionIndex: current.currentQuestionIndex + 1));
      }
    }
  }

  void previousQuestion() {
    if (state is ExamSessionActive) {
      final current = state as ExamSessionActive;
      if (current.currentQuestionIndex > 0) {
        emit(current.copyWith(currentQuestionIndex: current.currentQuestionIndex - 1));
      }
    }
  }

  Future<void> submitExam() async {
    if (state is! ExamSessionActive) return;
    final current = state as ExamSessionActive;
    emit(current.copyWith(isSubmitting: true));

    _countdownTimer?.cancel();

    final timeTaken = (current.exam.durationMinutes * 60) - current.remainingSeconds;

    final result = await _submitExamUseCase(
      examId: current.exam.id,
      answers: current.answers,
      timeTakenSeconds: timeTaken > 0 ? timeTaken : 0,
    );

    switch (result) {
      case ApiSuccess(:final data):
        emit(
          ExamSessionSubmitted(
            submission: data,
            exam: current.exam,
          ),
        );
      case ApiError(:final failure):
        emit(ExamSessionError(failure.message));
    }
  }
}
