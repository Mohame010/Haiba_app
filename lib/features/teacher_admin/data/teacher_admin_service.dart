import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherAdminSession {
  const TeacherAdminSession({
    required this.adminId,
    required this.teacherId,
    required this.email,
  });

  final String adminId;
  final String teacherId;
  final String email;
}

class TeacherAdminService {
  TeacherAdminService([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  static const bucket = 'q360-content';
  static String? _sessionToken;
  final SupabaseClient _client;
  static const _uploadChannel = MethodChannel('q360education/uploads');

  Future<TeacherAdminSession?> currentSession() async {
    if (_sessionToken == null) return null;
    _applySessionHeader();
    final result = await _client.rpc('teacher_admin_current_session');
    if (result is! Map) {
      _clearSessionHeader();
      return null;
    }
    final row = Map<String, dynamic>.from(result);
    final teacherId = row['teacher_id'] as String?;
    if (teacherId == null) {
      _clearSessionHeader();
      return null;
    }
    return TeacherAdminSession(
      adminId: row['admin_id'] as String? ?? '',
      teacherId: teacherId,
      email: row['email'] as String? ?? '',
    );
  }

  Future<TeacherAdminSession> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _client.rpc(
        'teacher_admin_login',
        params: {'p_email': email.trim().toLowerCase(), 'p_password': password},
      );
      if (result is! Map || result['token'] is! String) {
        throw const AuthException('تعذر إنشاء جلسة الأدمن');
      }
      _sessionToken = result['token'] as String;
      _applySessionHeader();
      return TeacherAdminSession(
        adminId: result['admin_id'] as String? ?? '',
        teacherId: result['teacher_id'] as String,
        email: result['email'] as String? ?? email.trim().toLowerCase(),
      );
    } on PostgrestException catch (error) {
      if (error.message.contains('invalid_admin_credentials')) {
        throw const AuthException('البريد الإلكتروني أو كلمة المرور غير صحيحة');
      }
      rethrow;
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _applySessionHeader();
    await _client.rpc(
      'teacher_admin_change_password',
      params: {
        'p_current_password': currentPassword,
        'p_new_password': newPassword,
      },
    );
  }

  Future<void> signOut() async {
    if (_sessionToken != null) {
      _applySessionHeader();
      try {
        await _client.rpc('teacher_admin_logout');
      } catch (_) {}
    }
    _sessionToken = null;
    _clearSessionHeader();
  }

  void _applySessionHeader() {
    final token = _sessionToken;
    if (token == null) return;
    _client.headers = {..._client.headers, 'x-teacher-admin-token': token};
  }

  void _clearSessionHeader() {
    final headers = Map<String, String>.from(_client.headers)
      ..remove('x-teacher-admin-token');
    _client.headers = headers;
  }

  Future<List<Map<String, dynamic>>> courses(String teacherId) async {
    final rows = await _client
        .from('courses')
        .select(
          'id,title,description,stage,grade,price,is_published,thumbnail_url,level,recommended_skill,min_placement_score,max_placement_score,created_at,direct_lectures:lectures!lectures_course_id_fkey(id,title,is_published),course_lectures(lecture_id,sort_order,lectures!course_lectures_lecture_id_fkey(id,title,is_published))',
        )
        .eq('teacher_id', teacherId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> lectures(String teacherId) async {
    final rows = await _client
        .from('lectures')
        .select(
          'id,title,description,stage,grade,subject,chapter,lesson_number,course_id,online_price,center_price,is_published,thumbnail_url,created_at,lecture_contents(id,title,content_type,file_url,sort_order)',
        )
        .eq('teacher_id', teacherId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> offers(String teacherId) async {
    final rows = await _client
        .from('commerce_offers')
        .select(
          'id,title,description,badge_text,offer_price,original_price,is_active,commerce_offer_items(id)',
        )
        .eq('teacher_id', teacherId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> pronunciationSubmissions() async {
    _applySessionHeader();
    final rows = await _client.rpc('teacher_admin_pronunciation_submissions');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<String> createPronunciationAudioUrl(String path) async {
    _applySessionHeader();
    return _client.storage
        .from('pronunciation-recordings')
        .createSignedUrl(path, 300);
  }

  Future<List<Map<String, dynamic>>> students() async {
    _applySessionHeader();
    final rows = await _client.rpc('teacher_admin_students');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> setStudentBlocked({
    required String studentId,
    required bool isBlocked,
  }) async {
    _applySessionHeader();
    await _client.rpc(
      'teacher_admin_set_student_blocked',
      params: {'p_student_id': studentId, 'p_is_blocked': isBlocked},
    );
  }

  Future<List<Map<String, dynamic>>> exams(String teacherId) async {
    final rows = await _client
        .from('exams')
        .select('id,title,is_published,created_at')
        .eq('teacher_id', teacherId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> sendNotification({
    required String title,
    required String body,
    required String actionRoute,
    String? actionId,
    String? studentId,
  }) async {
    final token = _sessionToken;
    if (token == null) throw const AuthException('انتهت جلسة المدرس');
    final requestBody = <String, dynamic>{
      'title': title.trim(),
      'body': body.trim(),
      'target_type': studentId == null ? 'all' : 'student',
      'action_route': actionRoute,
    };
    if (studentId != null) requestBody['student_id'] = studentId;
    if (actionId != null) requestBody['action_id'] = actionId;
    final response = await _client.functions.invoke(
      'send-notification',
      headers: {'x-teacher-admin-token': token},
      body: requestBody,
    );
    if (response.data is! Map) {
      throw StateError('استجابة غير متوقعة من خدمة الإشعارات');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<String> uploadFile({
    required String teacherId,
    required String folder,
    required PlatformFile file,
  }) async {
    final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path =
        '$teacherId/$folder/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    final options = FileOptions(contentType: _mimeType(file.extension));
    if (file.path != null) {
      await _client.storage
          .from(bucket)
          .upload(path, File(file.path!), fileOptions: options);
    } else if (file.bytes != null) {
      await _client.storage
          .from(bucket)
          .uploadBinary(path, file.bytes!, fileOptions: options);
    } else {
      throw StateError('تعذر قراءة الملف ${file.name}');
    }
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  Future<String> queueBackgroundVideoUpload({
    required String teacherId,
    required String folder,
    required PlatformFile file,
  }) async {
    final localPath = file.path;
    if (kIsWeb ||
        localPath == null ||
        (!Platform.isAndroid && !Platform.isIOS)) {
      return uploadFile(teacherId: teacherId, folder: folder, file: file);
    }

    final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path =
        '$teacherId/$folder/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    final signed = await _client.storage
        .from(bucket)
        .createSignedUploadUrl(path);
    await _uploadChannel.invokeMethod<void>('enqueue', {
      'id': path,
      'title': file.name,
      'filePath': localPath,
      'uploadUrl': signed.signedUrl,
      'contentType': _mimeType(file.extension) ?? 'application/octet-stream',
    });
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> createCourse({
    required TeacherAdminSession session,
    required String title,
    required String description,
    required String stage,
    required String grade,
    required double price,
    required bool isPublished,
    required String level,
    required String recommendedSkill,
    required int minPlacementScore,
    required int maxPlacementScore,
    PlatformFile? thumbnail,
  }) async {
    String? thumbnailUrl;
    if (thumbnail != null) {
      thumbnailUrl = await uploadFile(
        teacherId: session.teacherId,
        folder: 'course-images',
        file: thumbnail,
      );
    }
    final data = <String, dynamic>{
      'teacher_id': session.teacherId,
      'title': title.trim(),
      'description': description.trim(),
      'stage': stage.trim(),
      'grade': grade.trim(),
      'price': price,
      'is_published': isPublished,
      'level': level,
      'recommended_skill': recommendedSkill,
      'min_placement_score': minPlacementScore,
      'max_placement_score': maxPlacementScore,
    };
    if (thumbnailUrl != null) data['thumbnail_url'] = thumbnailUrl;
    await _client.from('courses').insert(data);
  }

  Future<String> createLecture({
    required TeacherAdminSession session,
    required String title,
    required String description,
    required String stage,
    required String grade,
    required String subject,
    required String chapter,
    required String lessonNumber,
    required double onlinePrice,
    required double centerPrice,
    required bool isPublished,
    String? courseId,
    PlatformFile? thumbnail,
    required List<PlatformFile> contentFiles,
    List<Map<String, String>> contentLinks = const [],
    List<Map<String, dynamic>> pronunciationWords = const [],
  }) async {
    String? thumbnailUrl;
    if (thumbnail != null) {
      thumbnailUrl = await uploadFile(
        teacherId: session.teacherId,
        folder: 'lecture-images',
        file: thumbnail,
      );
    }
    final data = <String, dynamic>{
      'teacher_id': session.teacherId,
      'course_id': courseId,
      'title': title.trim(),
      'description': description.trim(),
      'stage': stage.trim(),
      'grade': grade.trim(),
      'subject': subject.trim(),
      'chapter': chapter.trim(),
      'lesson_number': lessonNumber.trim(),
      'online_price': onlinePrice,
      'center_price': centerPrice,
      'price': onlinePrice,
      'is_published': isPublished,
    };
    if (thumbnailUrl != null) data['thumbnail_url'] = thumbnailUrl;
    final lecture = await _client
        .from('lectures')
        .insert(data)
        .select('id')
        .single();
    final lectureId = lecture['id'] as String;
    try {
      for (var index = 0; index < contentFiles.length; index++) {
        final file = contentFiles[index];
        final isVideo = _contentType(file.extension) == 'video';
        final url = isVideo
            ? await queueBackgroundVideoUpload(
                teacherId: session.teacherId,
                folder: 'lectures/$lectureId',
                file: file,
              )
            : await uploadFile(
                teacherId: session.teacherId,
                folder: 'lectures/$lectureId',
                file: file,
              );
        await _client.from('lecture_contents').insert({
          'lecture_id': lectureId,
          'content_type': _contentType(file.extension),
          'title': file.name,
          'file_url': url,
          'sort_order': index,
        });
      }
      for (var index = 0; index < contentLinks.length; index++) {
        await _client.from('lecture_contents').insert({
          'lecture_id': lectureId,
          'content_type': 'link',
          'title': contentLinks[index]['title'] ?? 'رابط إضافي',
          'file_url': contentLinks[index]['url'],
          'sort_order': contentFiles.length + index,
        });
      }
      if (pronunciationWords.isNotEmpty) {
        await _client.from('lecture_pronunciation_words').insert([
          for (var index = 0; index < pronunciationWords.length; index++)
            {
              'lecture_id': lectureId,
              'word': pronunciationWords[index]['word'],
              'max_duration_seconds':
                  pronunciationWords[index]['max_duration_seconds'],
              'sort_order': index,
              'is_published': isPublished,
            },
        ]);
      }
    } catch (_) {
      await _client
          .from('lecture_contents')
          .delete()
          .eq('lecture_id', lectureId);
      await _client.from('lectures').delete().eq('id', lectureId);
      rethrow;
    }
    return lectureId;
  }

  Future<String> createExam({
    required TeacherAdminSession session,
    required String lectureId,
    required String title,
    required String description,
    required int durationMinutes,
    required int maxAttempts,
    required int passScore,
    required bool isPublished,
    required List<Map<String, dynamic>> questions,
  }) async {
    final lecture = await _client
        .from('lectures')
        .select('stage,grade,chapter')
        .eq('id', lectureId)
        .single();
    final totalScore = questions.fold<int>(
      0,
      (sum, question) => sum + ((question['points'] as num?)?.toInt() ?? 1),
    );
    final exam = await _client
        .from('exams')
        .insert({
          'teacher_id': session.teacherId,
          'lecture_id': lectureId,
          'title': title.trim(),
          'description': description.trim(),
          'stage': lecture['stage'],
          'grade': lecture['grade'],
          'chapter': lecture['chapter'],
          'duration_minutes': durationMinutes,
          'max_attempts': maxAttempts,
          'total_score': totalScore,
          'pass_score': passScore,
          'questions_count': questions.length,
          'is_published': isPublished,
          'exam_type': 'exam',
        })
        .select('id')
        .single();
    final examId = exam['id'] as String;
    try {
      final questionRows = <Map<String, dynamic>>[];
      for (var index = 0; index < questions.length; index++) {
        final question = questions[index];
        String? mediaUrl;
        final media = question['media'] as PlatformFile?;
        if (media != null) {
          mediaUrl = await uploadFile(
            teacherId: session.teacherId,
            folder: 'exams/$examId',
            file: media,
          );
        }
        final mediaType = question['media_type'] as String? ?? 'text';
        final answerType = question['answer_type'] as String? ?? 'mcq';
        questionRows.add({
          'exam_id': examId,
          'question_number': index + 1,
          // Keep the legacy enum limited to response types. Question media is
          // represented by image_url/audio_url and inferred by the app.
          'question_type': answerType,
          'answer_type': answerType,
          'question_text': question['question_text'],
          'options': question['options'] ?? const <String>[],
          'correct_answer': question['correct_answer'],
          'points': question['points'],
          if (mediaType == 'image') 'image_url': mediaUrl,
          if (mediaType == 'audio') 'audio_url': mediaUrl,
        });
      }
      await _client.from('exam_questions').insert(questionRows);
      return examId;
    } catch (error, stackTrace) {
      try {
        await _client.from('exam_questions').delete().eq('exam_id', examId);
      } catch (_) {}
      try {
        await _client.from('exams').delete().eq('id', examId);
      } catch (_) {}
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> createOffer({
    required TeacherAdminSession session,
    required String title,
    required String description,
    required String badge,
    required double offerPrice,
    double? originalPrice,
    required int? accessDurationDays,
    required int? viewLimit,
    required List<Map<String, String>> items,
  }) async {
    final offer = await _client
        .from('commerce_offers')
        .insert({
          'teacher_id': session.teacherId,
          'title': title.trim(),
          'description': description.trim(),
          'badge_text': badge.trim().isEmpty ? null : badge.trim(),
          'offer_price': offerPrice,
          'original_price': originalPrice,
          'is_active': true,
        })
        .select('id')
        .single();
    final offerId = offer['id'] as String;
    try {
      await _client.from('commerce_offer_items').insert([
        for (var index = 0; index < items.length; index++)
          {
            'offer_id': offerId,
            'item_type': items[index]['type'],
            if (items[index]['type'] == 'lecture')
              'lecture_id': items[index]['id'],
            if (items[index]['type'] == 'course')
              'course_id': items[index]['id'],
            'access_duration_days': accessDurationDays,
            'view_limit': viewLimit,
            'sort_order': index,
          },
      ]);
    } catch (_) {
      await _client.from('commerce_offers').delete().eq('id', offerId);
      rethrow;
    }
  }

  static String _contentType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'mp4':
      case 'mov':
      case 'mkv':
      case 'webm':
      case 'm3u8':
        return 'video';
      case 'pdf':
        return 'pdf';
      case 'mp3':
      case 'm4a':
      case 'wav':
      case 'aac':
        return 'audio';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
        return 'image';
      default:
        return 'file';
    }
  }

  static String? _mimeType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'mp4':
        return 'video/mp4';
      case 'webm':
        return 'video/webm';
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'mp3':
        return 'audio/mpeg';
      default:
        return null;
    }
  }
}
