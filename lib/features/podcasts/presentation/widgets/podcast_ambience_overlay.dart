import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../novels/data/novel_ambience_service.dart';
import 'podcast_ambience_sheet.dart';

class PodcastAmbientMixerOverlay extends StatefulWidget {
  const PodcastAmbientMixerOverlay({
    super.key,
    required this.controller,
    required this.isDark,
  });

  final PodcastAmbienceController controller;
  final bool isDark;

  @override
  State<PodcastAmbientMixerOverlay> createState() =>
      _PodcastAmbientMixerOverlayState();
}

class _PodcastAmbientMixerOverlayState extends State<PodcastAmbientMixerOverlay> {
  late final ValueNotifier<Offset> _mixerPosition;
  bool _isPanelVisible = false;

  @override
  void initState() {
    super.initState();
    // Default starting position: top-right area
    _mixerPosition = ValueNotifier<Offset>(const Offset(20, 80));
  }

  @override
  void dispose() {
    _mixerPosition.dispose();
    super.dispose();
  }

  void _moveMixer(Offset delta, Size size, double panelWidth, double panelHeight) {
    final current = _mixerPosition.value;
    final newX = (current.dx + delta.dx).clamp(
      12.0,
      math.max(12.0, size.width - panelWidth - 12.0),
    ).toDouble();
    final newY = (current.dy + delta.dy).clamp(
      12.0,
      math.max(12.0, size.height - panelHeight - 12.0),
    ).toDouble();
    _mixerPosition.value = Offset(newX, newY);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Offset>(
      valueListenable: _mixerPosition,
      builder: (context, position, _) {
        final size = MediaQuery.sizeOf(context);
        final panelWidth = _isPanelVisible
            ? math.min(330.0, size.width - 24.0)
            : 54.0;
        final panelHeight = _isPanelVisible ? 480.0 : 54.0;

        final left = position.dx
            .clamp(12.0, math.max(12.0, size.width - panelWidth - 12.0))
            .toDouble();
        final top = position.dy
            .clamp(12.0, math.max(12.0, size.height - panelHeight - 12.0))
            .toDouble();

        final activeCount = widget.controller.activeSounds.length;
        final hasActive = activeCount > 0;

        // 1. Collapsed Floating Draggable Circle Button
        if (!_isPanelVisible) {
          return Positioned(
            left: left,
            top: top,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) =>
                  _moveMixer(details.delta, size, panelWidth, panelHeight),
              child: Material(
                color: widget.isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.96)
                    : Colors.white.withValues(alpha: 0.96),
                elevation: 8,
                shadowColor: Colors.black38,
                shape: const CircleBorder(),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      tooltip: 'أصوات الخلفية (اسحب لتحريك الأيقونة)',
                      onPressed: () =>
                          setState(() => _isPanelVisible = true),
                      icon: Icon(
                        hasActive
                            ? Icons.graphic_eq_rounded
                            : Icons.surround_sound_rounded,
                        color: hasActive
                            ? const Color(0xFF8B5CF6)
                            : (widget.isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF475569)),
                      ),
                    ),
                    if (hasActive)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: widget.isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              width: 2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x6622C55E),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }

        // 2. Expanded Floating Draggable Panel
        final surfaceColor = widget.isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.96)
            : Theme.of(context).colorScheme.surface.withValues(alpha: 0.96);
        final textColor = widget.isDark ? Colors.white : const Color(0xFF1E293B);
        final subtextColor = widget.isDark
            ? const Color(0xFF94A3B8)
            : const Color(0xFF64748B);

        return Positioned(
          left: left,
          top: top,
          width: panelWidth,
          child: Material(
            color: surfaceColor,
            elevation: 10,
            shadowColor: Colors.black38,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Draggable Header
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) =>
                        _moveMixer(details.delta, size, panelWidth, panelHeight),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.drag_indicator_rounded,
                            color: subtextColor.withValues(alpha: 0.6),
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                hasActive
                                    ? Icons.graphic_eq_rounded
                                    : Icons.surround_sound_rounded,
                                color: const Color(0xFF8B5CF6),
                                size: 22,
                              ),
                              if (hasActive)
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF22C55E),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: widget.isDark
                                            ? const Color(0xFF1E293B)
                                            : Colors.white,
                                        width: 1.5,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x6622C55E),
                                          blurRadius: 3,
                                          spreadRadius: 0.5,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'أصوات الخلفية',
                            style: TextStyle(
                              fontFamily: 'IBM',
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: textColor,
                            ),
                          ),
                          if (hasActive) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF22C55E),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$activeCount شغال',
                                    style: const TextStyle(
                                      color: Color(0xFF16A34A),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'IBM',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const Spacer(),
                          IconButton(
                            tooltip: 'تصغير',
                            onPressed: () =>
                                setState(() => _isPanelVisible = false),
                            icon: Icon(
                              Icons.remove_rounded,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Ambient Sounds List
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: math.min(
                        380.0,
                        math.max(160.0, size.height - 180),
                      ),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: PodcastAmbienceController.availableSounds.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 6,
                        color: widget.isDark ? Colors.white12 : Colors.black12,
                      ),
                      itemBuilder: (context, index) {
                        final item =
                            PodcastAmbienceController.availableSounds[index];
                        final active =
                            widget.controller.activeSounds.contains(item.sound);
                        final downloading = widget.controller.downloadingSounds
                            .contains(item.sound);
                        final volume =
                            widget.controller.volumes[item.sound] ?? 0.35;

                        return Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  active
                                      ? Icons.graphic_eq_rounded
                                      : Icons.volume_off_outlined,
                                  size: 21,
                                  color: active
                                      ? const Color(0xFF22C55E)
                                      : subtextColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${item.label} • ${active ? 'شغال' : 'متوقف'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'IBM',
                                      fontSize: 13,
                                      fontWeight: active
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: active ? textColor : subtextColor,
                                    ),
                                  ),
                                ),
                                if (downloading)
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF8B5CF6),
                                      ),
                                    ),
                                  )
                                else
                                  Switch(
                                    value: active,
                                    activeColor: const Color(0xFF8B5CF6),
                                    onChanged: downloading
                                        ? null
                                        : (_) {
                                            widget.controller.toggleSound(
                                              item.sound,
                                              onChanged: () {
                                                if (mounted) setState(() {});
                                              },
                                            );
                                          },
                                  ),
                              ],
                            ),
                            if (active)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 2,
                                  bottom: 4,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.volume_down_rounded,
                                      size: 20,
                                      color: Color(0xFF8B5CF6),
                                    ),
                                    Expanded(
                                      child: Slider(
                                        value: volume.clamp(0.0, 1.0),
                                        onChanged: (value) {
                                          setState(() {
                                            widget.controller.setSoundVolume(
                                              item.sound,
                                              value,
                                            );
                                          });
                                        },
                                        activeColor: const Color(0xFF8B5CF6),
                                        inactiveColor: widget.isDark
                                            ? Colors.white24
                                            : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 38,
                                      child: Text(
                                        '${(volume * 100).round()}%',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'IBM',
                                          color: subtextColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),

                  // Stop All Action (if any sound active)
                  if (hasActive) ...[
                    const SizedBox(height: 4),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                      ),
                      onPressed: () async {
                        await widget.controller.stopAll();
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                      label: const Text(
                        'إيقاف جميع الأصوات',
                        style: TextStyle(
                          fontFamily: 'IBM',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
