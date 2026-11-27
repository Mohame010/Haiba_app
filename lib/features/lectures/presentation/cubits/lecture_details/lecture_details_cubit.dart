import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_result.dart';
import '../../../domain/entities/lecture_content_entity.dart';
import '../../../domain/entities/lecture_entity.dart';
import '../../../domain/usecases/get_lecture_details_usecase.dart';
import '../../../domain/usecases/get_student_lectures_usecase.dart';
import '../../../domain/usecases/save_video_note_usecase.dart';
import 'lecture_details_state.dart';

class LectureDetailsCubit extends Cubit<LectureDetailsState> {
  final GetLectureDetailsUseCase _getLectureDetailsUseCase;
  final GetStudentLecturesUseCase _getStudentLecturesUseCase;
  final GetVideoNotesUseCase _getVideoNotesUseCase;
  final SaveVideoNoteUseCase _saveVideoNoteUseCase;

  LectureDetailsCubit({
    required GetLectureDetailsUseCase getLectureDetailsUseCase,
    required GetStudentLecturesUseCase getStudentLecturesUseCase,
    required GetVideoNotesUseCase getVideoNotesUseCase,
    required SaveVideoNoteUseCase saveVideoNoteUseCase,
  }) : _getLectureDetailsUseCase = getLectureDetailsUseCase,
       _getStudentLecturesUseCase = getStudentLecturesUseCase,
       _getVideoNotesUseCase = getVideoNotesUseCase,
       _saveVideoNoteUseCase = saveVideoNoteUseCase,
       super(const LectureDetailsInitial());

  Future<void> loadLecture(String lectureId) async {
    debugPrint(
      '[Q360-CUBIT] LectureDetailsCubit: Loading details for lectureId: $lectureId',
    );
    emit(const LectureDetailsLoading());

    final lectureResult = await _getLectureDetailsUseCase(lectureId);
    final notesResult = await _getVideoNotesUseCase(lectureId);
    final lecturesResult = await _getStudentLecturesUseCase();

    switch (lectureResult) {
      case ApiSuccess(:final data):
        debugPrint(
          '[Q360-CUBIT] LectureDetailsCubit: Loaded lecture "${data.title}" with ${data.contents.length} contents',
        );
        final notes = switch (notesResult) {
          ApiSuccess(:final data) => data,
          _ => <VideoNoteEntity>[],
        };
        final nextLecture = switch (lecturesResult) {
          ApiSuccess(data: final lectures) => _findNextLecture(
            lectures,
            current: data,
          ),
          _ => null,
        };
        emit(
          LectureDetailsLoaded(
            lecture: data,
            nextLecture: nextLecture,
            notes: notes,
          ),
        );
      case ApiError(:final failure):
        debugPrint(
          '[Q360-CUBIT] LectureDetailsCubit: Error loading lecture: ${failure.message}',
        );
        emit(LectureDetailsError(failure.message));
    }
  }

  LectureEntity? _findNextLecture(
    List<LectureEntity> lectures, {
    required LectureEntity current,
  }) {
    if (current.courseId == null) return null;
    final sameCourse = lectures
        .where((lecture) => lecture.courseId == current.courseId)
        .toList();
    if (sameCourse.length < 2) return null;

    sameCourse.sort((a, b) {
      final aOrder = a.courseSortOrder;
      final bOrder = b.courseSortOrder;
      if (aOrder != null && bOrder != null && aOrder != bOrder) {
        return aOrder.compareTo(bOrder);
      }
      final aNumber = _lessonNumber(a.lessonNumber);
      final bNumber = _lessonNumber(b.lessonNumber);
      if (aNumber != null && bNumber != null && aNumber != bNumber) {
        return aNumber.compareTo(bNumber);
      }
      return lectures.indexOf(a).compareTo(lectures.indexOf(b));
    });
    final currentIndex = sameCourse.indexWhere(
      (lecture) => lecture.id == current.id,
    );
    if (currentIndex < 0 || currentIndex + 1 >= sameCourse.length) return null;
    return sameCourse[currentIndex + 1];
  }

  int? _lessonNumber(String value) {
    final match = RegExp(r'\d+').firstMatch(value);
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  Future<String?> addNote({
    required String lectureId,
    required int timestampSeconds,
    required String noteText,
  }) async {
    final newNote = VideoNoteEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      lectureId: lectureId,
      timestampSeconds: timestampSeconds,
      noteText: noteText,
      createdAt: DateTime.now(),
    );

    final result = await _saveVideoNoteUseCase(newNote);
    if (result case ApiError(:final failure)) {
      return failure.message;
    }

    if (state is LectureDetailsLoaded) {
      final current = state as LectureDetailsLoaded;
      final updatedNotes = List<VideoNoteEntity>.from(current.notes)
        ..add(newNote);
      emit(current.copyWith(notes: updatedNotes));
    }
    return null;
  }
}
