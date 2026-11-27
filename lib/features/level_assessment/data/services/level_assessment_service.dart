import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/level_assessment.dart';

class LevelAssessmentService {
  LevelAssessmentService._();

  static final instance = LevelAssessmentService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<LevelAssessmentResult?> latestResult() async {
    if (_client.auth.currentUser == null) return null;
    final row = await _client
        .from('placement_assessment_attempts')
        .select()
        .order('completed_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return LevelAssessmentResult.fromMap(row);
  }

  Future<LevelAssessmentResult> submit({
    required LevelAssessmentResult result,
    required Map<String, int> answers,
  }) async {
    final response = await _client.rpc(
      'submit_placement_assessment',
      params: {
        'p_pronunciation_score': result.pronunciationScore,
        'p_reading_score': result.readingScore,
        'p_writing_score': result.writingScore,
        'p_answers': answers,
      },
    );
    final map = response is List
        ? Map<String, dynamic>.from(response.first as Map)
        : Map<String, dynamic>.from(response as Map);
    return LevelAssessmentResult.fromMap(map);
  }
}
