import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../domain/novel_entities.dart';
import 'novel_reader_navigation_widgets.dart';

class NovelReaderPageLayout extends StatelessWidget {
  const NovelReaderPageLayout({
    super.key,
    required this.novel,
    required this.chapter,
    required this.pageColor,
    required this.foregroundColor,
    required this.backgroundPath,
    required this.readingFocusMode,
    required this.reader,
    required this.player,
    required this.ambientMixer,
    required this.floatingNotes,
    required this.chapterCountdown,
    required this.nextChapterTitle,
    required this.onNextChapter,
    required this.onSettings,
    required this.onSelectChapter,
    required this.onCancelCountdown,
    required this.onExitFocusMode,
    required this.onSavedWords,
    required this.savedWordsCount,
    this.preparationMessage,
    this.videoBackdrop,
    this.showVideo = true,
    this.onToggleVideo,
  });

  final Novel novel;
  final NovelChapter chapter;
  final Color pageColor;
  final Color foregroundColor;
  final String? backgroundPath;
  final bool readingFocusMode;
  final String? preparationMessage;
  final Widget reader;
  final Widget player;
  final Widget ambientMixer;
  final Widget? floatingNotes;
  final int chapterCountdown;
  final String? nextChapterTitle;
  final VoidCallback? onNextChapter;
  final VoidCallback onSettings;
  final ValueChanged<NovelChapter> onSelectChapter;
  final VoidCallback onCancelCountdown;
  final VoidCallback onExitFocusMode;
  final VoidCallback onSavedWords;
  final int savedWordsCount;
  final Widget? videoBackdrop;
  final bool showVideo;
  final VoidCallback? onToggleVideo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageColor,
      appBar: readingFocusMode
          ? null
          : AppBar(
              backgroundColor: pageColor,
              foregroundColor: foregroundColor,
              elevation: 0,
              centerTitle: true,
              title: Text(
                novel.title,
                style: TextStyle(
                  fontSize: 16.5.sp,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'IBM',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                if (onToggleVideo != null)
                  IconButton(
                    tooltip:
                        showVideo ? 'إلغاء فيديو الرواية' : 'عرض فيديو الرواية',
                    onPressed: onToggleVideo,
                    icon: Icon(
                      showVideo
                          ? Icons.videocam_rounded
                          : Icons.videocam_off_outlined,
                      color: showVideo
                          ? (foregroundColor == Colors.white
                              ? const Color(0xFFA78BFA)
                              : const Color(0xFF6D28D9))
                          : foregroundColor.withValues(alpha: 0.5),
                    ),
                  ),
                IconButton(
                  tooltip: 'إعدادات القراءة',
                  onPressed: onSettings,
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
      body: SafeArea(
        child: Container(
          decoration: backgroundPath == null
              ? null
              : BoxDecoration(
                  image: DecorationImage(
                    image: FileImage(File(backgroundPath!)),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      pageColor.withValues(alpha: .35),
                      BlendMode.srcOver,
                    ),
                  ),
                ),
          child: Stack(
            children: [
              if (videoBackdrop != null)
                Positioned.fill(
                  child: RepaintBoundary(child: videoBackdrop!),
                ),
              Column(
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    child: readingFocusMode
                        ? const SizedBox.shrink()
                        : NovelChapterBar(
                            novel: novel,
                            selectedChapterId: chapter.id,
                            onSelected: onSelectChapter,
                          ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: readingFocusMode ? onExitFocusMode : null,
                      child: reader,
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: !readingFocusMode &&
                            chapterCountdown > 0 &&
                            nextChapterTitle != null &&
                            onNextChapter != null
                        ? Padding(
                            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
                            child: NovelChapterCountdown(
                              seconds: chapterCountdown,
                              nextChapterTitle: nextChapterTitle!,
                              onNext: onNextChapter!,
                              onCancel: onCancelCountdown,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    child: readingFocusMode ? const SizedBox.shrink() : player,
                  ),
                ],
              ),
              if (!readingFocusMode) ambientMixer,
              if (preparationMessage != null)
                Positioned(
                  bottom: readingFocusMode ? 24.h : 90.h,
                  left: 20.w,
                  right: 20.w,
                  child: Center(
                    child: Material(
                      elevation: 8,
                      shadowColor: Colors.black26,
                      borderRadius: BorderRadius.circular(22.r),
                      color: const Color(0xFF1E1B4B).withAlpha(235),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 9.h,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14.w,
                              height: 14.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFA78BFA),
                              ),
                            ),
                            SizedBox(width: 9.w),
                            Text(
                              preparationMessage!,
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'IBM',
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              IgnorePointer(
                child: Center(
                  child: Image.asset(
                    'assets/image/haiba_without_bg.png',
                    width: 110.w,
                    color: Colors.white.withValues(alpha: .08),
                    colorBlendMode: BlendMode.modulate,
                  ),
                ),
              ),
              if (!readingFocusMode && floatingNotes != null) floatingNotes!,
            ],
          ),
        ),
      ),
    );
  }
}
