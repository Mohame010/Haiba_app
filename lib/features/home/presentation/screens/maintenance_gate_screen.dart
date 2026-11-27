import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constants/app_images.dart';
import '../../../core/theme/app_colors.dart';
import '../../data/models/app_gate_config.dart';

class MaintenanceGateScreen extends StatelessWidget {
  const MaintenanceGateScreen({
    super.key,
    required this.config,
    required this.onRetry,
    required this.isRetrying,
  });

  final AppGateConfig config;
  final Future<void> Function() onRetry;
  final bool isRetrying;

  @override
  Widget build(BuildContext context) {
    final maintenance = config.maintenance;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(AppImages.appLogo, width: 150.w),
                SizedBox(height: 34.h),
                Container(
                  width: 122.w,
                  height: 122.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.warning.withValues(alpha: .20),
                        AppColors.primary.withValues(alpha: .07),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: .28),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.construction_rounded,
                    size: 58.w,
                    color: AppColors.warning,
                  ),
                ),
                SizedBox(height: 28.h),
                Text(
                  'نطوّر التجربة من أجلك',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 25.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  maintenance.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15.sp,
                    height: 1.7,
                  ),
                ),
                if (maintenance.expectedTime.isNotEmpty) ...[
                  SizedBox(height: 18.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 19.w,
                          color: AppColors.warning,
                        ),
                        SizedBox(width: 7.w),
                        Flexible(
                          child: Text(
                            'العودة المتوقعة: ${maintenance.expectedTime}',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 34.h),
                SizedBox(
                  width: double.infinity,
                  height: 54.h,
                  child: FilledButton.icon(
                    onPressed: isRetrying ? null : onRetry,
                    icon: isRetrying
                        ? SizedBox.square(
                            dimension: 19.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.3,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(
                      isRetrying ? 'جارٍ التحقق...' : 'إعادة المحاولة',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      textStyle: TextStyle(
                        fontFamily: 'IBM',
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
