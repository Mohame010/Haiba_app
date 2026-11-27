import '../../../domain/entities/lecture_content_entity.dart';
import '../../../domain/entities/lecture_entity.dart';

sealed class LectureDetailsState {
  const LectureDetailsState();
}

final class LectureDetailsInitial extends LectureDetailsState {
  const LectureDetailsInitial();
}

final class LectureDetailsLoading extends LectureDetailsState {
  const LectureDetailsLoading();
}

final class LectureDetailsLoaded extends LectureDetailsState {
  final LectureEntity lecture;
  final LectureEntity? nextLecture;
  final List<VideoNoteEntity> notes;
  final int lastPositionSeconds;

  const LectureDetailsLoaded({
    required this.lecture,
    this.nextLecture,
    this.notes = const [],
    this.lastPositionSeconds = 0,
  });

  LectureDetailsLoaded copyWith({
    LectureEntity? lecture,
    LectureEntity? nextLecture,
    List<VideoNoteEntity>? notes,
    int? lastPositionSeconds,
  }) {
    return LectureDetailsLoaded(
      lecture: lecture ?? this.lecture,
      nextLecture: nextLecture ?? this.nextLecture,
      notes: notes ?? this.notes,
      lastPositionSeconds: lastPositionSeconds ?? this.lastPositionSeconds,
    );
  }
}

final class LectureDetailsError extends LectureDetailsState {
  final String message;
  const LectureDetailsError(this.message);
}
