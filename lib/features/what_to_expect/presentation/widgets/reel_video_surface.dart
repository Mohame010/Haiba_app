import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../domain/entities/reel_entity.dart';
import '../utils/youtube_video_id.dart';

const _youtubeAppOrigin = 'https://com.qimma.education';

class ReelVideoSurface extends StatefulWidget {
  final ReelEntity reel;
  final bool isActive;
  final bool shouldPrepare;

  const ReelVideoSurface({
    super.key,
    required this.reel,
    required this.isActive,
    required this.shouldPrepare,
  });

  @override
  State<ReelVideoSurface> createState() => _ReelVideoSurfaceState();
}

class _ReelVideoSurfaceState extends State<ReelVideoSurface> {
  VideoPlayerController? _videoController;
  WebViewController? _youtubeController;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isPlaying = true;
  double _zoomScale = 1;
  int _generation = 0;

  String? get _youtubeId => youtubeVideoId(widget.reel.videoUrl);

  @override
  void initState() {
    super.initState();
    if (widget.shouldPrepare) unawaited(_prepare());
  }

  @override
  void didUpdateWidget(covariant ReelVideoSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reel.videoUrl != widget.reel.videoUrl) {
      _release();
      if (widget.shouldPrepare) unawaited(_prepare());
      return;
    }
    if (!oldWidget.shouldPrepare && widget.shouldPrepare) {
      unawaited(_prepare());
    } else if (oldWidget.shouldPrepare && !widget.shouldPrepare) {
      _release();
    } else if (oldWidget.isActive != widget.isActive) {
      unawaited(_syncPlayback());
    }
  }

  Future<void> _prepare() async {
    if (_videoController != null || _youtubeController != null) {
      await _syncPlayback();
      return;
    }
    final generation = ++_generation;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }
    final youtubeId = _youtubeId;
    if (youtubeId != null) {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (!mounted || generation != _generation) return;
              setState(() => _isLoading = false);
              unawaited(_syncPlayback());
            },
            onWebResourceError: (error) {
              if (!mounted ||
                  generation != _generation ||
                  error.isForMainFrame == false) {
                return;
              }
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            },
          ),
        );
      _youtubeController = controller;
      // A base URL is required for YouTube embeds inside a WebView. Without
      // it the document has an opaque/local origin, so YouTube receives no
      // Referer (or equivalent app identity) and rejects playback with 153.
      await controller.loadHtmlString(
        _youtubeHtml(youtubeId),
        baseUrl: '$_youtubeAppOrigin/',
      );
      return;
    }

    final uri = Uri.tryParse(widget.reel.videoUrl);
    if (uri == null || !uri.hasScheme) {
      _setError(generation);
      return;
    }
    final controller = VideoPlayerController.networkUrl(
      uri,
      httpHeaders: const {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Mobile)',
      },
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    _videoController = controller;
    try {
      await controller.initialize().timeout(const Duration(seconds: 30));
      if (!mounted || generation != _generation) return;
      setState(() {
        _isLoading = false;
        _hasError = false;
        _isPlaying = widget.isActive;
      });
      try {
        await controller.setLooping(true);
        if (widget.isActive) await controller.play();
      } catch (error, stackTrace) {
        // The media is already initialized and can still be controlled by the
        // user. Do not replace a valid frame with a generic loading error just
        // because autoplay or looping was rejected temporarily by the device.
        debugPrint('Reel autoplay failed: $error\n$stackTrace');
      }
    } catch (error, stackTrace) {
      debugPrint('Reel initialization failed: $error\n$stackTrace');
      _setError(generation);
    }
  }

  Future<void> _syncPlayback() async {
    final video = _videoController;
    if (video?.value.isInitialized == true) {
      if (widget.isActive && _isPlaying) {
        await video!.play();
      } else {
        await video!.pause();
      }
    }
    final youtube = _youtubeController;
    if (youtube != null) {
      final command = widget.isActive && _isPlaying
          ? 'playVideo'
          : 'pauseVideo';
      try {
        await youtube.runJavaScript('player.$command();');
      } catch (_) {}
    }
  }

  Future<void> _togglePlayback() async {
    if (_hasError) {
      _release();
      await _prepare();
      return;
    }
    setState(() => _isPlaying = !_isPlaying);
    if (_isPlaying && _youtubeController != null) {
      try {
        await _youtubeController!.runJavaScript('player.unMute();');
      } catch (_) {}
    }
    await _syncPlayback();
  }

  void _toggleZoom() {
    setState(() => _zoomScale = _zoomScale > 1 ? 1 : 1.5);
  }

  void _setError(int generation) {
    if (!mounted || generation != _generation) return;
    setState(() {
      _isLoading = false;
      _hasError = true;
    });
  }

  void _release() {
    _generation++;
    final video = _videoController;
    _videoController = null;
    unawaited(video?.dispose());
    _youtubeController = null;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _isPlaying = true;
        _zoomScale = 1;
      });
    }
  }

  @override
  void dispose() {
    _generation++;
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _videoController;
    return ColoredBox(
      color: Colors.black,
      child: ClipRect(
        child: Material(
          color: const Color(0xFF05070B),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _togglePlayback,
            onDoubleTap: _toggleZoom,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _ReelBackdrop(reel: widget.reel),
                AnimatedScale(
                  scale: _zoomScale,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (video?.value.isInitialized == true)
                        _CoverVideo(controller: video!),
                      if (_youtubeController case final youtube?)
                        IgnorePointer(
                          child: WebViewWidget(controller: youtube),
                        ),
                    ],
                  ),
                ),
                Center(
                  child: AnimatedOpacity(
                    opacity: !_isPlaying || _hasError ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Color(0x99000000),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _hasError
                            ? Icons.refresh_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 36,
                        semanticLabel: _hasError
                            ? 'إعادة المحاولة'
                            : 'تشغيل الفيديو',
                      ),
                    ),
                  ),
                ),
                // Positioned.directional(
                //   textDirection: Directionality.of(context),
                //   top: 8,
                //   end: 8,
                //   child: IconButton.filledTonal(
                //     onPressed: _toggleZoom,
                //     tooltip: _zoomScale > 1
                //         ? 'إظهار الفيديو كاملًا'
                //         : 'تكبير الفيديو',
                //     style: IconButton.styleFrom(
                //       backgroundColor: const Color(0x99000000),
                //       foregroundColor: Colors.white,
                //       minimumSize: const Size(48, 48),
                //     ),
                //     icon: Icon(
                //       _zoomScale > 1
                //           ? Icons.zoom_out_map_rounded
                //           : Icons.zoom_in_map_rounded,
                //     ),
                //   ),
                // ),
                if (_isLoading) const _LoadingOverlay(),
                if (_hasError)
                  const Positioned(
                    left: 24,
                    right: 24,
                    bottom: 24,
                    child: Text(
                      'تعذر تشغيل الفيديو. اضغط للمحاولة مرة أخرى.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontFamily: 'IBM'),
                    ),
                  ),
                if (video?.value.isInitialized == true)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: video!,
                      builder: (context, value, _) {
                        final total = value.duration.inMilliseconds;
                        final progress = total <= 0
                            ? 0.0
                            : (value.position.inMilliseconds / total).clamp(
                                0.0,
                                1.0,
                              );
                        return LinearProgressIndicator(
                          value: progress,
                          minHeight: 2,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _youtubeHtml(String id) =>
      '''
<!doctype html>
<html>
<head>
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
  <meta name="referrer" content="strict-origin-when-cross-origin">
  <style>
    html,body,#player{margin:0;width:100%;height:100%;overflow:hidden;background:#000}
    iframe{display:block;width:100%;height:100%;border:0}
  </style>
</head>
<body>
  <div id="player"></div>
  <script src="https://www.youtube.com/iframe_api"></script>
  <script>
    var player;
    function onYouTubeIframeAPIReady() {
      player = new YT.Player('player', {
        videoId: '$id',
        playerVars: {
          autoplay: 1,
          controls: 0,
          disablekb: 1,
          fs: 0,
          playsinline: 1,
          rel: 0,
          loop: 1,
          playlist: '$id',
          enablejsapi: 1,
          origin: '$_youtubeAppOrigin',
          widget_referrer: '$_youtubeAppOrigin/'
        },
        events: {
          onReady: function(event) {
            event.target.mute();
            event.target.playVideo();
          }
        }
      });
    }
  </script>
</body>
</html>''';
}

class _CoverVideo extends StatelessWidget {
  final VideoPlayerController controller;

  const _CoverVideo({required this.controller});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = controller.value.size;
      return FittedBox(
        // Reels fill the whole viewport. A 9:16 video on a taller phone is
        // cropped slightly at the sides instead of being letterboxed.
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: size.width - 100,
          height: size.height - 140,
          child: VideoPlayer(controller),
        ),
      );
    },
  );
}

class _ReelBackdrop extends StatelessWidget {
  final ReelEntity reel;

  const _ReelBackdrop({required this.reel});

  @override
  Widget build(BuildContext context) {
    final youtubeId = youtubeVideoId(reel.videoUrl);
    final imageUrl = reel.thumbnailUrl?.trim().isNotEmpty == true
        ? reel.thumbnailUrl!
        : youtubeId == null
        ? null
        : 'https://i.ytimg.com/vi/$youtubeId/hqdefault.jpg';
    if (imageUrl == null) return const ColoredBox(color: Color(0xFF111827));
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      cacheWidth: 1080,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF111827)),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x221E40AF), Color(0x22000000), Color(0x224338CA)],
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: 48,
          height: 4,
          child: LinearProgressIndicator(
            color: Colors.white,
            backgroundColor: Colors.white24,
          ),
        ),
      ),
    ),
  );
}
