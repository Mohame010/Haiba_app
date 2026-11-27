import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/helpers/app_logger.dart';
import '../models/exam_model.dart';

abstract class ExamsRemoteDataSource {
  Future<List<ExamModel>> getExams();

  Future<ExamModel> getExamDetails(String examId);

  Future<ExamSubmissionModel> submitExam({
    required String examId,
    required Map<String, String> answers,
    required int timeTakenSeconds,
  });
}

class ExamsRemoteDataSourceImpl implements ExamsRemoteDataSource {
  final SupabaseClient _supabaseClient;

  ExamsRemoteDataSourceImpl(this._supabaseClient);

  @override
  Future<List<ExamModel>> getExams() async {
    AppLogger.authLog(
      'Fetching exams from Supabase for teacher ${AppConstants.activeTeacherId}',
    );

    try {
      final List<dynamic> data = await _supabaseClient
          .from('exams')
          .select('*, exam_questions(*), exam_submissions(id)')
          .eq('teacher_id', AppConstants.activeTeacherId)
          .eq('is_published', true)
          .order('created_at', ascending: false);

      return data
          .map((item) => ExamModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.authLog(
        'Error fetching exams from Supabase',
        error: e.toString(),
      );
      rethrow;
    }
  }

  @override
  Future<ExamModel> getExamDetails(String examId) async {
    try {
      final data = await _supabaseClient
          .from('exams')
          .select('*, exam_questions(*), exam_submissions(id)')
          .eq('id', examId)
          .maybeSingle();

      if (data != null) {
        return ExamModel.fromJson(data);
      }
      throw StateError('Exam not found: $examId');
    } catch (e) {
      AppLogger.authLog(
        'Error fetching exam details from Supabase',
        error: e.toString(),
      );
      rethrow;
    }
  }

  @override
  Future<ExamSubmissionModel> submitExam({
    required String examId,
    required Map<String, String> answers,
    required int timeTakenSeconds,
  }) async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw const AuthException('يجب تسجيل الدخول أولاً');

    try {
      final response = await _supabaseClient.rpc(
        'submit_exam_answers',
        params: {
          'p_exam_id': examId,
          'p_answers': answers,
          'p_time_taken_seconds': timeTakenSeconds,
        },
      );
      return ExamSubmissionModel.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    } catch (e) {
      AppLogger.authLog(
        'Error submitting exam to Supabase',
        error: e.toString(),
      );
      rethrow;
    }
  }
}
