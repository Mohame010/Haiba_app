import '../../../domain/entities/lecture_entity.dart';

sealed class LecturesListState {
  const LecturesListState();
}

final class LecturesListInitial extends LecturesListState {
  const LecturesListInitial();
}

final class LecturesListLoading extends LecturesListState {
  const LecturesListLoading();
}

final class LecturesListLoaded extends LecturesListState {
  final List<LectureEntity> lectures;
  const LecturesListLoaded(this.lectures);
}

final class LecturesListError extends LecturesListState {
  final String message;
  const LecturesListError(this.message);
}
