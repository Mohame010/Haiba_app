import 'dart:developer' as developer;
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class PronunciationAssignmentService {
  PronunciationAssignmentService([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  static const bucket = 'pronunciation-recordings';
  static const maxFileSizeBytes = 24 * 1024;
  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> loadWords(String lectureId) async {
    final rows = await _client
        .from('lecture_pronunciation_words')
        .select('id,word,max_duration_seconds,sort_order')
        .eq('lecture_id', lectureId)
        .eq('is_published', true)
        .order('sort_order');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, Map<String, dynamic>>> loadStudentSubmissions(
    List<String> wordIds,
  ) async {
    final studentId = _client.auth.currentUser?.id;
    if (studentId == null || wordIds.isEmpty) return {};
    final rows = await _client
        .from('lecture_pronunciation_submissions')
        .select('word_id,audio_path,file_size_bytes,duration_ms,submitted_at')
        .eq('student_id', studentId)
        .inFilter('word_id', wordIds);
    return {
      for (final row in rows)
        (row['word_id'] as String): Map<String, dynamic>.from(row),
    };
  }

  Future<Map<String, dynamic>> submitRecording({
    required String lectureId,
    required String wordId,
    required String localPath,
    required int durationMs,
    String? previousAudioPath,
  }) async {
    final studentId = _client.auth.currentUser?.id;
    if (studentId == null) {
      throw const AuthException('يجب تسجيل الدخول لتسليم النطق');
    }

    final file = File(localPath);
    if (!await file.exists()) {
      throw const FileSystemException('ملف التسجيل غير موجود');
    }
    final fileSize = await file.length();
    if (fileSize == 0 || fileSize > maxFileSizeBytes) {
      throw StateError('يجب ألا يتجاوز حجم التسجيل 24 كيلوبايت');
    }

    final fileName = '${DateTime.now().microsecondsSinceEpoch}.m4a';
    final storagePath = '$lectureId/$studentId/$wordId/$fileName';
    await _client.storage.from(bucket).upload(
      storagePath,
      file,
      fileOptions: const FileOptions(
        contentType: 'audio/mp4',
        upsert: false,
      ),
    );

    try {
      final row = await _client
          .from('lecture_pronunciation_submissions')
          .upsert(
            {
              'word_id': wordId,
              'student_id': studentId,
              'audio_path': storagePath,
              'file_size_bytes': fileSize,
              'duration_ms': durationMs,
              'submitted_at': DateTime.now().toUtc().toIso8601String(),
            },
            onConflict: 'word_id,student_id',
          )
          .select(
            'word_id,audio_path,file_size_bytes,duration_ms,submitted_at',
          )
          .single();

      if (previousAudioPath != null && previousAudioPath != storagePath) {
        try {
          await _client.storage.from(bucket).remove([previousAudioPath]);
        } catch (error) {
          developer.log(
            'Failed to remove replaced pronunciation audio',
            name: 'Q360.Pronunciation',
            error: error,
          );
        }
      }
      return Map<String, dynamic>.from(row);
    } catch (error, stackTrace) {
      try {
        await _client.storage.from(bucket).remove([storagePath]);
      } catch (cleanupError) {
        developer.log(
          'Failed to clean up an unsubmitted pronunciation recording',
          name: 'Q360.Pronunciation',
          error: cleanupError,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<String> createStudentAudioUrl(String path) {
    return _client.storage.from(bucket).createSignedUrl(path, 300);
  }
}
