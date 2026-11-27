import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

class _DropdownOption {
  const _DropdownOption({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
}

class NovelReaderPlayerPanel extends StatelessWidget {
  const NovelReaderPlayerPanel({
    super.key,
    required this.isPlaying,
    required this.isCompleted,
    required this.hasRecordedAudio,
    required this.downloadProgress,
    required this.listeningStatus,
    required this.playbackRateLabel,
    required this.readerVoiceId,
    required this.femaleVoiceId,
    required this.maleVoiceId,
    required this.onSeekBy,
    required this.onToggleAudio,
    required this.onPlaybackRateChanged,
    required this.onReaderVoiceChanged,
    required this.onToggleNotes,
    required this.onEnterFocusMode,
    this.onSavedWords,
    this.savedWordsCount = 0,
  });

  final bool isPlaying;
  final bool isCompleted;
  final bool hasRecordedAudio;
  final double? downloadProgress;
  final String listeningStatus;
  final String playbackRateLabel;
  final String readerVoiceId;
  final String femaleVoiceId;
  final String maleVoiceId;
  final ValueChanged<Duration> onSeekBy;
  final VoidCallback onToggleAudio;
  final ValueChanged<double> onPlaybackRateChanged;
  final ValueChanged<String> onReaderVoiceChanged;
  final VoidCallback onToggleNotes;
  final VoidCallback onEnterFocusMode;
  final VoidCallback? onSavedWords;
  final int savedWordsCount;

  void _showDropdown({
    required BuildContext context,
    required String title,
    required List<_DropdownOption> options,
  }) {
    final overlay = Overlay.of(context);
    final target = context.findRenderObject();
    if (target is! RenderBox) return;

    final position = target.localToGlobal(Offset.zero);
    final size = target.size;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => entry.remove(),
            ),
          ),
          Positioned(
            left: (position.dx + size.width / 2 - 120.w)
                .clamp(16.0, MediaQuery.sizeOf(overlayContext).width - 256.w)
                .toDouble(),
            bottom:
                MediaQuery.sizeOf(overlayContext).height - position.dy + 8.h,
            width: 240.w,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16.r),
              clipBehavior: Clip.antiAlias,
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 6.h),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5.sp,
                        fontFamily: 'IBM',
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  for (final option in options)
                    InkWell(
                      onTap: () {
                        entry.remove();
                        option.onSelected();
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 12.h,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 28.w,
                              child: option.selected
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: AppColors.primary,
                                    )
                                  : null,
                            ),
                            Expanded(
                              child: Text(
                                option.label,
                                style: TextStyle(
                                  fontFamily: 'IBM',
                                  fontSize: 13.sp,
                                  fontWeight: option.selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: option.selected
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black.withAlpha(20),
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 14.h),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppColors.border.withAlpha(80)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (listeningStatus.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: 6.h),
                child: Text(
                  listeningStatus,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    fontFamily: 'IBM',
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'تأخير 5 ثوانٍ',
                    onPressed: () => onSeekBy(const Duration(seconds: -5)),
                    icon: Icon(Icons.replay_5_rounded, size: 24.sp),
                  ),
                  SizedBox(width: 4.w),
                  IconButton(
                    tooltip: isCompleted
                        ? 'إعادة الاستماع من البداية'
                        : isPlaying
                        ? 'إيقاف مؤقت'
                        : 'تشغيل الصوت',
                    onPressed: onToggleAudio,
                    iconSize: 46.sp,
                    icon: isCompleted
                        ? const Icon(
                            Icons.replay_circle_filled_rounded,
                            color: AppColors.primary,
                          )
                        : isPlaying
                        ? const Icon(
                            Icons.pause_circle_filled_rounded,
                            color: AppColors.primary,
                          )
                        : const Icon(
                            Icons.play_circle_fill_rounded,
                            color: AppColors.primary,
                          ),
                  ),
                  SizedBox(width: 4.w),
                  IconButton(
                    tooltip: 'تقديم 5 ثوانٍ',
                    onPressed: () => onSeekBy(const Duration(seconds: 5)),
                    icon: Icon(Icons.forward_5_rounded, size: 24.sp),
                  ),
                  SizedBox(width: 6.w),
                  Builder(
                    builder: (speedContext) => Material(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10.r),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10.r),
                        onTap: () => _showDropdown(
                          context: speedContext,
                          title: 'سرعة الصوت',
                          options: [
                            for (final rate in [.75, 1.0, 1.25, 1.5, 2.0])
                              _DropdownOption(
                                label: '${rate}x',
                                selected: playbackRateLabel == '${rate}x',
                                onSelected: () => onPlaybackRateChanged(rate),
                              ),
                          ],
                        ),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 7.h,
                          ),
                          child: Text(
                            playbackRateLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.sp,
                              fontFamily: 'IBM',
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (onSavedWords != null)
                    IconButton(
                      tooltip: 'حصيلة الكلمات المحفوظة',
                      onPressed: onSavedWords,
                      icon: Badge.count(
                        count: savedWordsCount,
                        isLabelVisible: savedWordsCount > 0,
                        child: Icon(
                          Icons.collections_bookmark_outlined,
                          size: 22.sp,
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: 'ملاحظات الفصل',
                    onPressed: onToggleNotes,
                    icon: Icon(Icons.sticky_note_2_outlined, size: 22.sp),
                  ),
                  IconButton(
                    tooltip: 'وضع القراءة الكامل',
                    onPressed: onEnterFocusMode,
                    icon: Icon(Icons.fullscreen_rounded, size: 24.sp),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
