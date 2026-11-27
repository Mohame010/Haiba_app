import '../../../core/network/api_result.dart';
import '../entities/lecture_content_entity.dart';
import '../repositories/lectures_repository.dart';

class SaveVideoNoteUseCase {
  final LecturesRepository _repository;

  const SaveVideoNoteUseCase(this._repository);

  Future<ApiResult<void>> call(VideoNoteEntity note) {
    return _repository.saveVideoNote(note);
  }
}

class GetVideoNotesUseCase {
  final LecturesRepository _repository;

  const GetVideoNotesUseCase(this._repository);

  Future<ApiResult<List<VideoNoteEntity>>> call(String lectureId) {
    return _repository.getVideoNotes(lectureId);
  }
}
