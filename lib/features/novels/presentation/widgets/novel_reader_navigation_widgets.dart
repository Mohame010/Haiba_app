import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../domain/novel_entities.dart';

class NovelChapterBar extends StatefulWidget {
  const NovelChapterBar({
    super.key,
    required this.novel,
    required this.selectedChapterId,
    required this.onSelected,
  });

  final Novel novel;
  final String? selectedChapterId;
  final ValueChanged<NovelChapter> onSelected;

  @override
  State<NovelChapterBar> createState() => _NovelChapterBarState();
}

class _NovelChapterBarState extends State<NovelChapterBar> {
  final ScrollController _controller = ScrollController();
  final Map<String, GlobalKey> _chapterKeys = {};

  @override
  void initState() {
    super.initState();
    _scheduleReveal();
  }

  @override
  void didUpdateWidget(covariant NovelChapterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedChapterId != widget.selectedChapterId ||
        oldWidget.novel.chapters.length != widget.novel.chapters.length) {
      _scheduleReveal();
    }
  }

  void _scheduleReveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _revealSelected();
    });
  }

  Future<void> _revealSelected() async {
    final selectedId = widget.selectedChapterId;
    if (selectedId == null || !_controller.hasClients) return;
    final index = widget.novel.chapters.indexWhere(
      (chapter) => chapter.id == selectedId,
    );
    if (index < 0) return;

    var selectedContext = _chapterKeys[selectedId]?.currentContext;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (selectedContext == null && widget.novel.chapters.length > 1) {
      final position = _controller.position;
      final target =
          position.maxScrollExtent *
          (index / (widget.novel.chapters.length - 1));
      if (reduceMotion) {
        _controller.jumpTo(target);
      } else {
        await _controller.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      selectedContext = _chapterKeys[selectedId]?.currentContext;
    }
    if (!mounted || selectedContext == null || !selectedContext.mounted) return;
    await Scrollable.ensureVisible(
      selectedContext,
      alignment: .5,
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        height: 56.h,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ListView.builder(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            itemCount: widget.novel.chapters.length,
            itemBuilder: (_, index) {
              final chapter = widget.novel.chapters[index];
              final isSelected = chapter.id == widget.selectedChapterId;
              final textColor = isSelected
                  ? Colors.white
                  : const Color(0xFF1E293B);
              return Padding(
                key: _chapterKeys.putIfAbsent(chapter.id, GlobalKey.new),
                padding: EdgeInsetsDirectional.only(end: 8.w),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14.r),
                    onTap: () => widget.onSelected(chapter),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 8.h,
                      ),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        chapter.title,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12.5.sp,
                          fontFamily: 'IBM',
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class NovelChapterCountdown extends StatelessWidget {
  const NovelChapterCountdown({
    super.key,
    required this.seconds,
    required this.nextChapterTitle,
    required this.onNext,
    required this.onCancel,
  });

  final int seconds;
  final String nextChapterTitle;
  final VoidCallback onNext;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16.r),
      elevation: 4,
      shadowColor: Colors.black.withAlpha(25),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.skip_next_rounded,
                    color: AppColors.primary,
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'الانتقال للفصل التالي بعد $seconds ثوانٍ',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'IBM',
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          nextChapterTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            color: AppColors.textSecondary,
                            fontFamily: 'IBM',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  child: Text(
                    'الانتقال الآن',
                    style: TextStyle(fontFamily: 'IBM', fontSize: 12.sp),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onCancel,
                  child: Text(
                    'إلغاء التمرير التلقائي',
                    style: TextStyle(
                      fontFamily: 'IBM',
                      fontSize: 11.5.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
