import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';

class PointsBannerWidget extends StatelessWidget {
  final int points;
  final VoidCallback? onBrowseRewards;

  const PointsBannerWidget({
    super.key,
    required this.points,
    this.onBrowseRewards,
  });

  @override
  Widget build(BuildContext context) {
    final formattedPoints = NumberFormat('#,###').format(points);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: BoxDecoration(
        gradient: AppColors.pointsGradient,
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withAlpha(60),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Points & Action Button
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'نقاطك',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withAlpha(200),
                  fontFamily: 'IBM',
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                formattedPoints,
                style: TextStyle(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                  fontFamily: 'IBM',
                ),
              ),
              SizedBox(height: 10.h),
              GestureDetector(
                onTap: onBrowseRewards,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(35),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: Colors.white.withAlpha(50),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'تصفح المكافآت',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'IBM',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Right: Glowing Golden Star Coin
          Container(
            width: 72.w,
            height: 72.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0xFFFDE047),
                  Color(0xFFF59E0B),
                  Color(0xFFD97706),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withAlpha(120),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.star_rounded,
                color: Colors.white,
                size: 44.w,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
