import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../novels/data/ambient_crossfade_player.dart';
import '../../../novels/data/novel_ambience_service.dart';

class PodcastAmbienceController {
  final NovelAmbienceService _service = NovelAmbienceService();
  final Map<NovelAmbientSound, AmbientCrossfadePlayer> _players = {};
  final Set<NovelAmbientSound> activeSounds = {};
  final Set<NovelAmbientSound> downloadingSounds = {};
  final Map<NovelAmbientSound, double> volumes = {
    for (final sound in NovelAmbientSound.values) sound: 0.35,
  };

  final ValueNotifier<int> activeCountNotifier = ValueNotifier<int>(0);

  static final List<({NovelAmbientSound sound, String label, IconData icon})> availableSounds = [
    (sound: NovelAmbientSound.rain, label: 'صوت المطر', icon: Icons.water_drop_rounded),
    (sound: NovelAmbientSound.angel, label: 'صوت الهواء والنسيم', icon: Icons.air_rounded),
    (sound: NovelAmbientSound.sea, label: 'أمواج البحر', icon: Icons.waves_rounded),
    (sound: NovelAmbientSound.birds, label: 'تغريد العصافير', icon: Icons.forest_rounded),
    (sound: NovelAmbientSound.water, label: 'خرير المياه', icon: Icons.shower_rounded),
    (sound: NovelAmbientSound.fire, label: 'نيران هادئة', icon: Icons.local_fire_department_rounded),
  ];

  Future<void> toggleSound(NovelAmbientSound sound, {VoidCallback? onChanged}) async {
    if (activeSounds.contains(sound)) {
      activeSounds.remove(sound);
      activeCountNotifier.value = activeSounds.length;
      onChanged?.call();
      await _players[sound]?.stop();
      return;
    }

    downloadingSounds.add(sound);
    onChanged?.call();

    try {
      final path = await _service.downloadFromStorage(sound);
      downloadingSounds.remove(sound);
      activeSounds.add(sound);
      activeCountNotifier.value = activeSounds.length;
      onChanged?.call();

      final player = _players.putIfAbsent(sound, () => AmbientCrossfadePlayer());
      await player.play(path, volume: volumes[sound] ?? 0.35);
    } catch (e) {
      downloadingSounds.remove(sound);
      activeSounds.remove(sound);
      activeCountNotifier.value = activeSounds.length;
      onChanged?.call();
      debugPrint('[PodcastAmbience] Error playing sound $sound: $e');
    }
  }

  Future<void> setSoundVolume(NovelAmbientSound sound, double vol) async {
    volumes[sound] = vol;
    if (activeSounds.contains(sound)) {
      await _players[sound]?.setVolume(vol);
    }
  }

  Future<void> stopAll() async {
    for (final player in _players.values) {
      await player.stop();
    }
    activeSounds.clear();
    activeCountNotifier.value = 0;
  }

  Future<void> dispose() async {
    activeCountNotifier.dispose();
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
    activeSounds.clear();
  }
}

class PodcastAmbienceSheet extends StatefulWidget {
  const PodcastAmbienceSheet({
    super.key,
    required this.controller,
  });

  final PodcastAmbienceController controller;

  static Future<void> show(BuildContext context, PodcastAmbienceController controller) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PodcastAmbienceSheet(controller: controller),
    );
  }

  @override
  State<PodcastAmbienceSheet> createState() => _PodcastAmbienceSheetState();
}

class _PodcastAmbienceSheetState extends State<PodcastAmbienceSheet> {
  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Center(
            child: Container(
              width: 44.w,
              height: 4.5.h,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38.w,
                    height: 38.w,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.headphones_rounded,
                      color: AppColors.primary,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'أصوات الخلفية المريحة',
                        style: TextStyle(
                          fontFamily: 'IBM',
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'امزج أصوات المطر والهواء مع البودكاست لتركيز أعمق',
                        style: TextStyle(
                          fontFamily: 'IBM',
                          fontSize: 11.5.sp,
                          color: isDark ? Colors.white60 : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (ctrl.activeSounds.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    await ctrl.stopAll();
                    if (mounted) setState(() {});
                  },
                  child: Text(
                    'إيقاف الكل',
                    style: TextStyle(
                      fontFamily: 'IBM',
                      fontSize: 12.sp,
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 18.h),

          // Sounds Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: PodcastAmbienceController.availableSounds.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12.h,
              crossAxisSpacing: 12.w,
              childAspectRatio: 2.3,
            ),
            itemBuilder: (context, index) {
              final item = PodcastAmbienceController.availableSounds[index];
              final sound = item.sound;
              final isActive = ctrl.activeSounds.contains(sound);
              final isDownloading = ctrl.downloadingSounds.contains(sound);
              final vol = ctrl.volumes[sound] ?? 0.35;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : (isDark ? Colors.white10 : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: isActive ? AppColors.primary : Colors.black12,
                    width: isActive ? 1.6 : 1.0,
                  ),
                ),
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: isDownloading
                          ? null
                          : () async {
                              await ctrl.toggleSound(sound, onChanged: () {
                                if (mounted) setState(() {});
                              });
                            },
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            color: isActive ? AppColors.primary : (isDark ? Colors.white70 : AppColors.textSecondary),
                            size: 22.sp,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              item.label,
                              style: TextStyle(
                                fontFamily: 'IBM',
                                fontSize: 12.5.sp,
                                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                                color: isActive ? AppColors.primary : (isDark ? Colors.white : AppColors.textPrimary),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isDownloading)
                            SizedBox(
                              width: 16.w,
                              height: 16.w,
                              child: const CircularProgressIndicator(strokeWidth: 2),
                            )
                          else if (isActive)
                            Container(
                              width: 8.w,
                              height: 8.w,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isActive) ...[
                      SizedBox(height: 4.h),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2.5,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                          activeTrackColor: AppColors.primary,
                          thumbColor: AppColors.primary,
                        ),
                        child: Slider(
                          value: vol,
                          min: 0.05,
                          max: 1.0,
                          onChanged: (val) async {
                            setState(() {});
                            await ctrl.setSoundVolume(sound, val);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          SizedBox(height: 14.h),
        ],
      ),
    );
  }
}
