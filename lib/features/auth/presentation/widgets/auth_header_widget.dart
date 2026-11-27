import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AuthHeaderWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget illustration;
  final VoidCallback? onBack;

  const AuthHeaderWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.illustration,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // if (onBack != null)
        //   Align(
        //     alignment: Alignment.topRight,
        //     child: IconButton(
        //       onPressed: onBack,
        //       icon: const Icon(
        //         Icons.arrow_back_ios_new,
        //         color: Color(0xFF1E1B4B),
        //         size: 20,
        //       ),
        //       padding: EdgeInsets.zero,
        //       constraints: const BoxConstraints(),
        //     ),
        //   ),
        SizedBox(height: 8.h),
        illustration,
        SizedBox(height: 16.h),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E1B4B),
            fontFamily: 'IBM',
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.sp,
            color: const Color(0xFF6B7280),
            fontFamily: 'IBM',
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
