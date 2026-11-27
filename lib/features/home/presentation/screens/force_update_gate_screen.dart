import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_images.dart';
import '../../../core/theme/app_colors.dart';
import '../../data/models/app_gate_config.dart';
import '../../data/services/app_gate_service.dart';

class ForceUpdateGateScreen extends StatelessWidget {
  const ForceUpdateGateScreen({super.key, required this.config});

  final AppGateConfig config;

  Future<void> _openStore(BuildContext context, String url) async {
    var opened = false;
    try {
      final uri = Uri.tryParse(url);
      opened =
          uri != null &&
          await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذّر فتح المتجر. تأكد من اتصالك بالإنترنت وحاول مجدداً.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = config.updateFor(AppGateService.currentPlatform);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.sizeOf(context).height - 112.h,
              ),
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
                          AppColors.primary.withValues(alpha: .18),
                          AppColors.primaryDark.withValues(alpha: .07),
                        ],
                      ),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: .22),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.rocket_launch_rounded,
                      size: 58.w,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 28.h),
                  Text(
                    'تحديث جديد جاهز لك',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 25.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'حدّث تطبيق هيبة الآن لتكمل استخدام المنصة بأفضل أداء وأحدث المميزات.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15.sp,
                      height: 1.7,
                    ),
                  ),
                  SizedBox(height: 18.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 18.w,
                      vertical: 11.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Text(
                      'الإصدار المطلوب: ${update?.minimumVersion ?? '-'}',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: 34.h),
                  SizedBox(
                    width: double.infinity,
                    height: 54.h,
                    child: FilledButton.icon(
                      onPressed: update?.storeUrl.isNotEmpty == true
                          ? () => _openStore(context, update!.storeUrl)
                          : null,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('تحديث الآن'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        textStyle: TextStyle(
                          fontFamily: 'IBM',
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'التحديث مطلوب للاستمرار في استخدام التطبيق',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
