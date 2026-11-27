import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../domain/entities/lecture_content_entity.dart';
import '../cubits/lecture_details/lecture_details_cubit.dart';
import '../cubits/lecture_details/lecture_details_state.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/pdf_viewer_dialog.dart';
import '../widgets/web_view_screen.dart';

class LessonResourcesScreen extends StatefulWidget {
  final String lectureId;

  const LessonResourcesScreen({super.key, required this.lectureId});

  @override
  State<LessonResourcesScreen> createState() => _LessonResourcesScreenState();
}

class _LessonResourcesScreenState extends State<LessonResourcesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<LectureDetailsCubit>().loadLecture(widget.lectureId);
  }

  void _openSummary(String title, String summary) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title.isNotEmpty ? title : 'ملخص الدرس',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontFamily: 'IBM',
              ),
              textAlign: TextAlign.right,
            ),
            SizedBox(height: 12.h),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 350.h),
              child: SingleChildScrollView(
                child: Text(
                  summary,
                  style: TextStyle(
                    fontSize: 14.sp,
                    height: 1.7,
                    color: AppColors.textSecondary,
                    fontFamily: 'IBM',
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
          'موارد ومحتويات الدرس',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontFamily: 'IBM',
          ),
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<LectureDetailsCubit, LectureDetailsState>(
          builder: (context, state) {
            if (state is LectureDetailsLoading ||
                state is LectureDetailsInitial) {
              return _buildShimmerLoading();
            }

            if (state is LectureDetailsError) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(24.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 48.w,
                        color: AppColors.error,
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        state.message,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textSecondary,
                          fontFamily: 'IBM',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16.h),
                      ElevatedButton(
                        onPressed: () => context
                            .read<LectureDetailsCubit>()
                            .loadLecture(widget.lectureId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: const Text(
                          'إعادة المحاولة',
                          style: TextStyle(fontFamily: 'IBM'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state is LectureDetailsLoaded) {
              final lecture = state.lecture;

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Lecture Banner
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(8),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Thumbnail
                          Container(
                            width: 80.w,
                            height: 80.w,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16.r),
                              color: AppColors.primary.withAlpha(20),
                              image: lecture.thumbnailUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(
                                        lecture.thumbnailUrl!,
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : const DecorationImage(
                                      image: NetworkImage(
                                        'https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=400&auto=format&fit=crop',
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                          SizedBox(width: 14.w),

                          // Title and teacher
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lecture.title,
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    fontFamily: 'IBM',
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  '${lecture.lessonNumber} - ${lecture.chapter}',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                    fontFamily: 'IBM',
                                  ),
                                ),
                                SizedBox(height: 8.h),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // Section Title
                    Text(
                      'المحتويات المرفقة (${lecture.contents.length + (lecture.attachedExamId != null ? 1 : 0)})',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        fontFamily: 'IBM',
                      ),
                      textAlign: TextAlign.right,
                    ),
                    SizedBox(height: 12.h),

                    // Real Lecture Contents from Supabase
                    ...lecture.contents.map((content) {
                      final (
                        icon,
                        iconColor,
                        defaultSubtitle,
                        trailingIcon,
                      ) = switch (content.contentType) {
                        ContentType.video => (
                          Icons.play_circle_fill_rounded,
                          AppColors.info,
                          content.durationSeconds > 0
                              ? 'مدة الفيديو ${(content.durationSeconds / 60).ceil()} دقيقة'
                              : 'فيديو الشرح',
                          Icons.play_arrow_rounded,
                        ),
                        ContentType.pdf => (
                          Icons.picture_as_pdf_rounded,
                          const Color(0xFFEF4444),
                          'ملف PDF للمطالعة والتحميل',
                          Icons.arrow_forward_ios_rounded,
                        ),
                        ContentType.audio => (
                          Icons.headphones_rounded,
                          const Color(0xFF10B981),
                          content.durationSeconds > 0
                              ? 'تسجيل صوتي ${(content.durationSeconds / 60).ceil()} دقيقة'
                              : 'شرح صوتي مبسط',
                          Icons.play_arrow_rounded,
                        ),
                        ContentType.image => (
                          Icons.image_rounded,
                          const Color(0xFFF59E0B),
                          'صورة مرفقة بالحصة',
                          Icons.open_in_full_rounded,
                        ),
                        ContentType.link => (
                          Icons.link_rounded,
                          const Color(0xFF2563EB),
                          'رابط خارجي مرفق بالحصة',
                          Icons.open_in_new_rounded,
                        ),
                        ContentType.summary => (
                          Icons.article_rounded,
                          const Color(0xFF8B5CF6),
                          'ملخص لأهم القوانين والنقاط',
                          Icons.arrow_forward_ios_rounded,
                        ),
                      };

                      return Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: _buildResourceItem(
                          context,
                          title: content.title.isNotEmpty
                              ? content.title
                              : 'محتوى الدرس',
                          subtitle:
                              content.subtitle != null &&
                                  content.subtitle!.isNotEmpty
                              ? content.subtitle!
                              : defaultSubtitle,
                          icon: icon,
                          iconColor: iconColor,
                          trailingIcon: trailingIcon,
                          onTap: () {
                            switch (content.contentType) {
                              case ContentType.video:
                                context.pop(); // Go back to player screen
                                break;
                              case ContentType.pdf:
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PdfViewerModal(
                                      pdfUrl: content.fileUrl,
                                      title: content.title,
                                    ),
                                  ),
                                );
                                break;
                              case ContentType.audio:
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.transparent,
                                  isScrollControlled: true,
                                  builder: (_) => AudioPlayerModal(
                                    audioUrl: content.fileUrl,
                                    title: content.title,
                                  ),
                                );
                                break;
                              case ContentType.image:
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => _ImageContentPage(
                                      imageUrl: content.fileUrl,
                                      title: content.title,
                                    ),
                                  ),
                                );
                                break;
                              case ContentType.link:
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => InAppWebViewScreen(
                                      url: content.fileUrl,
                                      title: content.title,
                                    ),
                                  ),
                                );
                                break;
                              case ContentType.summary:
                                _openSummary(
                                  content.title,
                                  content.fileUrl.isNotEmpty
                                      ? content.fileUrl
                                      : (content.subtitle ??
                                            lecture.description),
                                );
                                break;
                            }
                          },
                        ),
                      );
                    }),

                    // Attached Exam Item if present
                    if (lecture.attachedExamId != null ||
                        lecture.attachedExamTitle != null) ...[
                      Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: _buildResourceItem(
                          context,
                          title:
                              lecture.attachedExamTitle ??
                              'امتحان على هذا الدرس',
                          subtitle:
                              'المدة: ${lecture.attachedExamDuration} دقيقة • ${lecture.attachedExamScore} درجة',
                          icon: Icons.assignment_turned_in_rounded,
                          iconColor: const Color(0xFF6366F1),
                          trailingIcon: Icons.arrow_forward_ios_rounded,
                          onTap: () {
                            final examId =
                                lecture.attachedExamId ??
                                '44444444-4444-4444-4444-444444444444';
                            context.push(AppRoutes.examDetails, extra: examId);
                          },
                        ),
                      ),
                    ],

                    SizedBox(height: 24.h),
                  ],
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE2E8F0),
      highlightColor: const Color(0xFFF8FAFC),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        child: Column(
          children: [
            Container(
              height: 100.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
              ),
            ),
            SizedBox(height: 20.h),
            ...List.generate(
              4,
              (index) => Container(
                margin: EdgeInsets.only(bottom: 12.h),
                height: 70.h,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    IconData? trailingIcon,
    required VoidCallback onTap,
  }) {
    final effectiveTrailingIcon =
        trailingIcon ?? Icons.arrow_forward_ios_rounded;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, color: iconColor, size: 24.w),
              ),
            ),
            SizedBox(width: 14.w),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFamily: 'IBM',
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      fontFamily: 'IBM',
                    ),
                  ),
                ],
              ),
            ),

            // Trailing Action Icon
            Icon(
              effectiveTrailingIcon,
              color: const Color(0xFF6366F1),
              size: effectiveTrailingIcon == Icons.arrow_forward_ios_rounded
                  ? 18.w
                  : 24.w,
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageContentPage extends StatelessWidget {
  const _ImageContentPage({required this.imageUrl, required this.title});

  final String imageUrl;
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    backgroundColor: Colors.black,
    body: Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5,
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Text(
            'تعذر فتح الصورة',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    ),
  );
}
