import '../../../core/network/api_result.dart';
import '../entities/lecture_content_entity.dart';
import '../entities/lecture_entity.dart';

abstract class LecturesRepository {
  Future<ApiResult<List<LectureEntity>>> getStudentLectures();

  Future<ApiResult<LectureEntity>> getLectureDetails(String lectureId);

  Future<ApiResult<List<VideoNoteEntity>>> getVideoNotes(String lectureId);

  Future<ApiResult<void>> saveVideoNote(VideoNoteEntity note);

  Future<ApiResult<int>> getLastVideoPosition(String lectureId);

  Future<ApiResult<void>> saveLastVideoPosition(String lectureId, int seconds);
}
