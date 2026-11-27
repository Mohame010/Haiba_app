import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CustomKeypadWidget extends StatelessWidget {
  final ValueChanged<String> onDigitPressed;
  final VoidCallback onBackspacePressed;

  const CustomKeypadWidget({
    super.key,
    required this.onDigitPressed,
    required this.onBackspacePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFD1D5DB).withValues(alpha: 0.35),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _KeypadButton(
                number: '1',
                letters: '',
                onTap: () => onDigitPressed('1'),
              ),
              SizedBox(width: 8.w),
              _KeypadButton(
                number: '2',
                letters: 'ABC',
                onTap: () => onDigitPressed('2'),
              ),
              SizedBox(width: 8.w),
              _KeypadButton(
                number: '3',
                letters: 'DEF',
                onTap: () => onDigitPressed('3'),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              _KeypadButton(
                number: '4',
                letters: 'GHI',
                onTap: () => onDigitPressed('4'),
              ),
              SizedBox(width: 8.w),
              _KeypadButton(
                number: '5',
                letters: 'JKL',
                onTap: () => onDigitPressed('5'),
              ),
              SizedBox(width: 8.w),
              _KeypadButton(
                number: '6',
                letters: 'MNO',
                onTap: () => onDigitPressed('6'),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              _KeypadButton(
                number: '7',
                letters: 'PQRS',
                onTap: () => onDigitPressed('7'),
              ),
              SizedBox(width: 8.w),
              _KeypadButton(
                number: '8',
                letters: 'TUV',
                onTap: () => onDigitPressed('8'),
              ),
              SizedBox(width: 8.w),
              _KeypadButton(
                number: '9',
                letters: 'WXYZ',
                onTap: () => onDigitPressed('9'),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              const Expanded(child: SizedBox()),
              SizedBox(width: 8.w),
              _KeypadButton(
                number: '0',
                letters: '',
                onTap: () => onDigitPressed('0'),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onBackspacePressed();
                    },
                    borderRadius: BorderRadius.circular(10.r),
                    child: Container(
                      height: 52.h,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.backspace_outlined,
                        color: Color(0xFF1E1B4B),
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String number;
  final String letters;
  final VoidCallback onTap;

  const _KeypadButton({
    required this.number,
    required this.letters,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        elevation: 0.5,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(10.r),
          child: Container(
            height: 52.h,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  number,
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E1B4B),
                    height: 1.1,
                    fontFamily: 'IBM',
                  ),
                ),
                if (letters.isNotEmpty)
                  Text(
                    letters,
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B7280),
                      letterSpacing: 1.2,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
