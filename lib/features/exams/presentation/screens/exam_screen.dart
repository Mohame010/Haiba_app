import 'package:audioplayers/audioplayers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/services/screen_protection_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_helper.dart';
import '../../domain/entities/exam_question_entity.dart';
import '../cubits/exam_session/exam_session_cubit.dart';
import '../cubits/exam_session/exam_session_state.dart';

class ExamScreen extends StatefulWidget {
  final String examId;

  const ExamScreen({super.key, required this.examId});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  bool _allowPop = false;

  AudioPlayer? _audioPlayer;
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();
    ScreenProtectionService.acquire();
    context.read<ExamSessionCubit>().startExam(widget.examId);
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    ScreenProtectionService.release();
    super.dispose();
  }

  Future<void> _playAudio(String url) async {
    _audioPlayer ??= AudioPlayer();
    if (_isPlayingAudio) {
      await _audioPlayer?.pause();
      setState(() => _isPlayingAudio = false);
    } else {
      await _audioPlayer?.play(UrlSource(url));
      setState(() => _isPlayingAudio = true);
      _audioPlayer?.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _isPlayingAudio = false);
      });
    }
  }

  void _showSubmitConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Text(
          'تسليم الامتحان',
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontFamily: 'IBM',
          ),
          textAlign: TextAlign.right,
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في إنهاء الامتحان وتسليم الإجابات الآن؟',
          style: TextStyle(fontSize: 13.5.sp, height: 1.6, fontFamily: 'IBM'),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('متابعة الحل'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.read<ExamSessionCubit>().submitExam();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: const Text('تأكيد التسليم'),
          ),
        ],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Text(
          'تنبيه الخروج من الامتحان',
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.error,
            fontFamily: 'IBM',
          ),
          textAlign: TextAlign.right,
        ),
        content: Text(
          'التايمر سيظل يعمل أثناء خروجك، هل تريد بالتأكيد الخروج مؤقتاً؟',
          style: TextStyle(fontSize: 13.5.sp, height: 1.6, fontFamily: 'IBM'),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('البقاء في الامتحان'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
    return shouldLeave ?? false;
  }

  Future<void> _requestPop() async {
    if (!await _onWillPop() || !mounted) return;
    setState(() => _allowPop = true);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _requestPop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
            onPressed: _requestPop,
          ),
          centerTitle: true,
          title: BlocBuilder<ExamSessionCubit, ExamSessionState>(
            builder: (context, state) {
              if (state is ExamSessionActive) {
                final timeStr = DateTimeHelper.formatSeconds(
                  state.remainingSeconds,
                );
                final isWarning = state.remainingSeconds < 300;
                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: isWarning
                        ? AppColors.error.withAlpha(20)
                        : AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: isWarning ? AppColors.error : AppColors.primary,
                        size: 18.sp,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: isWarning
                              ? AppColors.error
                              : AppColors.primary,
                          fontFamily: 'IBM',
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const Text('');
            },
          ),
          actions: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              child: ElevatedButton(
                onPressed: () => _showSubmitConfirmationDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 14.w),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  elevation: 0,
                ),
                child: const Text('تسليم'),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: BlocConsumer<ExamSessionCubit, ExamSessionState>(
            listener: (context, state) {
              if (state is ExamSessionSubmitted) {
                context.pushReplacement(
                  AppRoutes.examResult,
                  extra: {'submission': state.submission, 'exam': state.exam},
                );
              }
            },
            builder: (context, state) {
              if (state is ExamSessionLoading || state is ExamSessionInitial) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              if (state is ExamSessionError) {
                return Center(
                  child: Text(
                    state.message,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.error,
                      fontFamily: 'IBM',
                    ),
                  ),
                );
              }

              if (state is ExamSessionActive) {
                final questions = state.exam.questions;
                if (questions.isEmpty) {
                  return const Center(
                    child: Text('لا توجد أسئلة مضافة في هذا الامتحان'),
                  );
                }

                final currentQ = questions[state.currentQuestionIndex];
                final selectedAnswer = state.answers[currentQ.id];

                return Column(
                  children: [
                    // Question Numbers Horizontal Bar
                    Container(
                      color: Colors.white,
                      height: 52.h,
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        itemCount: questions.length,
                        itemBuilder: (context, idx) {
                          final isCurrent = idx == state.currentQuestionIndex;
                          final isAnswered = state.answers.containsKey(
                            questions[idx].id,
                          );

                          return GestureDetector(
                            onTap: () => context
                                .read<ExamSessionCubit>()
                                .goToQuestion(idx),
                            child: Container(
                              width: 36.w,
                              margin: EdgeInsets.symmetric(horizontal: 4.w),
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? AppColors.primary
                                    : isAnswered
                                    ? const Color(0xFFDCFCE7)
                                    : AppColors.cardLight,
                                shape: BoxShape.circle,
                                border: isCurrent
                                    ? null
                                    : Border.all(color: AppColors.border),
                              ),
                              child: Center(
                                child: Text(
                                  '${idx + 1}',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                    color: isCurrent
                                        ? Colors.white
                                        : isAnswered
                                        ? AppColors.success
                                        : AppColors.textSecondary,
                                    fontFamily: 'IBM',
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Active Question Area
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 16.h,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Question Type Tag & Score
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10.w,
                                    vertical: 4.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withAlpha(25),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Text(
                                    '${currentQ.points} درجات',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.warning,
                                      fontFamily: 'IBM',
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12.w,
                                    vertical: 4.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withAlpha(20),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Text(
                                    'سؤال ${state.currentQuestionIndex + 1} من ${questions.length}',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                      fontFamily: 'IBM',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16.h),

                            // Question Text
                            Container(
                              padding: EdgeInsets.all(18.w),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(6),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Text(
                                currentQ.questionText,
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w800,
                                  height: 1.6,
                                  color: AppColors.textPrimary,
                                  fontFamily: 'IBM',
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            SizedBox(height: 16.h),

                            // Image Question Media
                            if (currentQ.questionType == QuestionType.image &&
                                currentQ.imageUrl != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16.r),
                                child: Image.network(
                                  currentQ.imageUrl!,
                                  height: 180.h,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              SizedBox(height: 16.h),
                            ],

                            // Audio Question Player
                            if (currentQ.questionType == QuestionType.audio &&
                                currentQ.audioUrl != null) ...[
                              Container(
                                padding: EdgeInsets.all(16.w),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(18.r),
                                  border: Border.all(
                                    color: AppColors.info.withAlpha(50),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () =>
                                          _playAudio(currentQ.audioUrl!),
                                      child: Container(
                                        width: 48.w,
                                        height: 48.w,
                                        decoration: const BoxDecoration(
                                          color: AppColors.info,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _isPlayingAudio
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 30.w,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 14.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'تسجيل صوتي خاص بالسؤال',
                                            style: TextStyle(
                                              fontSize: 13.5.sp,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                              fontFamily: 'IBM',
                                            ),
                                          ),
                                          SizedBox(height: 2.h),
                                          Text(
                                            'اضغط للاستماع للتسجيل ثم أجب',
                                            style: TextStyle(
                                              fontSize: 11.5.sp,
                                              color: AppColors.textSecondary,
                                              fontFamily: 'IBM',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16.h),
                            ],

                            // Answers Area (Options for MCQ/Image/Audio OR TextField for Essay)
                            if (currentQ.answerType == QuestionAnswerType.essay)
                              _buildEssayInput(currentQ.id, selectedAnswer)
                            else
                              ...currentQ.options.map(
                                (opt) => _buildOptionCard(
                                  optionText: opt,
                                  isSelected: selectedAnswer == opt,
                                  onTap: () {
                                    context
                                        .read<ExamSessionCubit>()
                                        .selectAnswer(currentQ.id, opt);
                                  },
                                ),
                              ),
                            SizedBox(height: 24.h),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Navigation: Previous / Next
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 12.h,
                      ),
                      color: Colors.white,
                      child: Row(
                        children: [
                          if (state.currentQuestionIndex > 0)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => context
                                    .read<ExamSessionCubit>()
                                    .previousQuestion(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textPrimary,
                                  side: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14.r),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 12.h),
                                ),
                                child: const Text('السابق'),
                              ),
                            )
                          else
                            const Spacer(),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (state.currentQuestionIndex <
                                    questions.length - 1) {
                                  context
                                      .read<ExamSessionCubit>()
                                      .nextQuestion();
                                } else {
                                  _showSubmitConfirmationDialog(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.r),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                              ),
                              child: Text(
                                state.currentQuestionIndex <
                                        questions.length - 1
                                    ? 'التالي'
                                    : 'مراجعة وتسليم',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required String optionText,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF5F3FF) : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 22.w,
              height: 22.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                  width: 2,
                ),
                color: isSelected ? AppColors.primary : Colors.transparent,
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(Icons.circle, size: 8, color: Colors.white),
                    )
                  : null,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                optionText,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontFamily: 'IBM',
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEssayInput(String questionId, String? currentAnswer) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: TextEditingController(text: currentAnswer)
          ..selection = TextSelection.collapsed(
            offset: currentAnswer?.length ?? 0,
          ),
        maxLines: 6,
        onChanged: (val) {
          context.read<ExamSessionCubit>().selectAnswer(questionId, val);
        },
        style: TextStyle(fontSize: 14.sp, fontFamily: 'IBM'),
        decoration: InputDecoration(
          hintText: 'اكتب إجابتك المقالية بالتفصيل هنا...',
          hintStyle: TextStyle(
            fontSize: 13.sp,
            color: AppColors.textMuted,
            fontFamily: 'IBM',
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16.w),
        ),
      ),
    );
  }
}
