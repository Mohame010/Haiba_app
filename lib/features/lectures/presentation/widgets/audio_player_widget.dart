import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_helper.dart';

class AudioPlayerModal extends StatefulWidget {
  final String audioUrl;
  final String title;

  const AudioPlayerModal({
    super.key,
    required this.audioUrl,
    required this.title,
  });

  @override
  State<AudioPlayerModal> createState() => _AudioPlayerModalState();
}

class _AudioPlayerModalState extends State<AudioPlayerModal> {
  late AudioPlayer _player;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initAudio();
  }

  Future<void> _initAudio() async {
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
    });

    try {
      final uri = Uri.tryParse(widget.audioUrl);
      if (uri?.scheme == 'file') {
        await _player.setSourceDeviceFile(File.fromUri(uri!).path);
      } else {
        await _player.setSourceUrl(widget.audioUrl);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
          SizedBox(height: 18.h),

          // Icon
          Container(
            width: 64.w,
            height: 64.w,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(Icons.headphones_rounded, color: AppColors.info, size: 32.w),
            ),
          ),
          SizedBox(height: 14.h),

          Text(
            widget.title,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFamily: 'IBM',
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 18.h),

          // Slider & Times
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4.h,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.w),
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.cardLight,
              thumbColor: AppColors.primary,
            ),
            child: Slider(
              value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble()),
              min: 0.0,
              max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
              onChanged: (val) {
                _player.seek(Duration(seconds: val.toInt()));
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateTimeHelper.formatDuration(_position),
                  style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary, fontFamily: 'IBM'),
                ),
                Text(
                  DateTimeHelper.formatDuration(_duration),
                  style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary, fontFamily: 'IBM'),
                ),
              ],
            ),
          ),
          SizedBox(height: 18.h),

          // Play / Pause Button
          GestureDetector(
            onTap: () {
              if (_isPlaying) {
                _player.pause();
              } else {
                _player.resume();
              }
            },
            child: Container(
              width: 58.w,
              height: 58.w,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(80),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 34.w,
              ),
            ),
          ),
          SizedBox(height: 14.h),
        ],
      ),
    );
  }
}

