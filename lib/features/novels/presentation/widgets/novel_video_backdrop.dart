import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../domain/novel_entities.dart';

class NovelVideoBackdrop extends StatefulWidget {
  const NovelVideoBackdrop({
    super.key,
    required this.currentSeconds,
    required this.isPlaying,
    required this.videoSegments,
    required this.pageColor,
    this.fallbackCoverUrl,
  });

  final double currentSeconds;
  final bool isPlaying;
  final List<NovelVideoSegment> videoSegments;
  final Color pageColor;
  final String? fallbackCoverUrl;

  @override
  State<NovelVideoBackdrop> createState() => _NovelVideoBackdropState();
}

class _NovelVideoBackdropState extends State<NovelVideoBackdrop> {
  NovelVideoSegment? _activeSegment;
  VideoPlayerController? _controller;
  String? _loadedUrl;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _checkAndSyncVideo();
  }

  @override
  void didUpdateWidget(covariant NovelVideoBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoSegments != widget.videoSegments) {
      _checkAndSyncVideo();
    } else {
      _syncVideoState();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  NovelVideoSegment? _findSegmentAt(double seconds) {
    if (widget.videoSegments.isEmpty) return null;

    for (final seg in widget.videoSegments) {
      if (seg.isActiveAt(seconds)) return seg;
    }

    // If only one segment/video is configured, keep it active across the chapter
    if (widget.videoSegments.length == 1) {
      return widget.videoSegments.first;
    }

    return null;
  }

  Future<void> _checkAndSyncVideo() async {
    final segment = _findSegmentAt(widget.currentSeconds);

    if (segment == null || segment.videoUrl.trim().isEmpty) {
      if (_activeSegment != null) {
        _activeSegment = null;
        _controller?.pause();
        if (mounted) setState(() {});
      }
      return;
    }

    var cleanUrl = segment.videoUrl.trim().replaceAll(' ', '%20');
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      try {
        final client = Supabase.instance.client;
        var path = cleanUrl.replaceFirst(RegExp(r'^/+'), '');
        String bucket = 'videos';
        if (path.startsWith('videos/')) {
          bucket = 'videos';
          path = path.substring('videos/'.length);
        } else if (path.startsWith('podcasts/')) {
          bucket = 'podcasts';
          path = path.substring('podcasts/'.length);
        } else if (path.contains('/')) {
          bucket = path.substring(0, path.indexOf('/'));
          path = path.substring(path.indexOf('/') + 1);
        }
        cleanUrl = client.storage.from(bucket).getPublicUrl(path);
      } catch (_) {}
    }

    if (_loadedUrl != cleanUrl) {
      _loadedUrl = cleanUrl;
      _activeSegment = segment;
      final old = _controller;
      _controller = null;
      _isInitialized = false;
      await old?.dispose();

      if (!mounted) return;

      try {
        final ctrl = VideoPlayerController.networkUrl(
          Uri.parse(cleanUrl),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        _controller = ctrl;
        await ctrl.initialize();
        await ctrl.setVolume(0.0); // Muted so novel narration & ambience remain clear
        await ctrl.setLooping(true);

        if (mounted) {
          setState(() => _isInitialized = true);
          final segDur = segment.endSeconds - segment.startSeconds;
          final maxAllowed = segDur > 0 ? segDur : 999999.0;
          final offsetSec = (widget.currentSeconds - segment.startSeconds).clamp(0.0, maxAllowed);
          await ctrl.seekTo(Duration(milliseconds: (offsetSec * 1000).toInt()));
          if (widget.isPlaying) {
            await ctrl.play();
          }
        }
      } catch (e, stack) {
        debugPrint('[NovelVideoBackdrop] Video init failed for $cleanUrl: $e\n$stack');
      }
      return;
    }

    _syncVideoState();
  }

  void _syncVideoState() {
    final ctrl = _controller;
    final segment = _activeSegment;
    if (ctrl == null || !_isInitialized || segment == null) return;

    if (widget.isPlaying && !ctrl.value.isPlaying) {
      ctrl.play();
    } else if (!widget.isPlaying && ctrl.value.isPlaying) {
      ctrl.pause();
    }

    final targetMs = ((widget.currentSeconds - segment.startSeconds) * 1000).toInt();
    final currentVideoMs = ctrl.value.position.inMilliseconds;
    if ((targetMs - currentVideoMs).abs() > 2000 && targetMs >= 0) {
      ctrl.seekTo(Duration(milliseconds: targetMs));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        ThemeData.estimateBrightnessForColor(widget.pageColor) ==
        Brightness.dark;

    final hasActiveVideo = _controller != null && _isInitialized && _activeSegment != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Background Content: Either Video or Fallback Cover Artwork
        if (hasActiveVideo)
          Align(
            alignment: Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.88,
              heightFactor: 1.0,
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: _controller!.value.size.width > 0
                        ? _controller!.value.size.width
                        : 16,
                    height: _controller!.value.size.height > 0
                        ? _controller!.value.size.height
                        : 9,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ),
            ),
          )
        else if (widget.fallbackCoverUrl != null &&
            widget.fallbackCoverUrl!.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.80,
              heightFactor: 1.0,
              child: Opacity(
                opacity: isDark ? 0.35 : 0.20,
                child: Image.network(
                  widget.fallbackCoverUrl!,
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),

        // 2. Horizontal News-Style Blend Gradient
        // Solid theme color on the left where text is read, fading to transparent on the right
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: const [0.0, 0.30, 0.65, 1.0],
                colors: [
                  widget.pageColor,
                  widget.pageColor.withValues(alpha: 0.95),
                  widget.pageColor.withValues(alpha: 0.40),
                  widget.pageColor.withValues(alpha: 0.15),
                ],
              ),
            ),
          ),
        ),

        // 3. Subtle Vertical Vignette to soft-blend top and bottom edges
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.12, 0.85, 1.0],
                colors: [
                  widget.pageColor.withValues(alpha: 0.80),
                  Colors.transparent,
                  Colors.transparent,
                  widget.pageColor.withValues(alpha: 0.90),
                ],
              ),
            ),
          ),
        ),

        // 4. Active Segment Scene Badge (if segment has a title e.g. "مشهد 1: وصول البطل")
        if (hasActiveVideo &&
            _activeSegment?.title != null &&
            _activeSegment!.title!.trim().isNotEmpty)
          Positioned(
            top: 12.h,
            right: 14.w,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: 0.85,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.videocam_rounded,
                      size: 13.sp,
                      color: const Color(0xFFEF4444),
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      _activeSegment!.title!,
                      style: TextStyle(
                        fontFamily: 'IBM',
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
