import 'dart:async';
import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app/env.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/screen_protection_service.dart';
import '../../../novels/data/novel_listening_quota.dart';
import '../../../novels/data/novels_repository.dart';
import '../../../novels/domain/novel_entities.dart';
import '../../../novels/presentation/widgets/novel_saved_words_screen.dart';
import '../../data/services/podcast_cache_service.dart';
import '../../domain/entities/podcast_entity.dart';
import '../widgets/podcast_ambience_overlay.dart';
import '../widgets/podcast_ambience_sheet.dart';
import '../widgets/podcast_settings_sheet.dart';
import '../widgets/podcast_teleprompter_text.dart';
import '../widgets/podcast_video_backdrop.dart';
import '../widgets/podcast_wave_visualizer.dart';

class PodcastPlayerScreen extends StatefulWidget {
  const PodcastPlayerScreen({super.key, required this.episode});

  final PodcastEpisode episode;

  @override
  State<PodcastPlayerScreen> createState() => _PodcastPlayerScreenState();
}

class _PodcastPlayerScreenState extends State<PodcastPlayerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _wordPlayer = AudioPlayer();
  final NovelsRepository _novelsRepo = NovelsRepository();
  final PodcastAmbienceController _ambienceController =
      PodcastAmbienceController();
  final ValueNotifier<double> _currentSecondsNotifier = ValueNotifier<double>(
    0.0,
  );

  PodcastReadingTheme _theme =
      PodcastReadingTheme.presets[0]; // Default: Classic ('كلاسيكي')
  double _englishFontSize = 19.0;
  double _arabicFontSize = 14.5;
  bool _showTranslation = true;
  bool _showVideo = true;
  bool _isControlsExpanded = true;

  double _currentSeconds = 0.0;
  int _totalDurationSeconds = 0;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  bool _isLoading = true;
  String? _errorMessage;

  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _durationSub;
  Timer? _quotaTimer;
  final NovelListeningQuota _quota = NovelListeningQuota();

  @override
  void initState() {
    super.initState();
    ScreenProtectionService.acquire();
    _totalDurationSeconds = widget.episode.durationSeconds;
    unawaited(PodcastCacheService.instance.saveEpisode(widget.episode));
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      _durationSub = _audioPlayer.durationStream.listen((duration) {
        if (duration != null && mounted) {
          setState(() {
            _totalDurationSeconds = duration.inSeconds;
          });
        }
      });

      _posSub = _audioPlayer.positionStream.listen((position) {
        final sec = position.inMilliseconds / 1000.0;
        _currentSeconds = sec;
        _currentSecondsNotifier.value = sec;
      });

      _stateSub = _audioPlayer.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying =
                state.playing &&
                state.processingState != ProcessingState.completed;
          });
        }
      });

      final rawAudioUrl = widget.episode.audioUrl.trim();
      final audioUrl = rawAudioUrl.replaceAll(' ', '%20');

      // Check if audio file was already cached locally
      final cachedFile = await PodcastCacheService.instance.getCachedAudioFile(
        widget.episode.id,
      );
      if (cachedFile != null &&
          await cachedFile.exists() &&
          await cachedFile.length() > 1024) {
        await _audioPlayer.setFilePath(cachedFile.path);
      } else {
        await _audioPlayer.setUrl(audioUrl);
        // Cache audio file in background for subsequent offline & instant plays
        unawaited(
          PodcastCacheService.instance.cacheAudioFile(
            widget.episode.id,
            audioUrl,
          ),
        );
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'تعذر تحميل الصوت: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _quotaTimer?.cancel();
    ScreenProtectionService.release();
    _posSub?.cancel();
    _stateSub?.cancel();
    _durationSub?.cancel();
    _currentSecondsNotifier.dispose();
    unawaited(_ambienceController.dispose());
    _audioPlayer.dispose();
    _wordPlayer.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_audioPlayer.playing) {
      _audioPlayer.pause();
      _quotaTimer?.cancel();
    } else {
      if (_audioPlayer.processingState == ProcessingState.completed) {
        _audioPlayer.seek(Duration.zero);
      }
      _audioPlayer.play();
      _quotaTimer ??= Timer.periodic(const Duration(seconds: 10), (_) async {
        final status = await _quota.consumeSeconds(10);
        if (!status.allowed && mounted) {
          await _audioPlayer.pause();
          _quotaTimer?.cancel();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('انتهت حصة الاستماع الحالية.')),
          );
        }
      });
    }
  }

  void _seekBy(int seconds) {
    final target = (_currentSeconds + seconds).clamp(
      0.0,
      _totalDurationSeconds.toDouble(),
    );
    _audioPlayer.seek(Duration(seconds: target.toInt()));
  }

  void _cycleSpeed() {
    final speeds = [1.0, 1.25, 1.5, 2.0, 0.75];
    final nextIdx = (speeds.indexOf(_playbackSpeed) + 1) % speeds.length;
    final nextSpeed = speeds[nextIdx];
    setState(() => _playbackSpeed = nextSpeed);
    _audioPlayer.setSpeed(nextSpeed);
  }

  void _openWordModal(String rawWord, NovelWord? dictWord, GlobalKey wordKey) {
    final cleanWord = rawWord.replaceAll(RegExp(r'[^a-zA-Z]'), '').trim();
    if (cleanWord.isEmpty) return;

    var wordObj =
        dictWord ??
        NovelWord(
          word: cleanWord,
          arabicMeaning: 'جاري البحث عن المعنى...',
          contextMeaning: 'كلمة في بودكاست ${widget.episode.title}',
          transcription: '/$cleanWord/',
        );
    final lookupFuture = dictWord == null
        ? _novelsRepo.findWord(widget.episode.id, cleanWord)
        : null;

    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogContext) {
        final renderObject = wordKey.currentContext?.findRenderObject();
        final box = renderObject is RenderBox ? renderObject : null;
        final origin = box?.localToGlobal(Offset.zero) ?? const Offset(24, 120);
        final size = MediaQuery.sizeOf(dialogContext);
        final width = math.min(310.0, size.width - 32);
        final left = origin.dx.clamp(16.0, size.width - width - 16).toDouble();
        final top = (origin.dy - 185).clamp(72.0, size.height - 280).toDouble();

        bool isPronouncing = false;
        bool isSaved = false;

        return StatefulBuilder(
          builder: (ctx, setDialogState) => Stack(
            children: [
              if (lookupFuture != null)
                FutureBuilder<NovelWord?>(
                  future: lookupFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      wordObj = snapshot.data!;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (ctx.mounted) setDialogState(() {});
                      });
                    }
                    return const SizedBox.shrink();
                  },
                ),
              // Transparent barrier to dismiss on tap outside
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(dialogContext),
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                left: left,
                top: top,
                width: width,
                child: Material(
                  color: Colors.transparent,
                  child: GestureDetector(
                    onTap: () {}, // absorb taps inside card
                    child: Card(
                      color: Colors.white.withValues(alpha: .97),
                      elevation: 12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Word + transcription row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cleanWord,
                                        textDirection: TextDirection.ltr,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'IBM',
                                          color: Color(0xFF17202A),
                                        ),
                                      ),
                                      Text(
                                        wordObj.transcription,
                                        textDirection: TextDirection.ltr,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                          fontStyle: FontStyle.italic,
                                          fontFamily: 'IBM',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Close button
                                GestureDetector(
                                  onTap: () => Navigator.pop(dialogContext),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Arabic meaning box
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'المعنى العربي',
                                    style: TextStyle(
                                      fontFamily: 'IBM',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF64748B),
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    wordObj.arabicMeaning,
                                    style: const TextStyle(
                                      fontFamily: 'IBM',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF17202A),
                                    ),
                                    textAlign: TextAlign.right,
                                    textDirection: TextDirection.rtl,
                                  ),
                                  if (wordObj.contextMeaning.isNotEmpty &&
                                      wordObj.contextMeaning !=
                                          wordObj.arabicMeaning &&
                                      !wordObj.contextMeaning.startsWith(
                                        'كلمة في',
                                      )) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'في السياق: ${wordObj.contextMeaning}',
                                      style: const TextStyle(
                                        fontFamily: 'IBM',
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                      textAlign: TextAlign.right,
                                      textDirection: TextDirection.rtl,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Action buttons row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Pronounce button
                                _WordActionButton(
                                  tooltip: 'استمع للنطق',
                                  icon: isPronouncing
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primary,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.volume_up_rounded,
                                          color: AppColors.primary,
                                          size: 20,
                                        ),
                                  onTap: isPronouncing
                                      ? null
                                      : () async {
                                          setDialogState(
                                            () => isPronouncing = true,
                                          );
                                          try {
                                            await _playGoogleTts(cleanWord);
                                          } finally {
                                            if (ctx.mounted) {
                                              setDialogState(
                                                () => isPronouncing = false,
                                              );
                                            }
                                          }
                                        },
                                ),
                                const SizedBox(width: 6),

                                // Save word button
                                _WordActionButton(
                                  tooltip: 'حفظ الكلمة',
                                  icon: Icon(
                                    isSaved
                                        ? Icons.bookmark_added_rounded
                                        : Icons.bookmark_add_outlined,
                                    color: isSaved
                                        ? const Color(0xFF059669)
                                        : AppColors.primary,
                                    size: 20,
                                  ),
                                  onTap: isSaved
                                      ? null
                                      : () async {
                                          try {
                                            await _novelsRepo.saveWord(
                                              novelId: widget.episode.id,
                                              word: wordObj,
                                              novelTitle: widget.episode.title,
                                              chapterNumber: 1,
                                            );
                                            if (ctx.mounted) {
                                              setDialogState(
                                                () => isSaved = true,
                                              );
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(e.toString()),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                ),
                                const SizedBox(width: 6),

                                // Open saved words library button
                                _WordActionButton(
                                  tooltip: 'مكتبة الكلمات المحفوظة',
                                  icon: const Icon(
                                    Icons.collections_bookmark_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  onTap: () {
                                    Navigator.pop(dialogContext);
                                    NovelSavedWordsScreen.open(context);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _playGoogleTts(String word) async {
    await _wordPlayer.stop();
    final url =
        'https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=en&q=${Uri.encodeComponent(word)}';
    await _wordPlayer.setUrl(url);
    await _wordPlayer.play();
  }

  String _formatTime(double sec) {
    final s = sec.toInt();
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        ThemeData.estimateBrightnessForColor(_theme.pageColor) ==
        Brightness.dark;

    return Scaffold(
      backgroundColor: _theme.pageColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _theme.textColor,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text(
              widget.episode.title,
              style: TextStyle(
                fontFamily: 'IBM',
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: _theme.textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.episode.host,
              style: TextStyle(
                fontFamily: 'IBM',
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
                color: _theme.textColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _showVideo ? 'إلغاء ظهور الفيديو' : 'عرض الفيديو',
            icon: Icon(
              _showVideo ? Icons.videocam_rounded : Icons.videocam_off_outlined,
              color: _showVideo
                  ? AppColors.primary
                  : _theme.textColor.withValues(alpha: 0.5),
            ),
            onPressed: () => setState(() => _showVideo = !_showVideo),
          ),
          IconButton(
            tooltip: 'إعدادات العرض والثيمات',
            icon: Icon(Icons.tune_rounded, color: _theme.textColor),
            onPressed: () => PodcastSettingsSheet.show(
              context,
              currentTheme: _theme,
              englishFontSize: _englishFontSize,
              arabicFontSize: _arabicFontSize,
              showTranslation: _showTranslation,
              showVideo: _showVideo,
              onThemeChanged: (t) => setState(() => _theme = t),
              onEnglishFontSizeChanged: (s) =>
                  setState(() => _englishFontSize = s),
              onArabicFontSizeChanged: (s) =>
                  setState(() => _arabicFontSize = s),
              onShowTranslationChanged: (val) =>
                  setState(() => _showTranslation = val),
              onShowVideoChanged: (val) => setState(() => _showVideo = val),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Middle News-Broadcast Teleprompter & Video Area with Draggable Ambient Mixer
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ValueListenableBuilder<double>(
                    valueListenable: _currentSecondsNotifier,
                    builder: (context, currentSec, _) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          // Video Backdrop (News style: video on right with smooth gradient blend)
                          if (_showVideo)
                            RepaintBoundary(
                              child: PodcastVideoBackdrop(
                                currentSeconds: currentSec,
                                isPlaying: _isPlaying,
                                videoSegments: widget.episode.videoSegments,
                                pageColor: _theme.pageColor,
                                fallbackCoverUrl: widget.episode.coverUrl,
                              ),
                            ),

                          // Watermark App Logo (matches novel reader style)
                          IgnorePointer(
                            child: Center(
                              child: Image.asset(
                                'assets/image/haiba_without_bg.png',
                                width: 130.w,
                                color: Colors.white.withValues(alpha: .08),
                                colorBlendMode: BlendMode.modulate,
                              ),
                            ),
                          ),

                          // Synchronized Teleprompter Text Overlay on left
                          PodcastTeleprompterText(
                            episode: widget.episode,
                            currentSeconds: currentSec,
                            totalDurationSeconds: _totalDurationSeconds,
                            isPlaying: _isPlaying,
                            englishFontSize: _englishFontSize,
                            arabicFontSize: _arabicFontSize,
                            textColor: _theme.textColor,
                            highlightColor: _theme.highlightColor,
                            pageColor: _theme.pageColor,
                            showTranslation: _showTranslation,
                            onWordTap: _openWordModal,
                            onLineTap: (targetSec) {
                              _audioPlayer.seek(
                                Duration(seconds: targetSec.toInt()),
                              );
                            },
                          ),

                          if (_errorMessage != null)
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'IBM',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),

                  // Floating Draggable Ambient Sounds Mixer (matches Novel Reader UI/UX)
                  PodcastAmbientMixerOverlay(
                    controller: _ambienceController,
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            // Bottom Collapsible Audio Controls with Waves
            _buildAudiobookControls(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildAudiobookControls(bool isDark) {
    final playerBg = isDark
        ? const Color(0xFF1E293B)
        : Colors.white.withValues(alpha: 0.95);
    final controlColor = isDark ? Colors.white : AppColors.textPrimary;

    return Container(
      decoration: BoxDecoration(
        color: playerBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 20.w,
        vertical: _isControlsExpanded ? 12.h : 8.h,
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Collapse / Expand Handle Bar Pill (Tap to toggle)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  setState(() => _isControlsExpanded = !_isControlsExpanded),
              child: Padding(
                padding: EdgeInsets.only(bottom: 6.h, top: 2.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 42.w,
                      height: 4.5.h,
                      decoration: BoxDecoration(
                        color: controlColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(3.r),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Professional Audio Wave Visualizer (Always visible, even when collapsed)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (!_isControlsExpanded) {
                  setState(() => _isControlsExpanded = true);
                }
              },
              child: RepaintBoundary(
                child: PodcastWaveVisualizer(
                  isPlaying: _isPlaying,
                  height: _isControlsExpanded ? 36.h : 44.h,
                  waveColor: _theme.highlightColor != const Color(0xFFFFE28A)
                      ? _theme.highlightColor
                      : const Color(0xFF6366F1),
                  secondaryColor: const Color(0xFFA855F7),
                ),
              ),
            ),

            if (_isControlsExpanded) ...[
              SizedBox(height: 8.h),

              // Scrubber Slider & Timers (driven by ValueListenableBuilder for 60fps smoothness)
              ValueListenableBuilder<double>(
                valueListenable: _currentSecondsNotifier,
                builder: (context, currentSec, _) {
                  final progressVal = _totalDurationSeconds > 0
                      ? (currentSec / _totalDurationSeconds).clamp(0.0, 1.0)
                      : 0.0;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3.5,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor: isDark
                              ? Colors.white24
                              : Colors.black12,
                          thumbColor: AppColors.primary,
                        ),
                        child: Slider(
                          value: progressVal,
                          onChanged: (val) {
                            final target = val * _totalDurationSeconds;
                            _audioPlayer.seek(
                              Duration(seconds: target.toInt()),
                            );
                          },
                        ),
                      ),

                      // Time Progress Indicators
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.w),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatTime(currentSec),
                              style: TextStyle(
                                fontFamily: 'IBM',
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: controlColor.withValues(alpha: 0.7),
                              ),
                            ),
                            Text(
                              _formatTime(_totalDurationSeconds.toDouble()),
                              style: TextStyle(
                                fontFamily: 'IBM',
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: controlColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: 10.h),

              // Main Controls Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Playback Speed Button
                  GestureDetector(
                    onTap: _cycleSpeed,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white12
                            : Colors.black.withAlpha(12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_playbackSpeed}x',
                        style: TextStyle(
                          fontFamily: 'IBM',
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                          color: controlColor,
                        ),
                      ),
                    ),
                  ),

                  // Skip -10s
                  IconButton(
                    icon: Icon(
                      Icons.replay_10_rounded,
                      color: controlColor,
                      size: 28.sp,
                    ),
                    onPressed: () => _seekBy(-10),
                  ),

                  // Play / Pause Glowing Button
                  GestureDetector(
                    onTap: _isLoading ? null : _togglePlayPause,
                    child: Container(
                      width: 58.w,
                      height: 58.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF6366F1,
                            ).withValues(alpha: 0.45),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Icon(
                                _isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 34.sp,
                              ),
                      ),
                    ),
                  ),

                  // Skip +10s
                  IconButton(
                    icon: Icon(
                      Icons.forward_10_rounded,
                      color: controlColor,
                      size: 28.sp,
                    ),
                    onPressed: () => _seekBy(10),
                  ),

                  // Saved Words Shortcut
                  IconButton(
                    tooltip: 'الكلمات',
                    icon: Icon(
                      Icons.collections_bookmark_outlined,
                      color: controlColor,
                      size: 24.sp,
                    ),
                    onPressed: () => NovelSavedWordsScreen.open(context),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
            ],
          ],
        ),
      ),
    );
  }
}

/// A compact circular icon action button used inside the word popup card.
class _WordActionButton extends StatelessWidget {
  const _WordActionButton({
    required this.icon,
    required this.onTap,
    this.tooltip = '',
  });

  final Widget icon;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: icon),
        ),
      ),
    );
  }
}
