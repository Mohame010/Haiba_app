import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../domain/entities/exam_entity.dart';
import '../../domain/entities/exam_question_entity.dart';
import '../../domain/entities/exam_submission_entity.dart';

class ExamResultScreen extends StatelessWidget {
  final ExamSubmissionEntity submission;
  final ExamEntity exam;

  const ExamResultScreen({
    super.key,
    required this.submission,
    required this.exam,
  });

  @override
  Widget build(BuildContext context) {
    final isPassed = submission.score >= exam.passScore;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => context.go(AppRoutes.main),
        ),
        title: Text(
          'نتيجة الامتحان',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontFamily: 'IBM',
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Score Card
              Container(
                padding: EdgeInsets.all(22.w),
                decoration: BoxDecoration(
                  gradient: isPassed ? AppColors.pointsGradient : null,
                  color: isPassed ? null : Colors.white,
                  borderRadius: BorderRadius.circular(24.r),
                  boxShadow: [
                    BoxShadow(
                      color: isPassed ? const Color(0xFF312E81).withAlpha(60) : Colors.black.withAlpha(8),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      isPassed ? Icons.emoji_events_rounded : Icons.info_outline_rounded,
                      color: isPassed ? const Color(0xFFFBBF24) : AppColors.warning,
                      size: 56.w,
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      isPassed ? 'أحسنت! لقد اجتزت الامتحان بنجاح' : 'حاول مرة أخرى لتحسين نتيجتك',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: isPassed ? Colors.white : AppColors.textPrimary,
                        fontFamily: 'IBM',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      '${submission.score} / ${submission.totalScore}',
                      style: TextStyle(
                        fontSize: 36.sp,
                        fontWeight: FontWeight.w900,
                        color: isPassed ? const Color(0xFFFDE047) : AppColors.primary,
                        fontFamily: 'IBM',
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'الدرجة الكلية المحصلة',
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w500,
                        color: isPassed ? Colors.white.withAlpha(200) : AppColors.textSecondary,
                        fontFamily: 'IBM',
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.push(
                          AppRoutes.leaderboard,
                          extra: exam.id,
                        );
                      },
                      icon: const Icon(Icons.leaderboard_rounded, color: Colors.white, size: 20),
                      label: const Text('لوحة الصدارة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.go(AppRoutes.main),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                      child: const Text('الرئيسية'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),

              // Model Answers & Self Assessment Section
              Text(
                'مراجعة الإجابات ونموذج الإجابة',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: 'IBM',
                ),
                textAlign: TextAlign.right,
              ),
              SizedBox(height: 12.h),

              ...exam.questions.map((q) {
                final studentAns = submission.answers[q.id] ?? 'لم تتم الإجابة';
                final isMcq = q.questionType != QuestionType.essay;
                final isCorrect = isMcq && studentAns == q.correctAnswer;

                return Container(
                  margin: EdgeInsets.only(bottom: 14.h),
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18.r),
                    border: Border.all(
                      color: isMcq
                          ? (isCorrect ? AppColors.success : AppColors.error).withAlpha(100)
                          : AppColors.primary.withAlpha(100),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: (isMcq
                                      ? (isCorrect ? AppColors.success : AppColors.error)
                                      : AppColors.primary)
                                  .withAlpha(20),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              isMcq ? (isCorrect ? 'إجابة صحيحة' : 'إجابة خاطئة') : 'سؤال مقالي (تصحيح ذاتي)',
                              style: TextStyle(
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w700,
                                color: isMcq
                                    ? (isCorrect ? AppColors.success : AppColors.error)
                                    : AppColors.primary,
                                fontFamily: 'IBM',
                              ),
                            ),
                          ),
                          Text(
                            'سؤال ${q.questionNumber}',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              fontFamily: 'IBM',
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        q.questionText,
                        style: TextStyle(
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: 'IBM',
                        ),
                        textAlign: TextAlign.right,
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        'إجابتك: $studentAns',
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w600,
                          color: isCorrect ? AppColors.success : AppColors.error,
                          fontFamily: 'IBM',
                        ),
                      ),
                      if (q.correctAnswer != null) ...[
                        SizedBox(height: 4.h),
                        Text(
                          'الإجابة النموذجية: ${q.correctAnswer}',
                          style: TextStyle(
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                            fontFamily: 'IBM',
                          ),
                        ),
                      ],
                      if (q.explanation != null) ...[
                        SizedBox(height: 6.h),
                        Text(
                          'الشرح: ${q.explanation}',
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            color: AppColors.textSecondary,
                            fontFamily: 'IBM',
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              SizedBox(height: 30.h),
            ],
          ),
        ),
      ),
    );
  }
}
