import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/helpers/app_logger.dart';
import '../models/banner_model.dart';
import '../models/home_summary_model.dart';
import '../models/leaderboard_entry_model.dart';
import '../models/leaderboard_result_model.dart';
import '../models/teacher_model.dart';

abstract class HomeRemoteDataSource {
  Future<HomeSummaryModel> getHomeSummary();

  Future<LeaderboardResultModel> getLeaderboard({
    String? examId,
    String? grade,
    String? stage,
    bool challengesOnly = false,
  });
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final SupabaseClient _supabaseClient;

  HomeRemoteDataSourceImpl(this._supabaseClient);

  @override
  Future<HomeSummaryModel> getHomeSummary() async {
    AppLogger.authLog(
      'Fetching Home Summary from Supabase for teacher ${AppConstants.activeTeacherId}',
    );

    final currentUser = _supabaseClient.auth.currentUser;
    final metadata = currentUser?.userMetadata ?? const <String, dynamic>{};
    String studentName = metadata['name'] as String? ?? 'الطالب';
    String grade = metadata['grade'] as String? ?? 'الصف الدراسي';
    String educationLevel =
        metadata['education_level'] as String? ?? 'المرحلة الدراسية';
    int points = 0;
    String? currentUserId = currentUser?.id;

    if (currentUserId != null) {
      try {
        final profile = await _supabaseClient
            .from('students')
            .select()
            .eq('id', currentUserId)
            .maybeSingle();

        if (profile != null) {
          studentName = profile['name'] as String? ?? studentName;
          grade = profile['grade'] as String? ?? grade;
          educationLevel =
              profile['education_level'] as String? ?? educationLevel;
          points = (profile['points'] as num?)?.toInt() ?? points;
        }

        // Ensure points reflect all completed exam submissions
        final examScores = await _supabaseClient
            .from('exam_submissions')
            .select('score')
            .eq('student_id', currentUserId);
        if (examScores.isNotEmpty) {
          final totalExamScore = examScores.fold<int>(
            0,
            (sum, item) => sum + ((item['score'] as num?)?.toInt() ?? 0),
          );
          if (totalExamScore > points) {
            points = totalExamScore;
            // Background sync back to students table
            _supabaseClient
                .from('students')
                .update({'points': points})
                .eq('id', currentUserId)
                .then((_) {})
                .catchError((_) {});
          }
        }
      } catch (e) {
        AppLogger.authLog(
          'Error fetching student profile for home',
          error: e.toString(),
        );
      }
    }

    // Query Specific Configured Teacher
    TeacherModel? teacherModel;
    try {
      final teacherData = await _supabaseClient
          .from('teachers')
          .select()
          .eq('id', AppConstants.activeTeacherId)
          .maybeSingle();

      if (teacherData != null) {
        teacherModel = TeacherModel.fromJson(teacherData);
      }
    } catch (e) {
      AppLogger.authLog('Error fetching teacher', error: e.toString());
    }

    List<BannerModel> banners = [];
    try {
      final List<dynamic> bannerData = await _supabaseClient
          .from('home_banners')
          .select()
          .eq('teacher_id', AppConstants.activeTeacherId)
          .eq('is_active', true)
          .order('sort_order');
      banners = bannerData
          .map((item) => BannerModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.authLog('Error fetching home banners', error: e.toString());
    }

    // Upcoming Exam for this grade / stage scoped to active teacher
    UpcomingExamModel? upcomingExam;
    try {
      final examData = await _supabaseClient
          .from('exams')
          .select()
          .eq('teacher_id', AppConstants.activeTeacherId)
          .eq('exam_type', 'exam')
          .eq('is_published', true)
          .eq('grade', grade)
          .order('scheduled_at')
          .limit(1)
          .maybeSingle();

      if (examData != null) {
        upcomingExam = UpcomingExamModel.fromJson(examData);
      }
    } catch (e) {
      AppLogger.authLog('Error fetching upcoming exam', error: e.toString());
    }

    // Top 3 Leaderboard for current student's grade specifically
    List<LeaderboardEntryModel> top3 = [];
    int userRank = 1;
    int totalStudentsInGrade = 1;

    try {
      final gradeLeaderboard = await getLeaderboard(grade: grade);
      top3 = gradeLeaderboard.entries.take(3).toList();
      userRank = gradeLeaderboard.currentUserEntry?.rank ?? 1;
      totalStudentsInGrade = gradeLeaderboard.totalCount;
    } catch (e) {
      AppLogger.authLog(
        'Error fetching grade leaderboard for home',
        error: e.toString(),
      );
    }

    // Unread Notifications Count
    int unreadNotificationsCount = 0;
    try {
      final notifQuery = _supabaseClient
          .from('notifications')
          .select('id')
          .eq('student_id', currentUserId!)
          .eq('is_read', false);

      final List<dynamic> notifData = await notifQuery;
      unreadNotificationsCount = notifData.length;
    } catch (_) {
      unreadNotificationsCount = 0;
    }

    return HomeSummaryModel(
      studentName: studentName,
      grade: grade,
      educationLevel: educationLevel,
      points: points,
      unreadNotificationsCount: unreadNotificationsCount,
      banners: banners,
      upcomingExam: upcomingExam,
      topLeaderboard: top3,
      userRank: userRank,
      totalStudentsCount: totalStudentsInGrade,
      teacher: teacherModel,
    );
  }

  @override
  Future<LeaderboardResultModel> getLeaderboard({
    String? examId,
    String? grade,
    String? stage,
    bool challengesOnly = false,
  }) async {
    final currentUserId = _supabaseClient.auth.currentUser?.id;
    AppLogger.authLog(
      'Fetching Leaderboard from Supabase',
      data: {
        'examId': examId,
        'grade': grade,
        'stage': stage,
        'userId': currentUserId,
      },
    );

    try {
      if (challengesOnly) {
        final List<dynamic> rows =
            await _supabaseClient.rpc('get_challenge_leaderboard')
                as List<dynamic>;
        final entries = rows.map((row) {
          final item = row as Map<String, dynamic>;
          final studentId = item['student_id'] as String? ?? '';
          return LeaderboardEntryModel(
            studentId: studentId,
            name: item['name'] as String? ?? 'طالب',
            rank: (item['rank'] as num?)?.toInt() ?? 0,
            points: (item['points'] as num?)?.toInt() ?? 0,
            isCurrentUser: studentId == currentUserId,
          );
        }).toList();
        LeaderboardEntryModel? current;
        for (final entry in entries) {
          if (entry.isCurrentUser) current = entry;
        }
        return LeaderboardResultModel(
          entries: entries,
          totalCount: entries.length,
          currentUserEntry: current,
          currentGrade: null,
        );
      }

      if (examId != null) {
        // Exam-specific leaderboard from exam_submissions
        final List<dynamic> submissions = await _supabaseClient
            .from('exam_submissions')
            .select()
            .eq('exam_id', examId)
            .order('score', ascending: false)
            .order('time_taken_seconds', ascending: true)
            .order('submitted_at', ascending: true)
            .limit(100);

        final entries = submissions.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final item = entry.value as Map<String, dynamic>;
          final sId = item['student_id'] as String? ?? '';
          return LeaderboardEntryModel(
            studentId: sId,
            name: item['student_name'] as String? ?? 'طالب',
            rank: idx,
            points: (item['score'] as num?)?.toInt() ?? 0,
            avatarUrl: item['avatar_url'] as String?,
            isCurrentUser: currentUserId != null && currentUserId == sId,
          );
        }).toList();

        LeaderboardEntryModel? currentUserEntry;
        for (final e in entries) {
          if (e.isCurrentUser) {
            currentUserEntry = e;
            break;
          }
        }

        return LeaderboardResultModel(
          entries: entries,
          totalCount: entries.length,
          currentUserEntry: currentUserEntry,
          currentGrade: grade,
        );
      }

      // General / Grade Leaderboard from public.students table
      // Scalable query with limit to maintain fast response times
      PostgrestFilterBuilder filterQuery = _supabaseClient
          .from('students')
          .select('id, name, points, grade, education_level, created_at');

      if (grade != null && grade.isNotEmpty) {
        filterQuery = filterQuery.eq('grade', grade);
      } else if (stage != null && stage.isNotEmpty) {
        filterQuery = filterQuery.eq('education_level', stage);
      }

      final List<dynamic> studentsData = await filterQuery
          .order('points', ascending: false)
          .order('created_at', ascending: true)
          .limit(100);

      // Fast count query for total students in this grade / stage
      int totalCount = studentsData.length;
      try {
        var countQuery = _supabaseClient
            .from('students')
            .count(CountOption.exact);
        if (grade != null && grade.isNotEmpty) {
          countQuery = countQuery.eq('grade', grade);
        } else if (stage != null && stage.isNotEmpty) {
          countQuery = countQuery.eq('education_level', stage);
        }
        totalCount = await countQuery;
      } catch (_) {}

      final List<LeaderboardEntryModel> entries = studentsData
          .asMap()
          .entries
          .map((entry) {
            final idx = entry.key + 1;
            final item = entry.value as Map<String, dynamic>;
            final sId = item['id'] as String? ?? '';
            return LeaderboardEntryModel(
              studentId: sId,
              name: item['name'] as String? ?? 'طالب',
              rank: idx,
              points: (item['points'] as num?)?.toInt() ?? 0,
              grade: item['grade'] as String?,
              educationLevel: item['education_level'] as String?,
              avatarUrl: item['avatar_url'] as String?,
              isCurrentUser: currentUserId != null && currentUserId == sId,
            );
          })
          .toList();

      LeaderboardEntryModel? currentUserEntry;
      if (currentUserId != null) {
        for (final e in entries) {
          if (e.isCurrentUser) {
            currentUserEntry = e;
            break;
          }
        }

        // If user is not in the top 100 entries, calculate their exact rank accurately
        if (currentUserEntry == null) {
          try {
            final userProfile = await _supabaseClient
                .from('students')
                .select('id, name, points, grade, education_level')
                .eq('id', currentUserId)
                .maybeSingle();

            if (userProfile != null) {
              final userGrade = userProfile['grade'] as String? ?? '';
              final matchesFilter =
                  (grade == null || grade.isEmpty || grade == userGrade);

              if (matchesFilter) {
                final userPts = (userProfile['points'] as num?)?.toInt() ?? 0;
                var rankCountQuery = _supabaseClient
                    .from('students')
                    .count(CountOption.exact)
                    .gt('points', userPts);

                if (grade != null && grade.isNotEmpty) {
                  rankCountQuery = rankCountQuery.eq('grade', grade);
                } else if (stage != null && stage.isNotEmpty) {
                  rankCountQuery = rankCountQuery.eq('education_level', stage);
                }

                final higherCount = await rankCountQuery;
                currentUserEntry = LeaderboardEntryModel(
                  studentId: currentUserId,
                  name: userProfile['name'] as String? ?? 'أنت',
                  rank: higherCount + 1,
                  points: userPts,
                  grade: userProfile['grade'] as String?,
                  educationLevel: userProfile['education_level'] as String?,
                  isCurrentUser: true,
                );
              }
            }
          } catch (e) {
            AppLogger.authLog(
              'Error fetching current user rank for leaderboard',
              error: e.toString(),
            );
          }
        }
      }

      return LeaderboardResultModel(
        entries: entries,
        totalCount: totalCount > 0 ? totalCount : entries.length,
        currentUserEntry: currentUserEntry,
        currentGrade: grade,
      );
    } catch (e) {
      AppLogger.authLog(
        'Leaderboard fetch error from Supabase',
        error: e.toString(),
      );
      return const LeaderboardResultModel(
        entries: [],
        totalCount: 0,
        currentUserEntry: null,
      );
    }
  }
}
