import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../domain/entities/podcast_entity.dart';

class PodcastVideoBackdrop extends StatefulWidget {
  const PodcastVideoBackdrop({
    super.key,
    required this.currentSeconds,
    required this.isPlaying,
    required this.videoSegments,
    required this.pageColor,
    this.fallbackCoverUrl,
  });

  final double currentSeconds;
  final bool isPlaying;
  final List<PodcastVideoSegment> videoSegments;
  final Color pageColor;
  final String? fallbackCoverUrl;

  @override
  State<PodcastVideoBackdrop> createState() => _PodcastVideoBackdropState();
}

class _PodcastVideoBackdropState extends State<PodcastVideoBackdrop> {
  PodcastVideoSegment? _activeSegment;
  VideoPlayerController? _controller;
  String? _loadedUrl;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _checkAndSyncVideo();
  }

  @override
  void didUpdateWidget(covariant PodcastVideoBackdrop oldWidget) {
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

  PodcastVideoSegment? _findSegmentAt(double seconds) {
    if (widget.videoSegments.isEmpty) return null;

    for (final seg in widget.videoSegments) {
      if (seg.isActiveAt(seconds)) return seg;
    }

    // If only one segment exists, keep it active as the podcast's main video
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
        await ctrl.setVolume(0.0); // Muted so podcast audio is primary
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
        debugPrint('[PodcastVideoBackdrop] Video initialization failed for $cleanUrl: $e\n$stack');
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

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Background Content: Either Video or Cover Artwork
        if (_controller != null && _isInitialized)
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
                opacity: isDark ? 0.45 : 0.28,
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
                  widget.pageColor.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // 3. Subtle Vertical Edge Gradients (Top & Bottom)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.12, 0.85, 1.0],
                colors: [
                  widget.pageColor.withValues(alpha: 0.85),
                  Colors.transparent,
                  Colors.transparent,
                  widget.pageColor,
                ],
              ),
            ),
          ),
        ),

        // 4. Video badge if active
        if (_activeSegment != null && _activeSegment!.title != null && _activeSegment!.title!.isNotEmpty)
          Positioned(
            top: 14,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.videocam_rounded,
                    color: Color(0xFFEF4444),
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _activeSegment!.title!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'IBM',
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
