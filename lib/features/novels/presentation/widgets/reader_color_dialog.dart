import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

class ReaderColorDialog extends StatefulWidget {
  const ReaderColorDialog({
    super.key,
    required this.initial,
    this.contrastAgainst,
    this.contrastLabel = 'لون الصفحة',
    this.minContrastRatio = 3.2,
  });

  final Color initial;
  final Color? contrastAgainst;
  final String contrastLabel;
  final double minContrastRatio;

  @override
  State<ReaderColorDialog> createState() => _ReaderColorDialogState();
}

class _ReaderColorDialogState extends State<ReaderColorDialog> {
  late HSVColor _color = HSVColor.fromColor(widget.initial);

  static const _presets = [
    Color(0xfff8f1e3),
    Color(0xffffffff),
    Color(0xff17202a),
    Color(0xffe8f1f2),
    Color(0xfffff4b8),
    Color(0xffdbeafe),
  ];

  double _contrastRatio(Color a, Color b) {
    final l1 = a.computeLuminance();
    final l2 = b.computeLuminance();
    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  void _autoFixContrast() {
    if (widget.contrastAgainst == null) return;
    final bgLum = widget.contrastAgainst!.computeLuminance();
    // If background is light, pick a deep, rich dark shade of this hue.
    // If background is dark, pick a bright, luminous shade of this hue.
    setState(() {
      if (bgLum > 0.45) {
        _color = _color.withValue(0.18).withSaturation(math.min(_color.saturation, 0.75));
      } else {
        _color = _color.withValue(0.96).withSaturation(math.min(_color.saturation, 0.40));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = _color.toColor();
    final ratio = widget.contrastAgainst != null
        ? _contrastRatio(color, widget.contrastAgainst!)
        : null;
    final isConflicting = ratio != null && ratio < widget.minContrastRatio;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Text(
          'اختيار اللون',
          style: TextStyle(
            fontSize: 16.5.sp,
            fontWeight: FontWeight.w800,
            fontFamily: 'IBM',
            color: AppColors.textPrimary,
          ),
        ),
        content: SizedBox(
          width: 320.w,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48.w,
                      height: 48.w,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 8),
                        ],
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        _hexValue(color),
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.sp,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(
                        () => _color = HSVColor.fromColor(widget.initial),
                      ),
                      child: Text(
                        'إعادة',
                        style: TextStyle(fontFamily: 'IBM', fontSize: 12.sp),
                      ),
                    ),
                  ],
                ),

                // Live Contrast Guardrail & Preview
                if (widget.contrastAgainst != null) ...[
                  SizedBox(height: 12.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: widget.contrastAgainst,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: isConflicting ? AppColors.error : Colors.black12,
                        width: isConflicting ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'معاينة على ${widget.contrastLabel}:',
                              style: TextStyle(
                                fontFamily: 'IBM',
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: widget.contrastAgainst!.computeLuminance() > 0.45
                                    ? Colors.black54
                                    : Colors.white70,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: isConflicting
                                    ? AppColors.error.withValues(alpha: 0.15)
                                    : AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                isConflicting ? 'تعارض غير مقروء' : 'تباين ممتاز',
                                style: TextStyle(
                                  fontFamily: 'IBM',
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                  color: isConflicting ? AppColors.error : AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'The novel words will appear like this. هذا النص للتجربة.',
                          style: TextStyle(
                            color: color,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isConflicting) ...[
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '⚠️ هذا اللون قريب من ${widget.contrastLabel} وسيؤثر سلباً على وضوح القراءة.',
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 11.sp,
                              fontFamily: 'IBM',
                              height: 1.3,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        ElevatedButton.icon(
                          onPressed: _autoFixContrast,
                          icon: const Icon(Icons.auto_fix_high_rounded, size: 14),
                          label: Text(
                            'تصحيح ذكي',
                            style: TextStyle(fontFamily: 'IBM', fontSize: 11.sp),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],

                SizedBox(height: 16.h),
                Text(
                  'اختر درجة اللون ثم حدد التشبع والإضاءة:',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5.sp,
                    fontFamily: 'IBM',
                  ),
                ),
                SizedBox(height: 8.h),
                AspectRatio(
                  aspectRatio: 1.45,
                  child: Builder(
                    builder: (squareContext) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) {
                          final box =
                              squareContext.findRenderObject() as RenderBox?;
                          if (box != null && box.hasSize) {
                            _updateSquare(details.localPosition, box.size);
                          }
                        },
                        onPanUpdate: (details) {
                          final box =
                              squareContext.findRenderObject() as RenderBox?;
                          if (box != null && box.hasSize) {
                            _updateSquare(details.localPosition, box.size);
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12.r),
                          child: CustomPaint(
                            painter: _ColorSquarePainter(
                              hue: _color.hue,
                              saturation: _color.saturation,
                              value: _color.value,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 12.h),
                Slider(
                  value: _color.hue,
                  min: 0,
                  max: 360,
                  onChanged: (value) =>
                      setState(() => _color = _color.withHue(value)),
                ),
                SizedBox(height: 10.h),
                Text(
                  'ألوان جاهزة:',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'IBM',
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 10.w,
                  runSpacing: 10.h,
                  children: [
                    for (final preset in _presets)
                      InkWell(
                        onTap: () =>
                            setState(() => _color = HSVColor.fromColor(preset)),
                        borderRadius: BorderRadius.circular(20.r),
                        child: Container(
                          width: 34.w,
                          height: 34.w,
                          decoration: BoxDecoration(
                            color: preset,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color.toARGB32() == preset.toARGB32()
                                  ? AppColors.primary
                                  : Colors.black12,
                              width: color.toARGB32() == preset.toARGB32()
                                  ? 3
                                  : 1,
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: TextStyle(fontFamily: 'IBM', fontSize: 13.sp),
            ),
          ),
          FilledButton(
            onPressed: isConflicting ? null : () => Navigator.pop(context, color),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            child: Text(
              isConflicting ? 'اللون متعارض' : 'حفظ اللون',
              style: TextStyle(
                fontFamily: 'IBM',
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateSquare(Offset point, Size size) {
    setState(
      () => _color = _color
          .withSaturation((point.dx / size.width).clamp(0, 1).toDouble())
          .withValue((1 - point.dy / size.height).clamp(0, 1).toDouble()),
    );
  }

  String _hexValue(Color color) =>
      '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
}

class _ColorSquarePainter extends CustomPainter {
  const _ColorSquarePainter({
    required this.hue,
    required this.saturation,
    required this.value,
  });

  final double hue;
  final double saturation;
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()..color = HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Colors.white, Colors.transparent],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );

    final position = Offset(saturation * size.width, (1 - value) * size.height);
    canvas.drawCircle(
      position,
      8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      position,
      6,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _ColorSquarePainter oldDelegate) =>
      oldDelegate.hue != hue ||
      oldDelegate.saturation != saturation ||
      oldDelegate.value != value;
}
