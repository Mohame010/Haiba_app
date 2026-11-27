import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LearningActivity {
  const LearningActivity({
    required this.lectureId,
    required this.lectureTitle,
    required this.chapter,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.updatedAt,
    this.thumbnailUrl,
    this.courseTitle,
  });

  final String lectureId;
  final String lectureTitle;
  final String chapter;
  final String? thumbnailUrl;
  final String? courseTitle;
  final int positionSeconds;
  final int durationSeconds;
  final DateTime updatedAt;

  double get progress => durationSeconds <= 0
      ? 0
      : (positionSeconds / durationSeconds).clamp(0, 1);
}

class LearningActivityService {
  LearningActivityService._();

  static final instance = LearningActivityService._();
  static const _boxName = 'learning_activity_box';
  final _client = Supabase.instance.client;
  final Map<String, DateTime> _lastRemoteWrite = {};

  Future<Box<dynamic>> _box() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return Hive.openBox<dynamic>(_boxName);
  }

  Future<void> saveLectureProgress({
    required String lectureId,
    required String lectureTitle,
    required String chapter,
    required int positionSeconds,
    required int durationSeconds,
    String? thumbnailUrl,
  }) async {
    final safePosition = positionSeconds
        .clamp(0, durationSeconds > 0 ? durationSeconds : 1 << 31)
        .toInt();
    final now = DateTime.now();
    final local = await _box();
    await local.put(lectureId, {
      'lecture_id': lectureId,
      'lecture_title': lectureTitle,
      'chapter': chapter,
      'thumbnail_url': thumbnailUrl,
      'position_seconds': safePosition,
      'duration_seconds': durationSeconds,
      'updated_at': now.toIso8601String(),
    });
    await local.put('latest_lecture_id', lectureId);

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    final previousWrite = _lastRemoteWrite[lectureId];
    final completed =
        durationSeconds > 0 && safePosition >= durationSeconds - 2;
    if (!completed &&
        previousWrite != null &&
        now.difference(previousWrite) < const Duration(seconds: 10)) {
      return;
    }
    _lastRemoteWrite[lectureId] = now;
    try {
      await _client.from('student_learning_activity').upsert({
        'student_id': userId,
        'lecture_id': lectureId,
        'position_seconds': safePosition,
        'duration_seconds': durationSeconds,
        'updated_at': now.toUtc().toIso8601String(),
      }, onConflict: 'student_id');
    } catch (_) {
      // Local progress remains available when the device is offline or before
      // the database migration has been applied.
    }
  }

  Future<int> positionForLecture(String lectureId) async {
    final local = await _box();
    final raw = local.get(lectureId);
    if (raw is Map) {
      return (raw['position_seconds'] as num?)?.toInt() ?? 0;
    }
    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      try {
        final row = await _client
            .from('student_learning_activity')
            .select('position_seconds')
            .eq('student_id', userId)
            .eq('lecture_id', lectureId)
            .maybeSingle();
        return (row?['position_seconds'] as num?)?.toInt() ?? 0;
      } catch (_) {}
    }
    return 0;
  }

  Future<LearningActivity?> latestActivity() async {
    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      try {
        final row = await _client
            .from('student_learning_activity')
            .select(
              'lecture_id,position_seconds,duration_seconds,updated_at,lectures!student_learning_activity_lecture_id_fkey(title,chapter,thumbnail_url,course_id,courses!lectures_course_id_fkey(title))',
            )
            .eq('student_id', userId)
            .maybeSingle();
        if (row != null && row['lectures'] is Map) {
          final lecture = Map<String, dynamic>.from(row['lectures'] as Map);
          final course = lecture['courses'];
          return LearningActivity(
            lectureId: row['lecture_id'] as String,
            lectureTitle: lecture['title'] as String? ?? 'الحصة',
            chapter: lecture['chapter'] as String? ?? '',
            thumbnailUrl: lecture['thumbnail_url'] as String?,
            courseTitle: course is Map ? course['title'] as String? : null,
            positionSeconds: (row['position_seconds'] as num?)?.toInt() ?? 0,
            durationSeconds: (row['duration_seconds'] as num?)?.toInt() ?? 0,
            updatedAt:
                DateTime.tryParse(row['updated_at'] as String? ?? '') ??
                DateTime.now(),
          );
        }
      } catch (_) {}
    }
    return _latestLocal();
  }

  Future<LearningActivity?> _latestLocal() async {
    final local = await _box();
    final lectureId = local.get('latest_lecture_id') as String?;
    if (lectureId == null) return null;
    final raw = local.get(lectureId);
    if (raw is! Map) return null;
    return LearningActivity(
      lectureId: lectureId,
      lectureTitle: raw['lecture_title'] as String? ?? 'الحصة',
      chapter: raw['chapter'] as String? ?? '',
      thumbnailUrl: raw['thumbnail_url'] as String?,
      positionSeconds: (raw['position_seconds'] as num?)?.toInt() ?? 0,
      durationSeconds: (raw['duration_seconds'] as num?)?.toInt() ?? 0,
      updatedAt:
          DateTime.tryParse(raw['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
