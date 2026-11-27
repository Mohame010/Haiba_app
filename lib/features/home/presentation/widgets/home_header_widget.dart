import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_helper.dart';

class HomeHeaderWidget extends StatelessWidget {
  final String studentName;
  final String grade;
  final String? assessmentLevel;
  final int points;
  final int unreadNotificationsCount;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onPointsTap;
  final VoidCallback? onLevelTap;

  const HomeHeaderWidget({
    super.key,
    required this.studentName,
    required this.grade,
    this.assessmentLevel,
    this.points = 0,
    this.unreadNotificationsCount = 0,
    this.onNotificationTap,
    this.onPointsTap,
    this.onLevelTap,
  });

  @override
  Widget build(BuildContext context) {
    final greeting = DateTimeHelper.getEgyptGreeting();
    final firstName = studentName.trim().isNotEmpty
        ? studentName.trim().split(RegExp(r'\s+')).first
        : studentName;
    final formattedPoints = NumberFormat('#,###').format(points);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Student Greeting & Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$greeting، ',
                          style: TextStyle(
                            fontSize: 15.5.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            fontFamily: 'IBM',
                            height: 1.35,
                          ),
                        ),
                        TextSpan(
                          text: firstName,
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            fontFamily: 'IBM',
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6.h),
                  // Integrated Level Display in AppBar / Header
                  _buildLevelRow(),
                ],
              ),
            ),
            SizedBox(width: 8.w),

            // Points Badge (Min 48x48 tap target)
            // Semantics(
            //   button: true,
            //   label: 'رصيد النقاط $formattedPoints نقطة',
            //   child: Material(
            //     color: Colors.transparent,
            //     child: InkWell(
            //       onTap: onPointsTap,
            //       borderRadius: BorderRadius.circular(20.r),
            //       child: Container(
            //         constraints: BoxConstraints(minHeight: 40.h),
            //         padding: EdgeInsets.symmetric(
            //           horizontal: 10.w,
            //           vertical: 6.h,
            //         ),
            //         decoration: BoxDecoration(
            //           gradient: const LinearGradient(
            //             begin: Alignment.topLeft,
            //             end: Alignment.bottomRight,
            //             colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
            //           ),
            //           borderRadius: BorderRadius.circular(20.r),
            //           border: Border.all(
            //             color: const Color(0xFFFDE68A),
            //             width: 1.2,
            //           ),
            //           boxShadow: [
            //             BoxShadow(
            //               color: const Color(0xFFF59E0B).withAlpha(25),
            //               blurRadius: 8,
            //               offset: const Offset(0, 2),
            //             ),
            //           ],
            //         ),
            //         child: Row(
            //           mainAxisSize: MainAxisSize.min,
            //           children: [
            //             Container(
            //               padding: EdgeInsets.all(3.w),
            //               decoration: const BoxDecoration(
            //                 shape: BoxShape.circle,
            //                 gradient: LinearGradient(
            //                   begin: Alignment.topLeft,
            //                   end: Alignment.bottomRight,
            //                   colors: [Color(0xFFFDE047), Color(0xFFF59E0B)],
            //                 ),
            //               ),
            //               child: Icon(
            //                 Icons.star_rounded,
            //                 color: Colors.white,
            //                 size: 13.sp,
            //               ),
            //             ),
            //             SizedBox(width: 4.w),
            //             Text(
            //               formattedPoints,
            //               style: TextStyle(
            //                 fontSize: 12.5.sp,
            //                 fontWeight: FontWeight.w800,
            //                 color: const Color(0xFF92400E),
            //                 fontFamily: 'IBM',
            //               ),
            //             ),
            //           ],
            //         ),
            //       ),
            //     ),
            //   ),
            // ),
            SizedBox(width: 10.w),

            // Notification Bell with touch target >= 48x48
            Semantics(
              button: true,
              label:
                  'الإشعارات${unreadNotificationsCount > 0 ? "، لديك $unreadNotificationsCount إشعار غير مقروء" : ""}',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onNotificationTap,
                  borderRadius: BorderRadius.circular(24.r),
                  child: Container(
                    width: 44.w,
                    height: 44.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.border.withAlpha(100),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(8),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: SvgPicture.asset(
                            'assets/svgs/notification.svg',
                            color: AppColors.secondary,
                            width: 20.w,
                            height: 20.w,
                          ),
                        ),
                        if (unreadNotificationsCount > 0)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4.w,
                                vertical: 1.h,
                              ),
                              decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                              constraints: BoxConstraints(
                                minWidth: 16.w,
                                minHeight: 16.w,
                              ),
                              child: Center(
                                child: Text(
                                  unreadNotificationsCount > 99
                                      ? '+99'
                                      : '$unreadNotificationsCount',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'IBM',
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLevelRow() {
    return Row(
      spacing: 6.w,
      // runSpacing: 4.h,
      // crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Primary Grade / Stage Badge
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(16),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: AppColors.primary.withAlpha(35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.school_rounded,
                  size: 13.sp,
                  color: AppColors.primary,
                ),
                SizedBox(width: 4.w),
                Text(
                  grade,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    fontFamily: 'IBM',
                  ),
                ),
              ],
            ),
          ),
        ),

        // Assessment Level Badge (Interactive)
        if (onLevelTap != null)
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onLevelTap,
                borderRadius: BorderRadius.circular(8.r),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: assessmentLevel != null
                        ? const Color(0xFFF3E8FF)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: assessmentLevel != null
                          ? const Color(0xFFD8B4FE)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        assessmentLevel != null
                            ? Icons.workspace_premium_rounded
                            : Icons.psychology_alt_rounded,
                        size: 13.sp,
                        color: assessmentLevel != null
                            ? const Color(0xFF7E22CE)
                            : const Color(0xFF475569),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        assessmentLevel != null
                            ? 'المستوى: $assessmentLevel'
                            : 'تحديد المستوى',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: assessmentLevel != null
                              ? const Color(0xFF6B21A8)
                              : const Color(0xFF334155),
                          fontFamily: 'IBM',
                        ),
                      ),
                      SizedBox(width: 2.w),
                      Icon(
                        Icons.chevron_left_rounded,
                        size: 14.sp,
                        color: assessmentLevel != null
                            ? const Color(0xFF7E22CE)
                            : const Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
