import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';

class PodcastWaveVisualizer extends StatefulWidget {
  const PodcastWaveVisualizer({
    super.key,
    required this.isPlaying,
    this.height = 48,
    this.waveColor = const Color(0xFF6366F1),
    this.secondaryColor = const Color(0xFFA855F7),
  });

  final bool isPlaying;
  final double height;
  final Color waveColor;
  final Color secondaryColor;

  @override
  State<PodcastWaveVisualizer> createState() => _PodcastWaveVisualizerState();
}

class _PodcastWaveVisualizerState extends State<PodcastWaveVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant PodcastWaveVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size(double.infinity, widget.height),
        painter: _AudioWavePainter(
          progress: _controller.value,
          isPlaying: widget.isPlaying,
          primaryColor: widget.waveColor,
          secondaryColor: widget.secondaryColor,
        ),
      ),
    );
  }
}

class _AudioWavePainter extends CustomPainter {
  _AudioWavePainter({
    required this.progress,
    required this.isPlaying,
    required this.primaryColor,
    required this.secondaryColor,
  });

  final double progress;
  final bool isPlaying;
  final Color primaryColor;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final width = size.width;
    const barCount = 38;
    final barSpacing = width / barCount;
    final barWidth = (barSpacing * 0.55).clamp(2.5, 6.0);

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    for (int i = 0; i < barCount; i++) {
      final x = i * barSpacing + (barSpacing / 2);
      final phase = (i / barCount) * 2 * math.pi;

      // Realistic audio frequency amplitude calculation
      double amplitude;
      if (isPlaying) {
        final sin1 = math.sin((progress * 2 * math.pi) + phase);
        final sin2 = math.cos((progress * 4 * math.pi) - (phase * 1.5));
        final envelope = math.sin((i / barCount) * math.pi); // tapered at ends
        amplitude = ((sin1 * 0.5 + sin2 * 0.5).abs() * 0.85 + 0.15) * envelope;
      } else {
        // Subtle resting wave
        final envelope = math.sin((i / barCount) * math.pi);
        amplitude = 0.18 * envelope;
      }

      final barHeight = (size.height * 0.82) * amplitude.clamp(0.08, 1.0);
      final top = midY - (barHeight / 2);
      final bottom = midY + (barHeight / 2);

      final barRatio = i / barCount;
      paint.color = Color.lerp(primaryColor, secondaryColor, barRatio)!
          .withValues(alpha: isPlaying ? 0.95 : 0.45);

      canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AudioWavePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.isPlaying != isPlaying ||
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.secondaryColor != secondaryColor;
}
