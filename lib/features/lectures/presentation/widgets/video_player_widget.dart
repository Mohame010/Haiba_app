import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_helper.dart';
import '../../domain/entities/lecture_content_entity.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String title;
  final List<VideoNoteEntity> notes;
  final Future<String?> Function(int timestampSeconds, String noteText)?
  onAddNote;
  final VideoPlayerWidgetController? playerController;
  final VoidCallback? onDownload;
  final bool isDownloaded;
  final double? downloadProgress;
  final int initialPositionSeconds;
  final void Function(int positionSeconds, int durationSeconds)?
  onProgressChanged;
  final String? nextVideoTitle;
  final VoidCallback? onPlayNext;
  final VoidCallback? onDeleteDownload;
  final bool autoplay;
  final bool adaptiveAspectRatio;
  final bool portraitFullscreen;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    required this.title,
    this.notes = const [],
    this.onAddNote,
    this.playerController,
    this.onDownload,
    this.isDownloaded = false,
    this.downloadProgress,
    this.initialPositionSeconds = 0,
    this.onProgressChanged,
    this.nextVideoTitle,
    this.onPlayNext,
    this.onDeleteDownload,
    this.autoplay = false,
    this.adaptiveAspectRatio = false,
    this.portraitFullscreen = false,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

/// Allows the lecture screen to keep the same video playing in a floating
/// in-app window while another lesson resource is open.
class VideoPlayerWidgetController {
  _VideoPlayerWidgetState? _state;

  bool get isReady => _state?._isInitialized ?? false;

  void enterPictureInPicture() => _state?._enterPictureInPicture();

  void exitPictureInPicture() => _state?._exitPictureInPicture();

  void _attach(_VideoPlayerWidgetState state) => _state = state;

  void _detach(_VideoPlayerWidgetState state) {
    if (identical(_state, state)) _state = null;
  }
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  final TransformationController _fullscreenTransformationController =
      TransformationController();
  final ValueNotifier<int> _fullscreenRevision = ValueNotifier<int>(0);
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isLoadingTakingLonger = false;
  bool _showControls = true;
  Timer? _controlsTimer;
  Timer? _loadingFeedbackTimer;
  double _playbackSpeed = 1.0;
  bool _isFullscreen = false;
  bool _isRecovering = false;
  bool _isPictureInPicture = false;
  bool _pipShowControls = true;
  Timer? _pipControlsTimer;
  bool _wasPlayingBeforeError = false;
  bool _wasPlayingOnPreviousUpdate = false;
  int _controllerGeneration = 0;
  int _recoveryAttempts = 0;
  int _lastReportedSecond = -5;
  Timer? _recoveryResetTimer;
  Timer? _playbackRefreshTimer;
  Timer? _nextVideoTimer;
  int _nextVideoCountdown = 0;
  bool _completionHandled = false;
  OverlayEntry? _pictureInPictureEntry;
  Offset? _pictureInPictureOffset;
  Size? _pictureInPictureSize;
  BuildContext? _fullscreenContext;
  static const List<double> _speedOptions = [0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    widget.playerController?._attach(this);
    _initPlayer(
      widget.videoUrl,
      resumeAt: Duration(seconds: widget.initialPositionSeconds),
      autoplay: widget.autoplay,
    );
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playerController != widget.playerController) {
      oldWidget.playerController?._detach(this);
      widget.playerController?._attach(this);
    }
    if (oldWidget.videoUrl != widget.videoUrl) {
      _lastReportedSecond = -5;
      _completionHandled = false;
      _nextVideoTimer?.cancel();
      _nextVideoCountdown = 0;
      _initPlayer(
        widget.videoUrl,
        resumeAt: Duration(seconds: widget.initialPositionSeconds),
        autoplay: widget.autoplay,
      );
    } else if (oldWidget.initialPositionSeconds !=
            widget.initialPositionSeconds &&
        widget.initialPositionSeconds > 0 &&
        _isInitialized) {
      _controller?.seekTo(Duration(seconds: widget.initialPositionSeconds));
    }
  }

  void _disposeCurrentController() {
    _controllerGeneration++;
    _loadingFeedbackTimer?.cancel();
    _loadingFeedbackTimer = null;
    _isLoadingTakingLonger = false;
    _controlsTimer?.cancel();
    _playbackRefreshTimer?.cancel();
    _playbackRefreshTimer = null;
    _wasPlayingOnPreviousUpdate = false;
    final controller = _controller;
    controller?.removeListener(_onControllerUpdate);
    if (controller != null) unawaited(controller.dispose());
    _controller = null;
  }

  void _scheduleLoadingFeedback(int generation) {
    _loadingFeedbackTimer?.cancel();
    _loadingFeedbackTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted ||
          generation != _controllerGeneration ||
          _isInitialized ||
          _hasError) {
        return;
      }
      setState(() => _isLoadingTakingLonger = true);
    });
  }

  void _stopLoadingFeedback() {
    _loadingFeedbackTimer?.cancel();
    _loadingFeedbackTimer = null;
  }

  void _onControllerUpdate() {
    final value = _controller?.value;
    if (value?.hasError ?? false) {
      unawaited(_recoverFromPlaybackError(value?.errorDescription));
    } else if (value != null) {
      final wasPlaying = _wasPlayingOnPreviousUpdate;
      _wasPlayingOnPreviousUpdate = value.isPlaying;
      _wasPlayingBeforeError = value.isPlaying;
      final second = value.position.inSeconds;
      if (second >= 0 &&
          (second - _lastReportedSecond).abs() >= 5 &&
          value.duration.inSeconds > 0) {
        _lastReportedSecond = second;
        widget.onProgressChanged?.call(second, value.duration.inSeconds);
      }
      final duration = value.duration;
      final remaining = duration - value.position;
      final stoppedAtTheEnd =
          duration > Duration.zero &&
          wasPlaying &&
          !value.isPlaying &&
          remaining <= const Duration(seconds: 2);
      final finished = value.isCompleted || stoppedAtTheEnd;
      if (finished && !_completionHandled) {
        _completionHandled = true;
        widget.onProgressChanged?.call(duration.inSeconds, duration.inSeconds);
        if (widget.onPlayNext != null && widget.nextVideoTitle != null) {
          _startNextVideoCountdown();
        }
      }
    }
    _schedulePlaybackRefresh();
  }

  void _schedulePlaybackRefresh() {
    if (_playbackRefreshTimer?.isActive ?? false) return;
    _playbackRefreshTimer = Timer(const Duration(milliseconds: 100), () {
      _playbackRefreshTimer = null;
      _refresh();
    });
  }

  void _startNextVideoCountdown() {
    _nextVideoTimer?.cancel();
    _nextVideoCountdown = 3;
    _refresh();
    _nextVideoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_nextVideoCountdown > 1) {
        _nextVideoCountdown--;
        _refresh();
        return;
      }
      timer.cancel();
      _nextVideoCountdown = 0;
      _playNextVideo();
    });
  }

  Future<void> _playNextVideo() async {
    if (_isFullscreen) {
      final fullscreenContext = _fullscreenContext;
      if (fullscreenContext != null &&
          Navigator.of(fullscreenContext).canPop()) {
        Navigator.of(fullscreenContext).pop();
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    if (mounted) widget.onPlayNext?.call();
  }

  void _refresh() {
    if (!mounted) return;
    if (_isFullscreen) {
      _fullscreenRevision.value++;
    } else {
      setState(() {});
    }
    _pictureInPictureEntry?.markNeedsBuild();
  }

  Future<bool> _initPlayer(
    String url, {
    Duration resumeAt = Duration.zero,
    bool autoplay = false,
    bool recovery = false,
  }) async {
    log("Playing lecture video url: $url");
    _disposeCurrentController();
    final generation = _controllerGeneration;

    if (mounted) {
      setState(() {
        _isInitialized = false;
        _hasError = false;
        _errorMessage = null;
        _isLoadingTakingLonger = false;
      });
    }

    final targetUrl = url.trim();
    if (targetUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'رابط الفيديو غير متوفر لهذا الدرس';
        });
      }
      return false;
    }

    final Uri? videoUri = Uri.tryParse(targetUrl);
    if (videoUri == null || !videoUri.hasScheme) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'رابط الفيديو غير صالح';
        });
      }
      return false;
    }

    VideoPlayerController? pendingController;
    try {
      final isLocal = videoUri.scheme == 'file';
      final controller = isLocal
          ? VideoPlayerController.file(File.fromUri(videoUri))
          : VideoPlayerController.networkUrl(
              videoUri,
              httpHeaders: const {
                'User-Agent':
                    'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
                'Accept': '*/*',
              },
            );

      pendingController = controller;
      _controller = controller;
      if (!isLocal) _scheduleLoadingFeedback(generation);

      await controller.initialize().timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw TimeoutException('مهلة الاتصال بالفيديو انتهت');
        },
      );

      if (!mounted ||
          generation != _controllerGeneration ||
          !identical(_controller, controller)) {
        return false;
      }

      controller.addListener(_onControllerUpdate);
      await controller.setPlaybackSpeed(_playbackSpeed);
      if (!mounted || generation != _controllerGeneration) return false;
      _stopLoadingFeedback();
      setState(() {
        _isInitialized = true;
        _hasError = false;
        _isLoadingTakingLonger = false;
      });
      if (resumeAt > Duration.zero) {
        final safePosition = resumeAt < controller.value.duration
            ? resumeAt
            : controller.value.duration;
        await controller.seekTo(safePosition);
      }
      if (!mounted || generation != _controllerGeneration) return false;
      if (autoplay && generation == _controllerGeneration) {
        await controller.play();
      }
      _startHideControlsTimer();
      if (!recovery) _recoveryAttempts = 0;
      return true;
    } catch (e) {
      if (!mounted || generation != _controllerGeneration) return false;
      _stopLoadingFeedback();
      final failedController = pendingController;
      if (identical(_controller, failedController)) _controller = null;
      if (failedController != null) {
        try {
          await failedController.dispose();
        } catch (_) {
          // The platform player may already be disposed after a failed init.
        }
      }
      if (!mounted || generation != _controllerGeneration) return false;
      log('Lecture video initialization failed', error: e);
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = false;
          _isLoadingTakingLonger = false;
          final errStr = e.toString();
          if (errStr.contains('403')) {
            _errorMessage = 'تعذر تشغيل الفيديو (خطأ 403 / الصلاحيات)';
          } else if (e is TimeoutException) {
            _errorMessage =
                'تعذر تجهيز الفيديو خلال 45 ثانية. تحقق من الشبكة أو أعد المحاولة.';
          } else {
            _errorMessage =
                'تعذر تشغيل الفيديو حاليًا. حاول مرة أخرى أو استخدم شبكة مختلفة.';
          }
        });
      }
      return false;
    }
  }

  Future<void> _recoverFromPlaybackError(String? description) async {
    if (_isRecovering || !mounted) return;
    _isRecovering = true;

    final resumeAt = _controller?.value.position ?? Duration.zero;
    final shouldResume = _wasPlayingBeforeError;
    log('Video playback failed at $resumeAt: $description');

    while (mounted && _recoveryAttempts < 3) {
      _recoveryAttempts++;
      setState(() {
        _isInitialized = false;
        _hasError = false;
        _errorMessage = null;
      });
      await Future<void>.delayed(Duration(seconds: _recoveryAttempts));
      if (!mounted) break;

      final recovered = await _initPlayer(
        widget.videoUrl,
        resumeAt: resumeAt,
        autoplay: shouldResume,
        recovery: true,
      );
      if (recovered) {
        _isRecovering = false;
        _recoveryResetTimer?.cancel();
        _recoveryResetTimer = Timer(const Duration(seconds: 20), () {
          _recoveryAttempts = 0;
        });
        return;
      }
    }

    _isRecovering = false;
    if (mounted) {
      setState(() {
        _hasError = true;
        _errorMessage =
            'انقطع الاتصال بالفيديو. اضغط إعادة المحاولة لاستكماله من نفس الموضع.';
      });
    }
  }

  Future<void> _retryManually() async {
    final resumeAt = _controller?.value.position ?? Duration.zero;
    _recoveryAttempts = 0;
    await _initPlayer(
      widget.videoUrl,
      resumeAt: resumeAt,
      autoplay: _wasPlayingBeforeError,
    );
  }

  void _startHideControlsTimer() {
    _controlsTimer?.cancel();
    if (_showControls &&
        _isInitialized &&
        (_controller?.value.isPlaying ?? false)) {
      _controlsTimer = Timer(const Duration(milliseconds: 3500), () {
        if (mounted && (_controller?.value.isPlaying ?? false)) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideControlsTimer();
    } else {
      _controlsTimer?.cancel();
    }
  }

  void _seekRelative(int seconds) {
    if (!_isInitialized || _controller == null) return;
    final current = _controller!.value.position;
    final target = current + Duration(seconds: seconds);
    final max = _controller!.value.duration;
    if (target < Duration.zero) {
      _controller!.seekTo(Duration.zero);
    } else if (target > max) {
      _controller!.seekTo(max);
    } else {
      _controller!.seekTo(target);
    }
    _startHideControlsTimer();
  }

  void _seekToSeconds(int seconds) {
    if (!_isInitialized || _controller == null) return;
    _controller!.seekTo(Duration(seconds: seconds));
    if (!_controller!.value.isPlaying) {
      _controller!.play();
    }
    _startHideControlsTimer();
  }

  Future<void> _setSpeed(double speed) async {
    _playbackSpeed = speed;
    if (_isInitialized && _controller != null) {
      await _controller!.setPlaybackSpeed(speed);
    }
    if (!mounted) return;
    _refresh();
    _startHideControlsTimer();
  }

  Future<void> _toggleFullscreen() async {
    if (_isFullscreen) {
      final fullscreenContext = _fullscreenContext;
      if (fullscreenContext != null &&
          Navigator.of(fullscreenContext).canPop()) {
        Navigator.of(fullscreenContext).pop();
      }
      return;
    }

    _exitPictureInPicture();
    _resetFullscreenZoom();
    _isFullscreen = true;
    await SystemChrome.setPreferredOrientations(
      widget.portraitFullscreen
          ? const [DeviceOrientation.portraitUp]
          : const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ],
    );
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (!mounted) return;

    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (routeContext, animation, secondaryAnimation) {
          _fullscreenContext = routeContext;
          return ValueListenableBuilder<int>(
            valueListenable: _fullscreenRevision,
            builder: (context, revision, child) => PopScope(
              canPop: true,
              child: Scaffold(
                backgroundColor: Colors.black,
                body: SizedBox.expand(child: _buildPlayer(fullscreen: true)),
              ),
            ),
          );
        },
        // Opacity transitions around VideoPlayer's external texture trigger
        // an Impeller inherited-opacity validation failure.
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            child,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );

    _fullscreenContext = null;
    if (!mounted) return;
    _isFullscreen = false;
    _resetFullscreenZoom();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    _refresh();
  }

  void _resetFullscreenZoom() {
    _fullscreenTransformationController.value = Matrix4.identity();
  }

  void _startPipControlsTimer() {
    _pipControlsTimer?.cancel();
    _pipControlsTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _isPictureInPicture) {
        _pipShowControls = false;
        _pictureInPictureEntry?.markNeedsBuild();
      }
    });
  }

  void _togglePipControls() {
    _pipShowControls = !_pipShowControls;
    if (_pipShowControls) {
      _startPipControlsTimer();
    } else {
      _pipControlsTimer?.cancel();
    }
    _pictureInPictureEntry?.markNeedsBuild();
  }

  void _enterPictureInPicture() {
    if (!mounted || !_isInitialized || _isFullscreen || _isPictureInPicture) {
      return;
    }
    _isPictureInPicture = true;
    _pipShowControls = true;
    _startPipControlsTimer();
    _pictureInPictureEntry = OverlayEntry(builder: _buildPictureInPicture);
    Overlay.of(context, rootOverlay: true).insert(_pictureInPictureEntry!);
    setState(() {});
  }

  void _exitPictureInPicture() {
    _pipControlsTimer?.cancel();
    _pipControlsTimer = null;
    _pictureInPictureEntry?.remove();
    _pictureInPictureEntry?.dispose();
    _pictureInPictureEntry = null;
    _fullscreenContext = null;
    _pictureInPictureOffset = null;
    _pictureInPictureSize = null;
    _isPictureInPicture = false;
    if (mounted) setState(() {});
  }

  Widget _buildPictureInPicture(BuildContext overlayContext) {
    final media = MediaQuery.of(overlayContext);
    final minWidth = media.size.width >= 600 ? 240.0 : 190.0;
    final maxWidth = (media.size.width - 16).clamp(
      minWidth,
      media.size.width >= 600 ? 560.0 : 360.0,
    );
    final defaultWidth = (media.size.width * .54).clamp(
      minWidth,
      media.size.width >= 600 ? 420.0 : 280.0,
    );
    final width = (_pictureInPictureSize?.width ?? defaultWidth).clamp(
      minWidth,
      maxWidth,
    );
    final height = width * 9 / 16;
    final padding = media.padding;
    final initial = Offset(media.size.width - width - 12, padding.top + 16);
    final offset = _pictureInPictureOffset ?? initial;

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      width: width,
      height: height,
      child: Material(
        elevation: 14,
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePipControls,
          onPanUpdate: (details) {
            final next = offset + details.delta;
            _pictureInPictureOffset = Offset(
              next.dx.clamp(8.0, media.size.width - width - 8),
              next.dy.clamp(
                padding.top + 8,
                media.size.height - height - padding.bottom - 8,
              ),
            );
            _pictureInPictureEntry?.markNeedsBuild();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_controller != null)
                Center(
                  child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              Center(
                child: IgnorePointer(
                  ignoring: !_pipShowControls,
                  child: AnimatedOpacity(
                    opacity: _pipShowControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        final controller = _controller;
                        if (controller == null) return;
                        controller.value.isPlaying
                            ? controller.pause()
                            : controller.play();
                        _startPipControlsTimer();
                        _refresh();
                        _pictureInPictureEntry?.markNeedsBuild();
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(160),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          (_controller?.value.isPlaying ?? false)
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IgnorePointer(
                  ignoring: !_pipShowControls,
                  child: AnimatedOpacity(
                    opacity: _pipShowControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _exitPictureInPicture,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 17,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                bottom: 0,
                child: IgnorePointer(
                  ignoring: !_pipShowControls,
                  child: AnimatedOpacity(
                    opacity: _pipShowControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (details) {
                        final availableHeight =
                            media.size.height - offset.dy - padding.bottom - 8;
                        final heightLimitedWidth = availableHeight * 16 / 9;
                        final resizeMaxWidth = maxWidth < heightLimitedWidth
                            ? maxWidth
                            : heightLimitedWidth;
                        final deltaWidth =
                            (-details.delta.dx + details.delta.dy * 16 / 9) / 2;
                        final nextWidth = (width + deltaWidth).clamp(
                          minWidth,
                          resizeMaxWidth < minWidth ? minWidth : resizeMaxWidth,
                        );
                        final rightEdge = offset.dx + width;
                        _pictureInPictureSize = Size(nextWidth, nextWidth * 9 / 16);
                        _pictureInPictureOffset = Offset(
                          (rightEdge - nextWidth).clamp(
                            8.0,
                            media.size.width - nextWidth - 8,
                          ),
                          offset.dy,
                        );
                        _pictureInPictureEntry?.markNeedsBuild();
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.bottomLeft,
                        padding: const EdgeInsets.all(7),
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: const Icon(
                          Icons.open_in_full_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.playerController?._detach(this);
    _pipControlsTimer?.cancel();
    _pipControlsTimer = null;
    _recoveryResetTimer?.cancel();
    _playbackRefreshTimer?.cancel();
    _nextVideoTimer?.cancel();
    _pictureInPictureEntry?.remove();
    _pictureInPictureEntry?.dispose();
    _pictureInPictureEntry = null;
    _disposeCurrentController();
    _fullscreenTransformationController.dispose();
    _fullscreenRevision.dispose();
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    super.dispose();
  }

  Future<void> _showAddNoteDialog() async {
    _controlsTimer?.cancel();
    final shouldResume = _controller?.value.isPlaying ?? false;
    if (shouldResume) await _controller?.pause();
    if (!mounted) return;
    final currentSeconds = _isInitialized && _controller != null
        ? _controller!.value.position.inSeconds
        : 0;
    final formattedTime = DateTimeHelper.formatSeconds(currentSeconds);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (sheetContext) {
        final size = MediaQuery.sizeOf(sheetContext);
        return Align(
          alignment: Alignment.bottomCenter,
          widthFactor: 1,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: size.height * .9,
            ),
            child: _AddVideoNoteSheet(
              formattedTime: formattedTime,
              onSave: (text) async {
                if (widget.onAddNote == null) return 'تعذر حفظ الملاحظة';
                return widget.onAddNote!(currentSeconds, text);
              },
            ),
          ),
        );
      },
    );

    if (mounted && saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ الملاحظة'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    if (mounted && shouldResume && _isInitialized) {
      await _controller?.play();
    }
    _startHideControlsTimer();
  }

  void _showNotesListModal() {
    _controlsTimer?.cancel();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        final sheetHeight = (size.height * .78).clamp(280.0, 620.0);
        return Align(
          alignment: Alignment.bottomCenter,
          widthFactor: 1,
          heightFactor: 1,
          child: SizedBox(
            width: size.width > 680 ? 680 : size.width,
            height: sheetHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'ملاحظاتي على الفيديو (${widget.notes.length})',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            fontFamily: 'IBM',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  if (widget.notes.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.speaker_notes_off_rounded,
                              size: 44.w,
                              color: AppColors.textMuted,
                            ),
                            SizedBox(height: 10.h),
                            Text(
                              'لا توجد ملاحظات مسجلة بعد.\nاضغط على أيقونة القلم لإضافة ملاحظة.',
                              style: TextStyle(
                                fontSize: 13.5.sp,
                                color: AppColors.textMuted,
                                fontFamily: 'IBM',
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: widget.notes.length,
                        separatorBuilder: (c, i) => const Divider(
                          color: AppColors.borderLight,
                          height: 1,
                        ),
                        itemBuilder: (c, i) {
                          final note = widget.notes[i];
                          final timeStr = DateTimeHelper.formatSeconds(
                            note.timestampSeconds,
                          );
                          return ListTile(
                            contentPadding: EdgeInsets.symmetric(vertical: 4.h),
                            leading: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(25),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                  fontFamily: 'IBM',
                                ),
                              ),
                            ),
                            title: Text(
                              note.noteText,
                              style: TextStyle(
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                fontFamily: 'IBM',
                              ),
                            ),
                            trailing: const Icon(
                              Icons.play_circle_fill_rounded,
                              color: AppColors.primary,
                            ),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _seekToSeconds(note.timestampSeconds);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      _startHideControlsTimer();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isPictureInPicture || _isFullscreen) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20.r),
          ),
          alignment: Alignment.center,
          child: Text(
            _isPictureInPicture
                ? 'الفيديو يعمل في النافذة المصغرة'
                : 'الفيديو يعمل بملء الشاشة',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12.sp,
              fontFamily: 'IBM',
            ),
          ),
        ),
      );
    }
    return _buildPlayer(fullscreen: false);
  }

  Widget _buildPlayer({required bool fullscreen}) {
    final sourceAspectRatio = _controller?.value.aspectRatio ?? 16 / 9;
    final aspectRatio = widget.adaptiveAspectRatio && _isInitialized
        ? sourceAspectRatio.clamp(.5, 2.4).toDouble()
        : 16 / 9;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(fullscreen ? 0 : 20.r),
        boxShadow: fullscreen
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(50),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: fullscreen
          ? _buildPlayerStack(fullscreen: true)
          : AspectRatio(
              aspectRatio: aspectRatio,
              child: _buildPlayerStack(fullscreen: false),
            ),
    );
  }

  Widget _buildPlayerStack({required bool fullscreen}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 1. Video Surface or Loading or Error
        if (_isInitialized && _controller != null)
          GestureDetector(
            onTap: _toggleControls,
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: fullscreen
                  ? _buildFullscreenVideo()
                  : AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
            ),
          )
        else if (_hasError)
          _buildErrorView()
        else
          _buildLoadingView(),

        // 2. Overlay Controls (Visible ONLY when Initialized AND NOT in Error state)
        if (_isInitialized && !_hasError)
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 260),
            child: IgnorePointer(
              ignoring: !_showControls,
              child: Stack(
                children: [
                  // Top & Bottom Gradient Shadows
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withAlpha(160),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withAlpha(180),
                            ],
                            stops: const [0.0, 0.28, 0.65, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Top Bar (Title + Speed + Notes)
                  Positioned(
                    top: fullscreen ? 14 : 8.h,
                    left: fullscreen ? 20 : 10.w,
                    right: fullscreen ? 20 : 10.w,
                    child: _buildTopBar(fullscreen),
                  ),

                  // Center Controls (Replay 10s, Big Play/Pause, Forward 10s)
                  Center(child: _buildCenterControls(fullscreen)),

                  // Bottom Bar (Timestamps + Slider + Fullscreen)
                  Positioned(
                    bottom: fullscreen ? 12 : 6.h,
                    left: fullscreen ? 20 : 12.w,
                    right: fullscreen ? 20 : 12.w,
                    child: _buildBottomBar(fullscreen),
                  ),
                ],
              ),
            ),
          ),
        if (_nextVideoCountdown > 0)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withAlpha(190),
              child: SafeArea(
                minimum: const EdgeInsets.all(12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'سيتم تشغيل الفيديو التالي تلقائيًا خلال',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: fullscreen ? 15 : 12.sp,
                            fontFamily: 'IBM',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$_nextVideoCountdown',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fullscreen ? 34 : 27.sp,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'IBM',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.nextVideoTitle ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fullscreen ? 16 : 13.sp,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'IBM',
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            _nextVideoTimer?.cancel();
                            _nextVideoCountdown = 0;
                            _playNextVideo();
                          },
                          child: const Text('تشغيل الآن'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFullscreenVideo() {
    if (!widget.portraitFullscreen) {
      return InteractiveViewer(
        transformationController: _fullscreenTransformationController,
        minScale: 1,
        maxScale: 4,
        panEnabled: true,
        scaleEnabled: true,
        boundaryMargin: const EdgeInsets.all(120),
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        final videoAspectRatio = _controller!.value.aspectRatio;
        final viewportAspectRatio = viewport.width / viewport.height;
        final coverSize = viewportAspectRatio > videoAspectRatio
            ? Size(viewport.width, viewport.width / videoAspectRatio)
            : Size(viewport.height * videoAspectRatio, viewport.height);

        return InteractiveViewer(
          transformationController: _fullscreenTransformationController,
          constrained: false,
          minScale: 1,
          maxScale: 4,
          panEnabled: true,
          scaleEnabled: true,
          boundaryMargin: const EdgeInsets.all(120),
          child: SizedBox(
            width: coverSize.width,
            height: coverSize.height,
            child: VideoPlayer(_controller!),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(bool fullscreen) {
    double size(double regular, double full) => fullscreen ? full : regular.sp;
    double width(double regular, double full) => fullscreen ? full : regular.w;
    return Row(
      children: [
        // Title
        Expanded(
          child: Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: size(14, 15),
              fontWeight: FontWeight.w800,
              fontFamily: 'IBM',
              shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
            ),
          ),
        ),
        SizedBox(width: width(8, 10)),

        // Playback Speed Selector Popup
        PopupMenuButton<double>(
          initialValue: _playbackSpeed,
          tooltip: 'سرعة التشغيل',
          onSelected: _setSpeed,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          color: const Color(0xFF1E293B),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: width(8, 9),
              vertical: fullscreen ? 5 : 4.h,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(35),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              '${_playbackSpeed}x',
              style: TextStyle(
                color: Colors.white,
                fontSize: size(11.5, 12),
                fontWeight: FontWeight.w700,
                fontFamily: 'IBM',
              ),
            ),
          ),
          itemBuilder: (ctx) => _speedOptions.map((speed) {
            final isSelected = speed == _playbackSpeed;
            return PopupMenuItem<double>(
              value: speed,
              height: 38.h,
              child: Text(
                '${speed}x',
                style: TextStyle(
                  color: isSelected ? const Color(0xFF818CF8) : Colors.white,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 13.sp,
                  fontFamily: 'IBM',
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(width: width(4, 6)),

        if (fullscreen)
          IconButton(
            icon: const Icon(
              Icons.zoom_out_map_rounded,
              color: Colors.white,
              size: 20,
            ),
            tooltip: 'إعادة ضبط التكبير',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: _resetFullscreenZoom,
          ),

        if (!fullscreen)
          IconButton(
            icon: const Icon(
              Icons.picture_in_picture_alt_rounded,
              color: Colors.white,
              size: 20,
            ),
            tooltip: 'نافذة مصغرة داخل التطبيق',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: _enterPictureInPicture,
          ),

        if (widget.onDownload != null)
          IconButton(
            icon: widget.downloadProgress != null
                ? SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      value: widget.downloadProgress,
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    widget.isDownloaded
                        ? Icons.delete_outline_rounded
                        : Icons.download_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
            tooltip: widget.isDownloaded
                ? 'حذف من التنزيلات'
                : 'تنزيل للمشاهدة بدون إنترنت',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: widget.downloadProgress == null
                ? (widget.isDownloaded
                      ? widget.onDeleteDownload
                      : widget.onDownload)
                : null,
          ),

        if (widget.onAddNote != null || widget.notes.isNotEmpty) ...[
          // Notes List Button with Badge
          IconButton(
            icon: Badge(
              isLabelVisible: widget.notes.isNotEmpty,
              label: Text('${widget.notes.length}'),
              backgroundColor: AppColors.primary,
              child: const Icon(
                Icons.sticky_note_2_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            tooltip: 'الملاحظات',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _showNotesListModal,
          ),
          SizedBox(width: width(8, 10)),

          // Add Note Button
          IconButton(
            icon: const Icon(
              Icons.add_comment_outlined,
              color: Colors.white,
              size: 20,
            ),
            tooltip: 'إضافة ملاحظة',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: widget.onAddNote == null ? null : _showAddNoteDialog,
          ),
        ],
      ],
    );
  }

  Widget _buildCenterControls(bool fullscreen) {
    final isPlaying = _controller?.value.isPlaying ?? false;
    double size(double regular, double full) => fullscreen ? full : regular.sp;
    double width(double regular, double full) => fullscreen ? full : regular.w;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 10s Replay Button
        GestureDetector(
          onTap: () => _seekRelative(-10),
          child: Container(
            width: width(40, 42),
            height: width(40, 42),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(90),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.replay_10_rounded,
              color: Colors.white,
              size: size(24, 25),
            ),
          ),
        ),
        SizedBox(width: width(24, 32)),

        // Main Play/Pause Button
        GestureDetector(
          onTap: () {
            if (_controller != null) {
              if (isPlaying) {
                _controller!.pause();
                _controlsTimer?.cancel();
              } else {
                _controller!.play();
                _startHideControlsTimer();
              }
              setState(() {});
            }
          },
          child: Container(
            width: width(56, 58),
            height: width(56, 58),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withAlpha(120),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: size(34, 35),
            ),
          ),
        ),
        SizedBox(width: width(24, 32)),

        // 10s Forward Button
        GestureDetector(
          onTap: () => _seekRelative(10),
          child: Container(
            width: width(40, 42),
            height: width(40, 42),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(90),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.forward_10_rounded,
              color: Colors.white,
              size: size(24, 25),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(bool fullscreen) {
    final position = _controller?.value.position ?? Duration.zero;
    final duration = _controller?.value.duration ?? Duration.zero;
    final totalSec = duration.inSeconds.toDouble();
    final curSec = position.inSeconds.toDouble().clamp(
      0.0,
      totalSec > 0 ? totalSec : 1.0,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Slider
        SizedBox(
          height: fullscreen ? 20 : 18.h,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: fullscreen ? 3 : 3.5.h,
              thumbShape: RoundSliderThumbShape(
                enabledThumbRadius: fullscreen ? 5 : 6.w,
              ),
              overlayShape: RoundSliderOverlayShape(
                overlayRadius: fullscreen ? 13 : 14.w,
              ),
              activeTrackColor: const Color(0xFF818CF8),
              inactiveTrackColor: Colors.white.withAlpha(60),
              thumbColor: Colors.white,
              overlayColor: const Color(0xFF818CF8).withAlpha(50),
            ),
            child: Slider(
              value: curSec,
              min: 0.0,
              max: totalSec > 0 ? totalSec : 1.0,
              onChanged: (val) {
                _controlsTimer?.cancel();
                _controller?.seekTo(Duration(seconds: val.toInt()));
              },
              onChangeEnd: (_) {
                _startHideControlsTimer();
              },
            ),
          ),
        ),

        // Duration & Fullscreen
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${DateTimeHelper.formatDuration(position)} / ${DateTimeHelper.formatDuration(duration)}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fullscreen ? 12 : 11.5.sp,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'IBM',
                ),
              ),
              GestureDetector(
                onTap: _toggleFullscreen,
                child: Icon(
                  _isFullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  color: Colors.white,
                  size: fullscreen ? 24 : 22.sp,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingView() {
    return Container(
      color: const Color(0xFF0F172A),
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 52.w,
                    height: 52.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.6,
                      color: Color(0xFF818CF8),
                      backgroundColor: Color(0x33475569),
                    ),
                  ),
                  Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 25.sp,
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  _isLoadingTakingLonger
                      ? 'الاتصال بمصدر الفيديو أبطأ من المعتاد'
                      : 'جاري تجهيز الفيديو...',
                  key: ValueKey(_isLoadingTakingLonger),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'IBM',
                  ),
                ),
              ),
              if (_isLoadingTakingLonger) ...[
                SizedBox(height: 5.h),
                Text(
                  'سنستمر في المحاولة تلقائيًا، لا حاجة لإعادة فتح الصفحة.',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 10.5.sp,
                    fontFamily: 'IBM',
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      color: const Color(0xFF0B1329),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      alignment: Alignment.center,
      child: Center(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 22.sp,
                  ),
                ),
              ),
              SizedBox(height: 6.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: Text(
                  _errorMessage ?? 'تعذر تشغيل الفيديو من هذا المصدر',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'IBM',
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(height: 10.h),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Retry Button
                  Material(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(10.r),
                    child: InkWell(
                      onTap: _retryManually,
                      borderRadius: BorderRadius.circular(10.r),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 6.h,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.refresh_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'إعادة المحاولة',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'IBM',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddVideoNoteSheet extends StatefulWidget {
  final String formattedTime;
  final Future<String?> Function(String text) onSave;

  const _AddVideoNoteSheet({required this.formattedTime, required this.onSave});

  @override
  State<_AddVideoNoteSheet> createState() => _AddVideoNoteSheetState();
}

class _AddVideoNoteSheetState extends State<_AddVideoNoteSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSaving) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    final error = await widget.onSave(text);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _isSaving = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'إضافة ملاحظة على الفيديو',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        fontFamily: 'IBM',
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      'عند ${widget.formattedTime}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontFamily: 'IBM',
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              TextField(
                controller: _controller,
                maxLines: 3,
                autofocus: true,
                enabled: !_isSaving,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                style: TextStyle(fontSize: 14.sp, fontFamily: 'IBM'),
                decoration: InputDecoration(
                  hintText: 'اكتب ملاحظتك التوضيحية عند هذه النقطة الزمنية...',
                  hintStyle: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.textMuted,
                    fontFamily: 'IBM',
                  ),
                  filled: true,
                  fillColor: AppColors.cardLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              if (_error != null) ...[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontFamily: 'IBM',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 13.h),
                ),
                child: _isSaving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'حفظ الملاحظة',
                        style: TextStyle(
                          fontSize: 14.5.sp,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'IBM',
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
