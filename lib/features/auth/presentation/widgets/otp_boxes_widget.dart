import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class OtpBoxesWidget extends StatelessWidget {
  final String code;
  final int length;
  final bool hasError;

  const OtpBoxesWidget({
    super.key,
    required this.code,
    this.length = 6,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(length, (index) {
          final isFilled = index < code.length;
          final isCurrent = index == code.length;
          final digit = isFilled ? code[index] : '';

          return Container(
            width: 46.w,
            height: 54.h,
            margin: EdgeInsets.symmetric(horizontal: 4.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: hasError
                    ? const Color(0xFFEF4444)
                    : isCurrent
                    ? const Color(0xFF7C3AED)
                    : isFilled
                    ? const Color(0xFFA78BFA)
                    : const Color(0xFFE5E7EB),
                width: isCurrent || hasError ? 2.0 : 1.2,
              ),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: isCurrent
                ? const _BlinkingCursor()
                : Text(
                    digit,
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E1B4B),
                      fontFamily: 'IBM',
                    ),
                  ),
          );
        }),
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2.w,
        height: 24.h,
        color: const Color(0xFF7C3AED),
      ),
    );
  }
}
