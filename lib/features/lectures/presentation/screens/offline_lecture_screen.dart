import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/screen_protection_service.dart';
import '../../data/services/offline_lecture_service.dart';
import '../../domain/entities/lecture_content_entity.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/pdf_viewer_dialog.dart';
import '../widgets/video_player_widget.dart';

class OfflineLectureScreen extends StatefulWidget {
  final DownloadedLecture lecture;

  const OfflineLectureScreen({super.key, required this.lecture});

  @override
  State<OfflineLectureScreen> createState() => _OfflineLectureScreenState();
}

class _OfflineLectureScreenState extends State<OfflineLectureScreen> {
  final VideoPlayerWidgetController _playerController =
      VideoPlayerWidgetController();
  int _videoIndex = 0;

  @override
  void initState() {
    super.initState();
    ScreenProtectionService.acquire();
  }

  @override
  void dispose() {
    ScreenProtectionService.release();
    super.dispose();
  }

  List<DownloadedContent> get _videos =>
      widget.lecture.contents
          .where((item) => item.type == ContentType.video)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  Future<void> _openPdf(DownloadedContent content) async {
    final viewer = Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PdfViewerModal(
          pdfUrl: Uri.file(content.localPath).toString(),
          title: content.title,
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playerController.enterPictureInPicture();
    });
    await viewer;
    _playerController.exitPictureInPicture();
  }

  Future<void> _openAudio(DownloadedContent content) async {
    final sheet = showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AudioPlayerModal(
        audioUrl: Uri.file(content.localPath).toString(),
        title: content.title,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playerController.enterPictureInPicture();
    });
    await sheet;
    _playerController.exitPictureInPicture();
  }

  @override
  Widget build(BuildContext context) {
    final videos = _videos;
    final video = videos.isEmpty
        ? null
        : videos[_videoIndex.clamp(0, videos.length - 1)];
    final pdfs = widget.lecture.contents
        .where((item) => item.type == ContentType.pdf)
        .toList();
    final audios = widget.lecture.contents
        .where((item) => item.type == ContentType.audio)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('مشاهدة بدون إنترنت'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (video != null)
              VideoPlayerWidget(
                key: ValueKey(video.localPath),
                videoUrl: Uri.file(video.localPath).toString(),
                title: video.title,
                playerController: _playerController,
              )
            else
              const AspectRatio(
                aspectRatio: 16 / 9,
                child: ColoredBox(
                  color: Color(0xFF0F172A),
                  child: Center(
                    child: Text(
                      'ملف الفيديو غير متاح',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            if (videos.length > 1) ...[
              SizedBox(height: 10.h),
              Wrap(
                spacing: 8.w,
                children: List.generate(videos.length, (index) {
                  return ChoiceChip(
                    label: Text(videos[index].title),
                    selected: index == _videoIndex,
                    onSelected: (_) => setState(() => _videoIndex = index),
                  );
                }),
              ),
            ],
            SizedBox(height: 20.h),
            Text(
              widget.lecture.title,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 19.sp,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                fontFamily: 'IBM',
              ),
            ),
            SizedBox(height: 5.h),
            Text(
              '${widget.lecture.lessonNumber} • ${widget.lecture.chapter}',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'IBM',
                fontSize: 13.sp,
              ),
            ),
            SizedBox(height: 18.h),
            if (pdfs.isNotEmpty || audios.isNotEmpty)
              Text(
                'ملحقات الدرس',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'IBM',
                ),
              ),
            SizedBox(height: 8.h),
            ...pdfs.map(
              (item) => _resourceTile(
                item,
                Icons.picture_as_pdf_rounded,
                const Color(0xFFEF4444),
                () => _openPdf(item),
              ),
            ),
            ...audios.map(
              (item) => _resourceTile(
                item,
                Icons.headphones_rounded,
                const Color(0xFF3B82F6),
                () => _openAudio(item),
              ),
            ),
            if (widget.lecture.description.isNotEmpty) ...[
              SizedBox(height: 18.h),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Text(
                    widget.lecture.description,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      height: 1.6,
                      color: AppColors.textSecondary,
                      fontFamily: 'IBM',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _resourceTile(
    DownloadedContent item,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: color),
        title: Text(item.title, style: const TextStyle(fontFamily: 'IBM')),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
