import 'dart:io';
import 'package:material_ui/material_ui.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/routing/app_routes.dart';

import '../../../core/services/screen_protection_service.dart';
import '../../../core/theme/app_colors.dart';

import '../../domain/entities/lecture_content_entity.dart';
import '../../domain/entities/lecture_entity.dart';

import '../../data/services/offline_lecture_service.dart';
import '../../data/services/learning_activity_service.dart';

import '../cubits/lecture_details/lecture_details_cubit.dart';
import '../cubits/lecture_details/lecture_details_state.dart';

import '../widgets/audio_player_widget.dart';
import '../widgets/pdf_viewer_dialog.dart';

import '../widgets/pronunciation_assignment_widget.dart';
import '../widgets/video_player_widget.dart';

import '../widgets/web_view_screen.dart';

class LectureDetailsScreen extends StatefulWidget {
  final String lectureId;

  const LectureDetailsScreen({super.key, required this.lectureId});

  @override
  State<LectureDetailsScreen> createState() => _LectureDetailsScreenState();
}

class _LectureDetailsScreenState extends State<LectureDetailsScreen> {
  int _selectedVideoIndex = 0;
  final VideoPlayerWidgetController _videoPlayerController =
      VideoPlayerWidgetController();
  bool _isDownloaded = false;
  DownloadedLecture? _downloadedLecture;
  double? _downloadProgress;
  int _resumePositionSeconds = 0;
  bool _autoplaySelectedVideo = false;

  @override
  void initState() {
    super.initState();
    ScreenProtectionService.acquire();
    context.read<LectureDetailsCubit>().loadLecture(widget.lectureId);
    _loadDownloadState();
    _loadResumePosition();
  }

  @override
  void dispose() {
    ScreenProtectionService.release();
    super.dispose();
  }

  Future<void> _loadResumePosition() async {
    final position = await LearningActivityService.instance.positionForLecture(
      widget.lectureId,
    );
    if (mounted) setState(() => _resumePositionSeconds = position);
  }

  Future<void> _loadDownloadState() async {
    DownloadedLecture? downloaded;
    final downloads = await OfflineLectureService.instance.getDownloads();
    for (final item in downloads) {
      if (item.lectureId == widget.lectureId) {
        downloaded = item;
        break;
      }
    }
    if (mounted) {
      setState(() {
        _downloadedLecture = downloaded;
        _isDownloaded = downloaded != null;
      });
    }
  }

  String _contentUrl(LectureContentEntity content) {
    final downloaded = _downloadedLecture;
    if (downloaded == null) return content.fileUrl;

    DownloadedContent? fallback;
    for (final local in downloaded.contents) {
      if (local.type != content.contentType || !_localContentExists(local)) {
        continue;
      }
      if (local.id == content.id) return Uri.file(local.localPath).toString();
      if (fallback == null &&
          (local.title.trim() == content.title.trim() ||
              local.sortOrder == content.sortOrder)) {
        fallback = local;
      }
    }
    if (fallback != null) return Uri.file(fallback.localPath).toString();
    return content.fileUrl;
  }

  bool _localContentExists(DownloadedContent content) =>
      content.localPath.isNotEmpty &&
      FileSystemEntity.typeSync(content.localPath) !=
          FileSystemEntityType.notFound;

  Future<void> _downloadLecture(LectureEntity lecture) async {
    if (_downloadProgress != null || _isDownloaded) return;
    setState(() => _downloadProgress = 0);
    try {
      await OfflineLectureService.instance.downloadLecture(
        lecture,
        onProgress: (progress, message) {
          if (mounted) setState(() => _downloadProgress = progress);
        },
      );
      if (!mounted) return;
      setState(() {
        _downloadProgress = null;
        _isDownloaded = true;
      });
      await _loadDownloadState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تنزيل الفيديو وملحقات المحاضرة داخل التطبيق'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _downloadProgress = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إكمال التنزيل: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteDownloadedLecture() async {
    if (!_isDownloaded || _downloadProgress != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'حذف الفيديو من التنزيلات؟',
          style: TextStyle(fontFamily: 'IBM'),
        ),
        content: const Text(
          'يمكنك تنزيله مرة أخرى في أي وقت.',
          style: TextStyle(fontFamily: 'IBM'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await OfflineLectureService.instance.deleteDownload(widget.lectureId);
      if (!mounted) return;
      setState(() {
        _downloadedLecture = null;
        _isDownloaded = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف الفيديو من التنزيلات'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر حذف التنزيل: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _selectVideo(int index, {bool autoplay = false}) {
    setState(() {
      _selectedVideoIndex = index;
      _autoplaySelectedVideo = autoplay;
      _resumePositionSeconds = 0;
    });
  }

  void _openSummary(String title, String summary) {
    final trimmed = summary.trim();
    final isUrl =
        trimmed.startsWith('http://') || trimmed.startsWith('https://');

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
            Row(
              children: [
                Icon(
                  isUrl ? Icons.link_rounded : Icons.summarize_rounded,
                  color: AppColors.primary,
                  size: 26.w,
                ),
                SizedBox(width: 8.w),
                Text(
                  title.isNotEmpty ? title : 'ملخص المحاضرة',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontFamily: 'IBM',
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
            SizedBox(height: 16.h),
            if (isUrl) ...[
              Text(
                'يمكنك الاطلاع على مذكرة وملخص المحاضرة عبر الرابط التالي:',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  fontFamily: 'IBM',
                ),
                textAlign: TextAlign.right,
              ),
              SizedBox(height: 12.h),
              InkWell(
                onTap: () => _confirmAndOpenUrl(ctx, trimmed),
                borderRadius: BorderRadius.circular(12.r),
                child: Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.open_in_new_rounded,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          trimmed,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2563EB),
                            decoration: TextDecoration.underline,
                            decorationColor: const Color(0xFF2563EB),
                            fontFamily: 'IBM',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'اضغط على الرابط بالأعلى لعرض المحتوى داخل التطبيق',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                  fontFamily: 'IBM',
                ),
                textAlign: TextAlign.center,
              ),
            ] else ...[
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
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  void _confirmAndOpenUrl(BuildContext parentContext, String url) {
    showDialog(
      context: parentContext,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.primary),
            SizedBox(width: 8.w),
            Text(
              'تأكيد فتح الرابط',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                fontFamily: 'IBM',
              ),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد أنك ترغب في فتح هذا الرابط لعرض ملخص ومذكرة المحاضرة داخل التطبيق؟',
          style: TextStyle(
            fontSize: 14.sp,
            height: 1.5,
            color: AppColors.textPrimary,
            fontFamily: 'IBM',
          ),
          textAlign: TextAlign.right,
        ),
        actionsPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              'إلغاء',
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textSecondary,
                fontFamily: 'IBM',
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              Navigator.of(parentContext).push(
                MaterialPageRoute(
                  builder: (_) => InAppWebViewScreen(
                    url: url,
                    title: 'ملخص ومذكرة المحاضرة',
                  ),
                ),
              );
            },
            child: Text(
              'فتح داخل التطبيق',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFamily: 'IBM',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPdf(String url, String title) async {
    final viewer = Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerModal(pdfUrl: url, title: title),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _videoPlayerController.enterPictureInPicture();
    });
    await viewer;
    _videoPlayerController.exitPictureInPicture();
  }

  Future<void> _openAudio(String url, String title) async {
    final audioSheet = showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AudioPlayerModal(audioUrl: url, title: title),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _videoPlayerController.enterPictureInPicture();
    });
    await audioSheet;
    _videoPlayerController.exitPictureInPicture();
  }

  void _handlePdfAction(
    List<LectureContentEntity> pdfContents,
    String lectureTitle,
  ) {
    if (pdfContents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا توجد ملفات PDF مرفقة بهذا المحاضرة حالياً',
            style: TextStyle(fontFamily: 'IBM'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (pdfContents.length == 1) {
      final pdf = pdfContents.first;
      _openPdf(
        _contentUrl(pdf),
        pdf.title.isNotEmpty ? pdf.title : 'ملف PDF - $lectureTitle',
      );
      return;
    }

    // Multiple PDFs selection
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'اختر ملف الـ PDF',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontFamily: 'IBM',
              ),
              textAlign: TextAlign.right,
            ),
            SizedBox(height: 12.h),
            ...pdfContents.map(
              (pdf) => ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Color(0xFFEF4444),
                  ),
                ),
                title: Text(
                  pdf.title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'IBM',
                  ),
                ),
                subtitle: pdf.subtitle != null
                    ? Text(
                        pdf.subtitle!,
                        style: TextStyle(fontSize: 12.sp, fontFamily: 'IBM'),
                      )
                    : null,
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openPdf(_contentUrl(pdf), pdf.title);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAudioAction(
    List<LectureContentEntity> audioContents,
    String lectureTitle,
  ) {
    if (audioContents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا توجد تسجيلات صوتية مرفقة بهذا المحاضرة حالياً',
            style: TextStyle(fontFamily: 'IBM'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (audioContents.length == 1) {
      final audio = audioContents.first;
      _openAudio(
        _contentUrl(audio),
        audio.title.isNotEmpty ? audio.title : 'شرح صوتي - $lectureTitle',
      );
      return;
    }

    // Multiple Audios selection
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'اختر التسجيل الصوتي',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontFamily: 'IBM',
              ),
              textAlign: TextAlign.right,
            ),
            SizedBox(height: 12.h),
            ...audioContents.map(
              (audio) => ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.headphones_rounded,
                    color: Color(0xFF3B82F6),
                  ),
                ),
                title: Text(
                  audio.title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'IBM',
                  ),
                ),
                subtitle: audio.subtitle != null
                    ? Text(
                        audio.subtitle!,
                        style: TextStyle(fontSize: 12.sp, fontFamily: 'IBM'),
                      )
                    : null,
                trailing: const Icon(
                  Icons.play_arrow_rounded,
                  color: Color(0xFF3B82F6),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openAudio(_contentUrl(audio), audio.title);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSummaryAction(
    List<LectureContentEntity> summaryContents,
    String lectureDesc,
  ) {
    const defaultScribdUrl =
        'https://www.scribd.com/document/527732483/%D9%85%D8%B0%D9%83%D8%B1%D8%A9-%D8%A7%D8%AD%D9%8A%D8%A7%D8%A1-%D9%84%D9%84%D8%B5%D9%81-%D8%A7%D9%84%D8%AB%D8%A7%D9%84%D8%AB-%D8%A7%D9%84%D8%AB%D8%A7%D9%86%D9%88%D9%8A-%D9%85%D9%84%D8%B2%D9%85%D8%AA%D9%8A-1';

    if (summaryContents.isNotEmpty) {
      final summary = summaryContents.first;
      final text = summary.fileUrl.isNotEmpty
          ? summary.fileUrl
          : (summary.subtitle ?? defaultScribdUrl);
      _openSummary(summary.title, text);
    } else {
      _openSummary('ملخص المحاضرة والمذكرة', defaultScribdUrl);
    }
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
          'المحاضرة',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontFamily: 'IBM',
          ),
        ),
        // actions: [
        //   IconButton(
        //     icon: const Icon(
        //       Icons.more_horiz_rounded,
        //       color: AppColors.textPrimary,
        //     ),
        //     tooltip: 'موارد المحاضرة',
        //     onPressed: () {
        //       context.push(AppRoutes.lessonResources, extra: widget.lectureId);
        //     },
        //   ),
        // ],
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

              // Filter contents by type
              final videoContents = lecture.contents
                  .where((c) => c.contentType == ContentType.video)
                  .toList();
              final pdfContents = lecture.contents
                  .where((c) => c.contentType == ContentType.pdf)
                  .toList();
              final audioContents = lecture.contents
                  .where((c) => c.contentType == ContentType.audio)
                  .toList();
              final summaryContents = lecture.contents
                  .where((c) => c.contentType == ContentType.summary)
                  .toList();
              final extraContents = lecture.contents
                  .where(
                    (c) =>
                        c.contentType == ContentType.image ||
                        c.contentType == ContentType.link,
                  )
                  .toList();

              final currentVideoIndex = videoContents.isEmpty
                  ? 0
                  : _selectedVideoIndex.clamp(0, videoContents.length - 1);
              final currentVideo = videoContents.isNotEmpty
                  ? videoContents[currentVideoIndex]
                  : null;
              final nextVideo = currentVideoIndex + 1 < videoContents.length
                  ? videoContents[currentVideoIndex + 1]
                  : null;
              final nextLecture = state.nextLecture;
              final nextItemTitle = nextVideo != null
                  ? (nextVideo.title.isNotEmpty
                        ? nextVideo.title
                        : 'الجزء ${currentVideoIndex + 2}')
                  : nextLecture?.title;

              void playNextItem() {
                if (nextVideo != null) {
                  _selectVideo(currentVideoIndex + 1, autoplay: true);
                } else if (nextLecture != null) {
                  context.pushReplacement(
                    AppRoutes.lectureDetails,
                    extra: nextLecture.id,
                  );
                }
              }

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Video Player or Empty State
                    if (currentVideo != null &&
                        _contentUrl(currentVideo).isNotEmpty)
                      VideoPlayerWidget(
                        key: ValueKey(_contentUrl(currentVideo)),
                        playerController: _videoPlayerController,
                        isDownloaded: _isDownloaded,
                        downloadProgress: _downloadProgress,
                        onDownload: () => _downloadLecture(lecture),
                        onDeleteDownload: _deleteDownloadedLecture,
                        videoUrl: _contentUrl(currentVideo),
                        title: currentVideo.title.isNotEmpty
                            ? currentVideo.title
                            : lecture.title,
                        initialPositionSeconds: _resumePositionSeconds,
                        autoplay: _autoplaySelectedVideo,
                        nextVideoTitle: nextItemTitle,
                        onPlayNext: nextItemTitle == null ? null : playNextItem,
                        onProgressChanged: (position, duration) {
                          LearningActivityService.instance.saveLectureProgress(
                            lectureId: lecture.id,
                            lectureTitle: lecture.title,
                            chapter: lecture.chapter,
                            thumbnailUrl: lecture.thumbnailUrl,
                            positionSeconds: position,
                            durationSeconds: duration,
                          );
                        },
                        notes: state.notes,
                        onAddNote: (time, text) {
                          return context.read<LectureDetailsCubit>().addNote(
                            lectureId: widget.lectureId,
                            timestampSeconds: time,
                            noteText: text,
                          );
                        },
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          vertical: 40.h,
                          horizontal: 20.w,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.video_camera_back_outlined,
                              size: 48.w,
                              color: Colors.white54,
                            ),
                            SizedBox(height: 10.h),
                            Text(
                              'لا يوجد فيديو مرفق لهذا المحاضرة في قاعدة البيانات',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'IBM',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                    if (nextItemTitle != null) ...[
                      SizedBox(height: 12.h),
                      _NextVideoCard(title: nextItemTitle, onTap: playNextItem),
                    ],

                    // 2. Video Parts Selector (If multiple videos/parts exist)
                    if (videoContents.length > 1) ...[
                      SizedBox(height: 12.h),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: List.generate(videoContents.length, (idx) {
                            final vid = videoContents[idx];
                            final isSelected = idx == _selectedVideoIndex;
                            return GestureDetector(
                              onTap: () => _selectVideo(idx, autoplay: true),
                              child: Container(
                                margin: EdgeInsets.only(left: 8.w),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 6.h,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.border,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.play_circle_fill_rounded,
                                      size: 14.sp,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.primary,
                                    ),
                                    SizedBox(width: 6.w),
                                    Text(
                                      vid.title.isNotEmpty
                                          ? vid.title
                                          : 'الجزء ${idx + 1}',
                                      style: TextStyle(
                                        fontSize: 11.5.sp,
                                        fontWeight: isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                        fontFamily: 'IBM',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],

                    SizedBox(height: 18.h),

                    // 3. Lecture Title
                    Text(
                      lecture.title,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        fontFamily: 'IBM',
                      ),
                      textAlign: TextAlign.right,
                    ),
                    SizedBox(height: 4.h),

                    // 4. Chapter / Lesson info
                    Text(
                      '${lecture.lessonNumber} - ${lecture.chapter}',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        fontFamily: 'IBM',
                      ),
                      textAlign: TextAlign.right,
                    ),
                    SizedBox(height: 14.h),

                    // 5. About Lesson Description (أولاً كما هو مطلوب)
                    if (lecture.description.isNotEmpty) ...[
                      Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18.r),
                          border: Border.all(
                            color: AppColors.border.withAlpha(90),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(6),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(6.w),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withAlpha(20),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: const Icon(
                                    Icons.info_outline_rounded,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  'عن المحاضرة',
                                  style: TextStyle(
                                    fontSize: 14.5.sp,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    fontFamily: 'IBM',
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10.h),
                            Text(
                              lecture.description,
                              style: TextStyle(
                                fontSize: 13.sp,
                                height: 1.6,
                                color: AppColors.textSecondary,
                                fontFamily: 'IBM',
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                    ],

                    if (pdfContents.isNotEmpty ||
                        audioContents.isNotEmpty ||
                        summaryContents.isNotEmpty)
                      Row(
                        children: [
                          // PDF
                          if (pdfContents.isNotEmpty)
                            Expanded(
                              child: _buildActionCard(
                                icon: Icons.picture_as_pdf_rounded,
                                iconColor: const Color(0xFFEF4444),
                                title: 'ملف PDF',
                                badgeCount: pdfContents.length > 1
                                    ? pdfContents.length
                                    : null,
                                onTap: () => _handlePdfAction(
                                  pdfContents,
                                  lecture.title,
                                ),
                              ),
                            ),
                          if (pdfContents.isNotEmpty &&
                              (audioContents.isNotEmpty ||
                                  summaryContents.isNotEmpty))
                            SizedBox(width: 10.w),

                          // Audio
                          if (audioContents.isNotEmpty)
                            Expanded(
                              child: _buildActionCard(
                                icon: Icons.headphones_rounded,
                                iconColor: const Color(0xFF3B82F6),
                                title: 'ملف صوتي',
                                badgeCount: audioContents.length > 1
                                    ? audioContents.length
                                    : null,
                                onTap: () => _handleAudioAction(
                                  audioContents,
                                  lecture.title,
                                ),
                              ),
                            ),
                          if (audioContents.isNotEmpty &&
                              summaryContents.isNotEmpty)
                            SizedBox(width: 10.w),

                          // Summary
                          if (summaryContents.isNotEmpty)
                            Expanded(
                              child: _buildActionCard(
                                icon: Icons.article_rounded,
                                iconColor: const Color(0xFF10B981),
                                title: 'ملخص المحاضرة',
                                onTap: () => _handleSummaryAction(
                                  summaryContents,
                                  lecture.description,
                                ),
                              ),
                            ),
                        ],
                      ),
                    if (extraContents.isNotEmpty) ...[
                      SizedBox(height: 12.h),
                      ...extraContents.map(
                        (content) => Padding(
                          padding: EdgeInsets.only(bottom: 10.h),
                          child: ListTile(
                            tileColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            leading: Icon(
                              content.contentType == ContentType.image
                                  ? Icons.image_rounded
                                  : Icons.link_rounded,
                              color: content.contentType == ContentType.image
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF2563EB),
                            ),
                            title: Text(
                              content.title,
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontFamily: 'IBM'),
                            ),
                            trailing: const Icon(Icons.open_in_new_rounded),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      content.contentType == ContentType.image
                                      ? _LectureImagePage(
                                          imageUrl: _contentUrl(content),
                                          title: content.title,
                                        )
                                      : InAppWebViewScreen(
                                          url: content.fileUrl,
                                          title: content.title,
                                        ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                    if (lecture.hasAccess)
                      PronunciationAssignmentWidget(
                        key: ValueKey('pronunciation-${lecture.id}'),
                        lectureId: lecture.id,
                      ),
                    SizedBox(height: 22.h),

                    // 7. Attached Exam Card
                    if (lecture.attachedExamId != null ||
                        lecture.attachedExamTitle != null)
                      Container(
                        padding: EdgeInsets.all(18.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(8),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'الامتحان على هذا المحاضرة',
                              style: TextStyle(
                                fontSize: 14.5.sp,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                fontFamily: 'IBM',
                              ),
                              textAlign: TextAlign.right,
                            ),
                            SizedBox(height: 12.h),
                            Row(
                              children: [
                                Container(
                                  width: 52.w,
                                  height: 52.w,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3E8FF),
                                    borderRadius: BorderRadius.circular(14.r),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.assignment_rounded,
                                      color: Color(0xFF7C3AED),
                                      size: 28,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        lecture.attachedExamTitle ??
                                            'امتحان على المحاضرة',
                                        style: TextStyle(
                                          fontSize: 14.5.sp,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                          fontFamily: 'IBM',
                                        ),
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(
                                        'المدة: ${lecture.attachedExamDuration} دقيقة   •   الدرجة: ${lecture.attachedExamScore} درجة',
                                        style: TextStyle(
                                          fontSize: 11.5.sp,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                          fontFamily: 'IBM',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 14.h),
                            SizedBox(
                              height: 46.h,
                              child: ElevatedButton(
                                onPressed: () {
                                  final examId =
                                      lecture.attachedExamId ??
                                      '44444444-4444-4444-4444-444444444444';
                                  context.push(
                                    AppRoutes.examDetails,
                                    extra: examId,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6366F1),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14.r),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'ابدأ الامتحان',
                                  style: TextStyle(
                                    fontSize: 14.5.sp,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'IBM',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (lecture.attachedExamId != null ||
                        lecture.attachedExamTitle != null)
                      SizedBox(height: 22.h),

                    SizedBox(height: 20.h),
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
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      period: const Duration(milliseconds: 1400),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Video Player Skeleton (16:9)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Center(
                  child: Container(
                    width: 50.w,
                    height: 50.w,
                    decoration: const BoxDecoration(
                      color: Color(0xFFCBD5E1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 18.h),

            // 2. Title & Chapter Skeleton
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 220.w,
                height: 20.h,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6.r),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 140.w,
                height: 14.h,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6.r),
                ),
              ),
            ),
            SizedBox(height: 14.h),

            // 3. About Lesson Skeleton (يظهر أولاً كما هو مطلوب)
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 24.w,
                        height: 24.w,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        width: 90.w,
                        height: 14.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Container(
                    width: double.infinity,
                    height: 11.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Container(
                    width: double.infinity,
                    height: 11.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Container(
                    width: 160.w,
                    height: 11.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 18.h),

            // 4. Three Action Cards Skeleton (PDF, Audio, Summary)
            Row(
              children: List.generate(
                3,
                (index) => Expanded(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 4.w),
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 28.w,
                          height: 28.w,
                          decoration: const BoxDecoration(
                            color: Color(0xFFCBD5E1),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Container(
                          width: 45.w,
                          height: 12.h,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20.h),

            // 5. Attached Exam Card Skeleton
            Container(
              padding: EdgeInsets.all(18.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 130.w,
                      height: 14.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 14.h),
                  Row(
                    children: [
                      Container(
                        width: 52.w,
                        height: 52.w,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 140.w,
                              height: 14.h,
                              decoration: BoxDecoration(
                                color: const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Container(
                              width: 100.w,
                              height: 10.h,
                              decoration: BoxDecoration(
                                color: const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14.h),
                  Container(
                    height: 44.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 8.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Badge(
              isLabelVisible: badgeCount != null && badgeCount > 1,
              label: Text(
                '$badgeCount',
                style: const TextStyle(fontFamily: 'IBM'),
              ),
              backgroundColor: iconColor,
              child: Icon(icon, color: iconColor, size: 28.w),
            ),
            SizedBox(height: 8.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFamily: 'IBM',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }


class _NextVideoCard extends StatelessWidget {
  const _NextVideoCard({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFEFF6FF),
    borderRadius: BorderRadius.circular(16.r),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
        child: Row(
          children: [
            Container(
              width: 42.w,
              height: 42.w,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.skip_next_rounded, color: Colors.white),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الفيديو التالي · تشغيل تلقائي',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'IBM',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'IBM',
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
          ],
        ),
      ),
    ),
  );
}

class _LectureImagePage extends StatelessWidget {
  const _LectureImagePage({required this.imageUrl, required this.title});

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
