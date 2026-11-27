import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../data/level_assessment_questions.dart';
import '../../data/services/level_assessment_service.dart';
import '../../domain/entities/level_assessment.dart';

class LevelAssessmentScreen extends StatefulWidget {
  const LevelAssessmentScreen({super.key});

  @override
  State<LevelAssessmentScreen> createState() => _LevelAssessmentScreenState();
}

class _LevelAssessmentScreenState extends State<LevelAssessmentScreen> {
  int _index = 0;
  final Map<String, int> _answers = {};
  bool _submitting = false;
  LevelAssessmentResult? _result;
  bool _saved = true;

  LevelAssessmentQuestion get _question => levelAssessmentQuestions[_index];

  Future<void> _next() async {
    if (!_answers.containsKey(_question.id) || _submitting) return;
    if (_index < levelAssessmentQuestions.length - 1) {
      setState(() => _index++);
      return;
    }

    final scores = <AssessmentSkill, int>{};
    for (final skill in AssessmentSkill.values) {
      final questions = levelAssessmentQuestions
          .where((q) => q.skill == skill)
          .toList();
      final correct = questions
          .where((q) => _answers[q.id] == q.correctOption)
          .length;
      scores[skill] = ((correct / questions.length) * 100).round();
    }
    final localResult = LevelAssessmentResult.fromScores(
      pronunciationScore: scores[AssessmentSkill.pronunciation]!,
      readingScore: scores[AssessmentSkill.reading]!,
      writingScore: scores[AssessmentSkill.writing]!,
    );
    setState(() => _submitting = true);
    try {
      final saved = await LevelAssessmentService.instance.submit(
        result: localResult,
        answers: _answers,
      );
      if (mounted) setState(() => _result = saved);
    } catch (_) {
      if (mounted) {
        setState(() {
          _result = localResult;
          _saved = false;
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result case final result?) return _buildResult(result);

    final selected = _answers[_question.id];
    final progress = (_index + 1) / levelAssessmentQuestions.length;
    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F7FC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'اختبار تحديد المستوى',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'IBM',
              fontWeight: FontWeight.w800,
              fontSize: 17.sp,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      '${_index + 1} / ${levelAssessmentQuestions.length}',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'IBM',
                        fontSize: 13.sp,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20.r),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8.h,
                          backgroundColor: const Color(0xFFEDE9FE),
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 18.h),
                _SkillHeader(skill: _question.skill),
                SizedBox(height: 16.h),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_question.contextText case final text?) ...[
                          Container(
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(17.r),
                              border: Border.all(
                                color: const Color(0xFFBFDBFE),
                              ),
                            ),
                            child: Text(
                              text,
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                fontSize: 15.sp,
                                height: 1.65,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E3A8A),
                              ),
                            ),
                          ),
                          SizedBox(height: 18.h),
                        ],
                        Text(
                          _question.prompt,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontSize: 20.sp,
                            height: 1.45,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 20.h),
                        for (var i = 0; i < _question.options.length; i++)
                          Padding(
                            padding: EdgeInsets.only(bottom: 11.h),
                            child: _OptionTile(
                              index: i,
                              text: _question.options[i],
                              selected: selected == i,
                              onTap: () =>
                                  setState(() => _answers[_question.id] = i),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                FilledButton(
                  onPressed: selected == null || _submitting ? null : _next,
                  style: FilledButton.styleFrom(
                    minimumSize: Size.fromHeight(54.h),
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: const Color(0xFFD8D3E5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _index == levelAssessmentQuestions.length - 1
                              ? 'اعرض نتيجتي'
                              : 'السؤال التالي',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'IBM',
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResult(LevelAssessmentResult result) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go(AppRoutes.main);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F7FC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'الرئيسية',
            onPressed: () => context.go(AppRoutes.main),
          ),
          title: Text(
            'نتيجة تحديد المستوى',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'IBM',
              fontWeight: FontWeight.w800,
              fontSize: 17.sp,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 24.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: EdgeInsets.all(24.w),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4C1D95), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(28.r),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(50),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.emoji_events_rounded,
                        color: Color(0xFFFDE68A),
                        size: 55,
                      ),
                      SizedBox(height: 10.h),
                      const Text(
                        'مستواك العام',
                        style: TextStyle(
                          color: Colors.white70,
                          fontFamily: 'IBM',
                        ),
                      ),
                      Text(
                        result.overallLevel.arabicName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 31.sp,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'IBM',
                        ),
                      ),
                      Text(
                        '${result.overallScore}%',
                        style: TextStyle(
                          color: const Color(0xFFFDE68A),
                          fontSize: 19.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  'تفاصيل مستواك',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'IBM',
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 12.h),
                for (final skill in AssessmentSkill.values)
                  Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: _ResultSkillCard(
                      skill: skill,
                      score: result.scoreFor(skill),
                      level: result.levelFor(skill),
                    ),
                  ),
                if (!_saved) ...[
                  SizedBox(height: 6.h),
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(13.r),
                    ),
                    child: const Text(
                      'ظهرت النتيجة، لكن لم يتم حفظها. طبّق ملف SQL المرفق ثم أعد الاختبار.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF9A3412),
                        fontFamily: 'IBM',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 18.h),
                FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.recommendedCourses),
                  icon: const Icon(Icons.school_rounded),
                  label: const Text(
                    'شوف الكورسات المناسبة لمستواك',
                    style: TextStyle(
                      fontFamily: 'IBM',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: Size.fromHeight(55.h),
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                ),
                SizedBox(height: 10.h),
                OutlinedButton(
                  onPressed: () => context.go(AppRoutes.main),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size.fromHeight(52.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: const Text(
                    'العودة للرئيسية',
                    style: TextStyle(
                      fontFamily: 'IBM',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkillHeader extends StatelessWidget {
  final AssessmentSkill skill;

  const _SkillHeader({required this.skill});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (skill) {
      AssessmentSkill.pronunciation => (
        Icons.record_voice_over_rounded,
        const Color(0xFFEC4899),
      ),
      AssessmentSkill.reading => (
        Icons.menu_book_rounded,
        const Color(0xFF3B82F6),
      ),
      AssessmentSkill.writing => (
        Icons.edit_note_rounded,
        const Color(0xFF10B981),
      ),
    };
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(9.w),
          decoration: BoxDecoration(
            color: color.withAlpha(22),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(icon, color: color, size: 21),
        ),
        SizedBox(width: 9.w),
        Text(
          'اختبار ${skill.arabicName}',
          style: TextStyle(
            color: color,
            fontFamily: 'IBM',
            fontWeight: FontWeight.w900,
            fontSize: 14.sp,
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final int index;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.index,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 15.h),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF3E8FF) : Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.7 : 1,
            ),
          ),
          child: Row(
            textDirection: TextDirection.ltr,
            children: [
              Container(
                width: 30.w,
                height: 30.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  String.fromCharCode(65 + index),
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14.sp,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultSkillCard extends StatelessWidget {
  final AssessmentSkill skill;
  final int score;
  final StudentLevel level;

  const _ResultSkillCard({
    required this.skill,
    required this.score,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (skill) {
      AssessmentSkill.pronunciation => const Color(0xFFEC4899),
      AssessmentSkill.reading => const Color(0xFF3B82F6),
      AssessmentSkill.writing => const Color(0xFF10B981),
    };
    return Container(
      padding: EdgeInsets.all(15.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17.r),
        border: Border.all(color: color.withAlpha(45)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withAlpha(20),
            child: Icon(Icons.auto_graph_rounded, color: color),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skill.arabicName,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontFamily: 'IBM',
                    fontSize: 14.sp,
                  ),
                ),
                Text(
                  'مستواك: ${level.arabicName}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'IBM',
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$score%',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 15.sp,
            ),
          ),
        ],
      ),
    );
  }
}
