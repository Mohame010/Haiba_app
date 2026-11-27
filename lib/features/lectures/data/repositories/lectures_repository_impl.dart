import '../../../core/errors/failure.dart';
import '../../../core/network/api_result.dart';
import '../../domain/entities/lecture_content_entity.dart';
import '../../domain/entities/lecture_entity.dart';
import '../../domain/repositories/lectures_repository.dart';
import '../datasources/lectures_remote_data_source.dart';
import '../datasources/notes_local_data_source.dart';
import '../models/lecture_content_model.dart';

class LecturesRepositoryImpl implements LecturesRepository {
  final LecturesRemoteDataSource _remoteDataSource;
  final NotesLocalDataSource _localDataSource;

  LecturesRepositoryImpl({
    required LecturesRemoteDataSource remoteDataSource,
    required NotesLocalDataSource localDataSource,
  }) : _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource;

  @override
  Future<ApiResult<List<LectureEntity>>> getStudentLectures() async {
    try {
      final models = await _remoteDataSource.getStudentLectures();
      return ApiResult.success(
        models.map((model) => model.toEntity()).toList(),
      );
    } catch (_) {
      return const ApiResult.failure(
        ServerFailure('تعذر تحميل الحصص من الخادم'),
      );
    }
  }

  @override
  Future<ApiResult<LectureEntity>> getLectureDetails(String lectureId) async {
    try {
      final model = await _remoteDataSource.getLectureDetails(lectureId);
      return ApiResult.success(model.toEntity());
    } catch (error) {
      final message = error
          .toString()
          .replaceFirst(RegExp(r'^Exception:\s*'), '')
          .trim();
      return ApiResult.failure(
        ServerFailure(message.isEmpty ? 'تعذر تحميل تفاصيل الحصة' : message),
      );
    }
  }

  @override
  Future<ApiResult<List<VideoNoteEntity>>> getVideoNotes(
    String lectureId,
  ) async {
    try {
      final models = await _localDataSource.getVideoNotes(lectureId);
      return ApiResult.success(
        models.map((model) => model.toEntity()).toList(),
      );
    } catch (_) {
      return const ApiResult.failure(ServerFailure('تعذر تحميل الملاحظات'));
    }
  }

  @override
  Future<ApiResult<void>> saveVideoNote(VideoNoteEntity note) async {
    try {
      await _localDataSource.saveVideoNote(VideoNoteModel.fromEntity(note));
      return const ApiResult.success(null);
    } catch (_) {
      return const ApiResult.failure(ServerFailure('تعذر حفظ الملاحظة'));
    }
  }

  @override
  Future<ApiResult<int>> getLastVideoPosition(String lectureId) async {
    try {
      return ApiResult.success(
        await _localDataSource.getLastVideoPosition(lectureId),
      );
    } catch (_) {
      return const ApiResult.success(0);
    }
  }

  @override
  Future<ApiResult<void>> saveLastVideoPosition(
    String lectureId,
    int seconds,
  ) async {
    try {
      await _localDataSource.saveLastVideoPosition(lectureId, seconds);
      return const ApiResult.success(null);
    } catch (_) {
      return const ApiResult.failure(ServerFailure('تعذر حفظ تقدم المشاهدة'));
    }
  }
}
