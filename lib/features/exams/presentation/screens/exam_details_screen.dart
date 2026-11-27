import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/dependency_injection.dart';
import '../../../core/network/api_result.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../domain/entities/exam_entity.dart';
import '../../domain/entities/exam_question_entity.dart';
import '../../domain/usecases/get_exam_details_usecase.dart';

class ExamDetailsScreen extends StatefulWidget {
  final String examId;

  const ExamDetailsScreen({super.key, required this.examId});

  @override
  State<ExamDetailsScreen> createState() => _ExamDetailsScreenState();
}

class _ExamDetailsScreenState extends State<ExamDetailsScreen> {
  late Future<ApiResult<ExamEntity>> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  void _loadDetails() {
    _detailsFuture = getIt<GetExamDetailsUseCase>()(widget.examId);
  }

  void _retry() {
    setState(_loadDetails);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'تفاصيل الامتحان',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontFamily: 'IBM',
          ),
        ),
      ),
      body: FutureBuilder<ApiResult<ExamEntity>>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final result = snapshot.data;
          if (result is ApiError<ExamEntity>) {
            return _buildError(result.failure.message);
          }
          if (result is! ApiSuccess<ExamEntity>) {
            return _buildError('تعذر تحميل تفاصيل الامتحان');
          }

          final exam = result.data;
          final questionCount = exam.questions.isNotEmpty
              ? exam.questions.length
              : exam.questionsCount;

          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 10.h,
                    ),
                    child: Column(
                      children: [
                        // Exam 3D Illustration Icon
                        Container(
                          width: 90.w,
                          height: 90.w,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                            ),
                            borderRadius: BorderRadius.circular(24.r),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withAlpha(70),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.assignment_turned_in_rounded,
                              color: Colors.white,
                              size: 48.w,
                            ),
                          ),
                        ),
                        SizedBox(height: 16.h),

                        // Exam Title
                        Text(
                          exam.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            fontFamily: 'IBM',
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          [exam.chapter, exam.grade]
                              .where((value) => value.trim().isNotEmpty)
                              .join(' • '),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            fontFamily: 'IBM',
                          ),
                        ),
                        if (exam.description.trim().isNotEmpty) ...[
                          SizedBox(height: 12.h),
                          Text(
                            exam.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.sp,
                              height: 1.5,
                              color: AppColors.textSecondary,
                              fontFamily: 'IBM',
                            ),
                          ),
                        ],
                        SizedBox(height: 24.h),

                        // 4 Exam Specs Cards
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(6),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildSpecRow(
                                icon: Icons.access_time_rounded,
                                iconColor: AppColors.info,
                                label: 'المدة',
                                value: '${exam.durationMinutes} دقيقة',
                              ),
                              Divider(
                                color: AppColors.borderLight,
                                height: 20.h,
                              ),
                              _buildSpecRow(
                                icon: Icons.star_rounded,
                                iconColor: AppColors.warning,
                                label: 'الدرجة الكلية',
                                value: '${exam.totalScore} درجة',
                              ),
                              Divider(
                                color: AppColors.borderLight,
                                height: 20.h,
                              ),
                              _buildSpecRow(
                                icon: Icons.format_list_bulleted_rounded,
                                iconColor: AppColors.primary,
                                label: 'عدد الأسئلة',
                                value: '$questionCount سؤال',
                              ),
                              Divider(
                                color: AppColors.borderLight,
                                height: 20.h,
                              ),
                              _buildSpecRow(
                                icon: Icons.task_alt_rounded,
                                iconColor: AppColors.error,
                                label: 'درجة النجاح',
                                value: '${exam.passScore} درجة',
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20.h),

                        // Instructions Card
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(18.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22.r),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'تعليمات الامتحان',
                                style: TextStyle(
                                  fontSize: 14.5.sp,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  fontFamily: 'IBM',
                                ),
                              ),
                              SizedBox(height: 12.h),
                              _buildInstructionBullet(
                                'بمجرد بدء الامتحان سيبدأ التايمر بالعد التنازلي.',
                              ),
                              _buildInstructionBullet(
                                'تأكد من اتصال الإنترنت قبل بدء الإجابة.',
                              ),
                              _buildInstructionBullet(
                                'مسموح بدخول الامتحان ${exam.maxAttempts} ${exam.maxAttempts == 1 ? 'مرة' : 'مرات'} • المتبقي ${exam.maxAttempts - exam.attemptsUsed}.',
                              ),
                              _buildInstructionBullet(_questionTypesText(exam)),
                              _buildInstructionBullet(
                                exam.allowResume
                                    ? 'يمكنك التنقل بين الأسئلة ومراجعة إجاباتك قبل التسليم.'
                                    : 'لا يمكن استئناف الامتحان بعد الخروج منه.',
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20.h),
                      ],
                    ),
                  ),
                ),

                // Start Exam Button Pinned at Bottom
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 16.h,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: ElevatedButton(
                      onPressed: exam.isExpired || !exam.hasAttemptsRemaining
                          ? null
                          : () => context.push(
                              AppRoutes.examScreen,
                              extra: exam.id,
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        exam.isExpired
                            ? 'انتهى موعد الامتحان'
                            : !exam.hasAttemptsRemaining
                            ? 'استهلكت كل محاولات الدخول'
                            : exam.isChallenge
                            ? 'ابدأ التحدي الآن'
                            : 'ابدأ الامتحان الآن',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'IBM',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 48,
            ),
            SizedBox(height: 12.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textSecondary,
                fontFamily: 'IBM',
              ),
            ),
            SizedBox(height: 16.h),
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  String _questionTypesText(ExamEntity exam) {
    if (exam.questions.isEmpty) {
      return 'يحتوي الامتحان على ${exam.questionsCount} سؤال.';
    }

    const labels = <QuestionType, String>{
      QuestionType.mcq: 'اختيار من متعدد',
      QuestionType.essay: 'مقالي',
      QuestionType.image: 'صور',
      QuestionType.audio: 'صوت',
    };
    final types = exam.questions
        .map((question) => question.questionType)
        .toSet()
        .map((type) => labels[type]!)
        .join('، ');
    return 'أنواع الأسئلة: $types.';
  }

  Widget _buildSpecRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20.sp),
        SizedBox(width: 8.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
            fontFamily: 'IBM',
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontFamily: 'IBM',
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionBullet(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            margin: EdgeInsets.only(top: 6.h),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5.sp,
                height: 1.5,
                color: AppColors.textSecondary,
                fontFamily: 'IBM',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
