import '../../../domain/entities/exam_entity.dart';

sealed class ExamsListState {
  const ExamsListState();
}

final class ExamsListInitial extends ExamsListState {
  const ExamsListInitial();
}

final class ExamsListLoading extends ExamsListState {
  const ExamsListLoading();
}

final class ExamsListLoaded extends ExamsListState {
  final List<ExamEntity> exams;
  const ExamsListLoaded(this.exams);
}

final class ExamsListError extends ExamsListState {
  final String message;
  const ExamsListError(this.message);
}
