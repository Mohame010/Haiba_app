import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../models/lecture_model.dart';

abstract class LecturesRemoteDataSource {
  Future<List<LectureModel>> getStudentLectures();

  Future<LectureModel> getLectureDetails(String lectureId);

  Future<bool> purchaseLecture({
    required String lectureId,
    required double amountPaid,
    required bool isCenterStudent,
    required String paymentMethod,
    String? invoiceId,
    String? paymentReference,
  });
}

class LecturesRemoteDataSourceImpl implements LecturesRemoteDataSource {
  final SupabaseClient _supabaseClient;

  LecturesRemoteDataSourceImpl(this._supabaseClient);

  void _log(String message) {
    debugPrint('[Q360-LECTURES] $message');
    dev.log(message, name: 'Q360.Lectures');
  }

  double _onlinePrice(Map<String, dynamic> lecture) =>
      (lecture['online_price'] as num?)?.toDouble() ??
      (lecture['price'] as num?)?.toDouble() ??
      0;

  Future<List<dynamic>> _fetchOptionalList(
    String source,
    Future<dynamic> Function() fetch,
  ) async {
    try {
      final result = await fetch();
      return result is List<dynamic> ? result : <dynamic>[];
    } catch (error) {
      _log('⚠️ Error fetching $source: $error');
      return <dynamic>[];
    }
  }

  @override
  Future<List<LectureModel>> getStudentLectures() async {
    final currentUserId = _supabaseClient.auth.currentUser?.id;
    _log('===============================================================');
    _log('🚀 [START] Fetching student lectures from Supabase');
    _log('👤 Current User Auth ID: $currentUserId');
    _log('🎯 Default Active Teacher ID: ${AppConstants.activeTeacherId}');

    try {
      // 1. Get student profile
      String? studentGrade;
      String? studentStage;
      String targetTeacherId = AppConstants.activeTeacherId;
      List<String> accessibleLectureIds = [];
      List<String> centerAttendedLectureIds = [];

      if (currentUserId != null) {
        try {
          _log('🔍 Querying "students" table for ID: $currentUserId');
          final studentData = await _supabaseClient
              .from('students')
              // teacher_id and related_lectures are optional legacy columns.
              // Selecting all available fields keeps older schemas usable.
              .select()
              .eq('id', currentUserId)
              .maybeSingle();

          _log('📋 Student Profile Record: $studentData');

          if (studentData != null) {
            studentGrade = studentData['grade'] as String?;
            studentStage = studentData['education_level'] as String?;
            final tId = studentData['teacher_id'] as String?;
            if (tId != null && tId.isNotEmpty) {
              targetTeacherId = tId;
            }

            final related = studentData['related_lectures'] as List<dynamic>?;
            if (related != null) {
              for (var id in related) {
                if (id is String && !accessibleLectureIds.contains(id)) {
                  accessibleLectureIds.add(id);
                }
              }
            }
          }

          // An unfinished lesson remains accessible for resume even when the
          // old repeated-open bug already exhausted its view counter.
          final unfinishedLectureIds = <String>{};
          try {
            final activityRows = await _supabaseClient
                .from('student_learning_activity')
                .select('lecture_id,position_seconds,duration_seconds')
                .eq('student_id', currentUserId);
            for (final row in activityRows) {
              final position = (row['position_seconds'] as num?)?.toInt() ?? 0;
              final duration = (row['duration_seconds'] as num?)?.toInt() ?? 0;
              final lectureId = row['lecture_id'] as String?;
              if (lectureId != null &&
                  position > 0 &&
                  duration > 0 &&
                  position < duration - 2) {
                unfinishedLectureIds.add(lectureId);
              }
            }
          } catch (_) {}

          // Check direct lecture access
          final accessData = await _supabaseClient
              .from('student_lecture_access')
              .select(
                'lecture_id, is_unlocked, expires_at, view_limit, views_used',
              )
              .eq('student_id', currentUserId)
              .eq('is_unlocked', true);
          for (var item in (accessData as List<dynamic>)) {
            final expiresAt = DateTime.tryParse(
              item['expires_at'] as String? ?? '',
            );
            final viewLimit = (item['view_limit'] as num?)?.toInt();
            final viewsUsed = (item['views_used'] as num?)?.toInt() ?? 0;
            final isExpired =
                expiresAt != null && !expiresAt.isAfter(DateTime.now());
            final isExhausted = viewLimit != null && viewsUsed >= viewLimit;
            final id = item['lecture_id'] as String?;
            if (isExpired ||
                (isExhausted && !unfinishedLectureIds.contains(id))) {
              continue;
            }
            if (id != null && !accessibleLectureIds.contains(id)) {
              accessibleLectureIds.add(id);
            }
          }

          // Center attendance is stored in group_attendance in the current
          // schema. Keep it optional because older deployments may not have
          // the table (or may not expose it to students through RLS).
          try {
            final attendanceData = await _supabaseClient
                .from('group_attendance')
                .select('lecture_id')
                .eq('student_id', currentUserId);

            for (var item in (attendanceData as List<dynamic>)) {
              final id = item['lecture_id'] as String?;
              if (id != null && !centerAttendedLectureIds.contains(id)) {
                centerAttendedLectureIds.add(id);
              }
            }
          } catch (error) {
            _log('⚠️ Optional group attendance unavailable: $error');
          }
        } catch (e, stack) {
          _log('⚠️ Error fetching student details: $e\n$stack');
        }
      }

      _log(
        '🎯 Target Teacher: $targetTeacherId | Grade: $studentGrade | Stage: $studentStage',
      );

      // 2. Fetch lectures from Supabase
      List<dynamic> rawLectures = [];
      try {
        _log(
          '🔍 Executing query: lectures where is_published=true & teacher_id=$targetTeacherId & grade=$studentGrade & stage=$studentStage',
        );
        var query = _supabaseClient
            .from('lectures')
            .select('*')
            .eq('is_published', true)
            .eq('teacher_id', targetTeacherId);

        if (studentGrade != null && studentGrade.isNotEmpty) {
          query = query.eq('grade', studentGrade);
        }
        if (studentStage != null && studentStage.isNotEmpty) {
          query = query.eq('stage', studentStage);
        }

        final res = await query.order('created_at', ascending: true);
        rawLectures = res as List<dynamic>;
        _log('📦 Filtered query returned: ${rawLectures.length} lectures');

        // Fallback 1: Query by teacher_id alone (if grade/stage filter didn't match)
        if (rawLectures.isEmpty) {
          _log(
            'ℹ️ No lectures with exact grade/stage. Querying all published lectures for teacher_id=$targetTeacherId...',
          );
          final teacherRes = await _supabaseClient
              .from('lectures')
              .select('*')
              .eq('is_published', true)
              .eq('teacher_id', targetTeacherId)
              .order('created_at', ascending: true);
          rawLectures = teacherRes as List<dynamic>;
          _log(
            '📦 Teacher-only query returned: ${rawLectures.length} lectures',
          );
        }

        // Fallback 2: Query all published lectures if teacher_id also had 0 rows
        if (rawLectures.isEmpty) {
          _log(
            'ℹ️ Querying ALL published lectures in "lectures" table (any teacher)...',
          );
          final allRes = await _supabaseClient
              .from('lectures')
              .select('*')
              .eq('is_published', true)
              .order('created_at', ascending: true);
          rawLectures = allRes as List<dynamic>;
          _log(
            '📦 All-published query returned: ${rawLectures.length} lectures',
          );
        }

        // Diagnostic: Unfiltered query (no is_published condition) to detect RLS or is_published=null
        if (rawLectures.isEmpty) {
          _log(
            '🔬 [DIAGNOSTIC] Querying "lectures" table with NO filters at all .select("*")...',
          );
          final unfiltered = await _supabaseClient.from('lectures').select('*');
          final unfilteredList = unfiltered as List<dynamic>;
          _log(
            '🔬 [DIAGNOSTIC] Unfiltered query returned: ${unfilteredList.length} rows.',
          );
          if (unfilteredList.isNotEmpty) {
            _log(
              '🔬 [DIAGNOSTIC] First unfiltered row: ${unfilteredList.first}',
            );
            rawLectures = unfilteredList;
          }
        }
      } catch (e, stack) {
        _log('❌ Error querying "lectures" table: $e\n$stack');
        throw Exception('فشل في جلب الدروس من قاعدة البيانات: $e');
      }

      if (rawLectures.isEmpty) {
        _log('⚠️ "lectures" table returned 0 rows in Supabase.');
        _log('===============================================================');
        return [];
      }

      _log('✅ Found ${rawLectures.length} lectures in database:');
      for (var i = 0; i < rawLectures.length; i++) {
        final l = rawLectures[i] as Map<String, dynamic>;
        _log(
          '   [$i] ID: ${l['id']} | Title: "${l['title']}" | TeacherID: ${l['teacher_id']} | Grade: ${l['grade']} | Stage: ${l['stage']} | OnlinePrice: ${_onlinePrice(l)}',
        );
      }

      // 3. Fetch teachers, contents, and exams. Videos are represented by
      // lecture_contents rows whose content_type is "video".
      final teachersList = await _fetchOptionalList(
        'teachers',
        () => _supabaseClient.from('teachers').select('*'),
      );
      _log('👨‍🏫 Teachers fetched: ${teachersList.length}');

      final contentsList = await _fetchOptionalList(
        'lecture_contents',
        () => _supabaseClient
            .from('lecture_contents')
            .select('*')
            .order('sort_order', ascending: true),
      );
      _log('📄 Lecture contents fetched: ${contentsList.length}');

      final courseLectureLinks = await _fetchOptionalList(
        'course_lectures',
        () => _supabaseClient
            .from('course_lectures')
            .select('course_id, lecture_id, sort_order')
            .order('sort_order', ascending: true),
      );
      final courseLinkByLecture = <String, dynamic>{
        for (final link in courseLectureLinks)
          if (link['lecture_id'] is String) link['lecture_id'] as String: link,
      };

      final examsList = await _fetchOptionalList(
        'exams',
        () => _supabaseClient
            .from('exams')
            .select('*')
            .eq('is_published', true)
            .order('created_at', ascending: false),
      );
      _log('📝 Exams fetched: ${examsList.length}');

      final teachersMap = {for (var t in teachersList) t['id'] as String?: t};
      final contentsMap = <String, List<dynamic>>{};
      for (var c in contentsList) {
        final lId = c['lecture_id'] as String?;
        if (lId != null) {
          contentsMap.putIfAbsent(lId, () => []).add(c);
        }
      }
      final examsMap = <String, dynamic>{};
      for (final exam in examsList) {
        final lectureId = exam['lecture_id'] as String?;
        if (lectureId != null) examsMap.putIfAbsent(lectureId, () => exam);
      }

      // 4. Fetch purchase stats
      Map<String, Map<String, int>> lectureStats = {};
      try {
        final purchasesData = await _supabaseClient
            .from('lecture_purchases')
            .select('lecture_id, is_center_student');

        for (var p in (purchasesData as List<dynamic>)) {
          final lId = p['lecture_id'] as String?;
          final isCenter = p['is_center_student'] == true;
          if (lId != null) {
            lectureStats.putIfAbsent(
              lId,
              () => {'total': 0, 'center': 0, 'online': 0},
            );
            lectureStats[lId]!['total'] =
                (lectureStats[lId]!['total'] ?? 0) + 1;
            if (isCenter) {
              lectureStats[lId]!['center'] =
                  (lectureStats[lId]!['center'] ?? 0) + 1;
            } else {
              lectureStats[lId]!['online'] =
                  (lectureStats[lId]!['online'] ?? 0) + 1;
            }
          }
        }
      } catch (_) {}

      final result = rawLectures.map((item) {
        final map = Map<String, dynamic>.from(item as Map<String, dynamic>);
        final lectureId = map['id'] as String? ?? '';
        final teacherId = map['teacher_id'] as String?;
        final price = _onlinePrice(map);
        final courseLink = courseLinkByLecture[lectureId];
        if (courseLink is Map) {
          map['course_id'] ??= courseLink['course_id'];
          map['_course_sort_order'] = courseLink['sort_order'];
        }

        if (teacherId != null && teachersMap.containsKey(teacherId)) {
          map['teachers'] = teachersMap[teacherId];
        }
        if (contentsMap.containsKey(lectureId)) {
          map['lecture_contents'] = contentsMap[lectureId];
        }
        if (examsMap.containsKey(lectureId)) {
          map['exams'] = examsMap[lectureId];
        }

        final isCenterStudent = centerAttendedLectureIds.contains(lectureId);
        final hasAccess =
            price == 0 || accessibleLectureIds.contains(lectureId);
        final stats =
            lectureStats[lectureId] ?? {'total': 0, 'center': 0, 'online': 0};
        return LectureModel.fromJson(
          map,
          hasAccess: hasAccess,
          isCenterStudent: isCenterStudent,
          enrolledCount: stats['total'] ?? 0,
          centerCount: stats['center'] ?? 0,
          onlineCount: stats['online'] ?? 0,
        );
      }).toList();

      _log(
        '🎉 Successfully constructed ${result.length} LectureModels to display',
      );
      _log('===============================================================');
      return result;
    } catch (e, stack) {
      _log('💥 Fatal error in getStudentLectures: $e\n$stack');
      _log('===============================================================');
      rethrow;
    }
  }

  @override
  Future<LectureModel> getLectureDetails(String lectureId) async {
    _log('===============================================================');
    _log('🔍 [START] Fetching lecture details for lectureId: $lectureId');

    // 1. Fetch all content, including videos, from lecture_contents.
    List<dynamic> contentsList = [];
    try {
      final contents = await _supabaseClient
          .from('lecture_contents')
          .select('*')
          .eq('lecture_id', lectureId)
          .order('sort_order', ascending: true);
      contentsList = contents as List<dynamic>;
      _log(
        '📄 Found ${contentsList.length} contents in lecture_contents table: $contentsList',
      );
    } catch (e) {
      _log('⚠️ lecture_contents query error: $e');
    }

    // 2. Fetch lecture row from lectures table
    Map<String, dynamic>? lectureData;
    try {
      final res = await _supabaseClient
          .from('lectures')
          .select('*')
          .eq('id', lectureId)
          .maybeSingle();
      lectureData = res;
      _log('📖 Lecture row from "lectures" table: $lectureData');
    } catch (e, stack) {
      _log('❌ Error querying lectures table: $e\n$stack');
      throw Exception('فشل في جلب بيانات الدرس: $e');
    }

    if (lectureData == null) {
      _log('❌ Lecture not found in DB with ID: $lectureId');
      _log('===============================================================');
      throw Exception(
        'لم يتم العثور على الدرس في قاعدة البيانات (ID: $lectureId)',
      );
    }

    if (lectureData['course_id'] == null) {
      try {
        final courseLink = await _supabaseClient
            .from('course_lectures')
            .select('course_id, sort_order')
            .eq('lecture_id', lectureId)
            .limit(1)
            .maybeSingle();
        if (courseLink != null) {
          lectureData['course_id'] = courseLink['course_id'];
          lectureData['_course_sort_order'] = courseLink['sort_order'];
        }
      } catch (error) {
        _log('⚠️ Course mapping unavailable for lecture $lectureId: $error');
      }
    }

    // 3. Fetch teacher details if teacher_id exists
    final teacherId = lectureData['teacher_id'] as String?;
    if (teacherId != null && teacherId.isNotEmpty) {
      try {
        final teacherRes = await _supabaseClient
            .from('teachers')
            .select('*')
            .eq('id', teacherId)
            .maybeSingle();
        if (teacherRes != null) {
          lectureData['teachers'] = teacherRes;
          _log('👨‍🏫 Teacher data: ${teacherRes['name']}');
        }
      } catch (_) {}
    }

    // 4. Fetch attached exam details
    try {
      final examRes = await _supabaseClient
          .from('exams')
          .select('*')
          .eq('lecture_id', lectureId)
          .eq('is_published', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (examRes != null) {
        lectureData['exams'] = examRes;
        _log('📝 Exam data: ${examRes['title']}');
      }
    } catch (_) {}

    lectureData['lecture_contents'] = contentsList;

    final price = _onlinePrice(lectureData);
    if (price > 0) {
      final access = await _supabaseClient.rpc(
        'consume_lecture_access',
        params: {'p_lecture_id': lectureId},
      );
      final allowed = access is Map && access['allowed'] == true;
      if (!allowed) {
        final reason = access is Map ? access['reason']?.toString() : null;
        _log('❌ Lecture access denied: reason=$reason, response=$access');
        throw Exception(switch (reason) {
          'expired' => 'انتهت صلاحية الحصة',
          'view_limit_reached' => 'استنفدت عدد المشاهدات المتاح',
          'not_unlocked' => 'الحصة غير مفعلة لهذا الحساب',
          'authentication_required' => 'يجب تسجيل الدخول أولًا',
          _ => 'تعذر التحقق من صلاحية الحصة',
        });
      }
      _log('✅ Lecture access allowed: $access');
    }

    final model = LectureModel.fromJson(lectureData, hasAccess: true);

    _log(
      '🎉 LectureModel built: title="${model.title}", contentsCount=${model.contents.length}',
    );
    _log('===============================================================');
    return model;
  }

  @override
  Future<bool> purchaseLecture({
    required String lectureId,
    required double amountPaid,
    required bool isCenterStudent,
    required String paymentMethod,
    String? invoiceId,
    String? paymentReference,
  }) async {
    final currentUserId = _supabaseClient.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('يجب تسجيل الدخول أولاً لإتمام الشراء');
    }

    try {
      _log(
        '💳 Recording lecture purchase for student=$currentUserId, lecture=$lectureId, amount=$amountPaid',
      );

      // 1. Insert into lecture_purchases
      await _supabaseClient.from('lecture_purchases').upsert({
        'student_id': currentUserId,
        'lecture_id': lectureId,
        'amount_paid': amountPaid,
        'is_center_student': isCenterStudent,
        'payment_gateway': 'fawaterk',
        'invoice_id': invoiceId,
        'payment_method': paymentMethod,
        'payment_status': 'paid',
      });

      // 2. Grant direct access in student_lecture_access
      await _supabaseClient.from('student_lecture_access').upsert({
        'student_id': currentUserId,
        'lecture_id': lectureId,
      });

      _log('✅ Successfully recorded lecture purchase');
      return true;
    } catch (e, stack) {
      _log('❌ Error saving lecture purchase: $e\n$stack');
      rethrow;
    }
  }
}
