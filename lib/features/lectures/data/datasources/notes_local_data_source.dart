import 'dart:convert';
import 'package:hive_ce/hive.dart';
import '../models/lecture_content_model.dart';

abstract class NotesLocalDataSource {
  Future<List<VideoNoteModel>> getVideoNotes(String lectureId);

  Future<void> saveVideoNote(VideoNoteModel note);

  Future<int> getLastVideoPosition(String lectureId);

  Future<void> saveLastVideoPosition(String lectureId, int seconds);
}

class NotesLocalDataSourceImpl implements NotesLocalDataSource {
  static const String notesBoxName = 'video_notes_box';
  static const String progressBoxName = 'video_progress_box';

  Future<Box<dynamic>> _getNotesBox() async {
    if (Hive.isBoxOpen(notesBoxName)) {
      return Hive.box(notesBoxName);
    }
    return await Hive.openBox(notesBoxName);
  }

  Future<Box<dynamic>> _getProgressBox() async {
    if (Hive.isBoxOpen(progressBoxName)) {
      return Hive.box(progressBoxName);
    }
    return await Hive.openBox(progressBoxName);
  }

  @override
  Future<List<VideoNoteModel>> getVideoNotes(String lectureId) async {
    final box = await _getNotesBox();
    final rawList = box.get(lectureId);
    if (rawList == null) return [];

    if (rawList is List) {
      return rawList.map((item) {
        if (item is String) {
          final map = jsonDecode(item) as Map<String, dynamic>;
          return VideoNoteModel.fromJson(map);
        } else if (item is Map) {
          return VideoNoteModel.fromJson(Map<String, dynamic>.from(item));
        }
        return VideoNoteModel.fromJson(const {});
      }).toList();
    }
    return [];
  }

  @override
  Future<void> saveVideoNote(VideoNoteModel note) async {
    final box = await _getNotesBox();
    final currentList = await getVideoNotes(note.lectureId);
    currentList.add(note);

    final encoded = currentList.map((e) => jsonEncode(e.toJson())).toList();
    await box.put(note.lectureId, encoded);
  }

  @override
  Future<int> getLastVideoPosition(String lectureId) async {
    final box = await _getProgressBox();
    final val = box.get(lectureId);
    return (val as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> saveLastVideoPosition(String lectureId, int seconds) async {
    final box = await _getProgressBox();
    await box.put(lectureId, seconds);
  }
}
