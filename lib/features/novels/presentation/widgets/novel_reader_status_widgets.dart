import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';

class NovelReaderLoadingView extends StatelessWidget {
  const NovelReaderLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'جارٍ تحميل الرواية...',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            fontFamily: 'IBM',
          ),
        ),
      ),
      body: SafeArea(
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Chapters bar shimmer
                Row(
                  children: List.generate(
                    4,
                    (_) => Padding(
                      padding: EdgeInsetsDirectional.only(end: 8.w),
                      child: Container(
                        width: 80.w,
                        height: 36.h,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
                // Reader text lines shimmer
                ...List.generate(
                  8,
                  (index) => Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: Container(
                      height: 18.h,
                      width: index % 3 == 2 ? 220.w : double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                // Player panel shimmer
                Container(
                  height: 64.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
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

class NovelReaderSubscriptionView extends StatelessWidget {
  const NovelReaderSubscriptionView({super.key, required this.onShowPaywall});

  final VoidCallback onShowPaywall;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(28.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72.w,
                  height: 72.w,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withAlpha(35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    size: 34,
                    color: Color(0xFFD97706),
                  ),
                ),
                SizedBox(height: 18.h),
                Text(
                  'هذه الرواية ضمن مكتبة المشتركين',
                  style: TextStyle(
                    fontSize: 16.5.sp,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'IBM',
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8.h),
                Text(
                  'اشترك الآن للوصول الكامل إلى جميع فصول الروايات والاستماع الصوتي غير المحدود.',
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    color: AppColors.textSecondary,
                    fontFamily: 'IBM',
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20.h),
                FilledButton.icon(
                  onPressed: onShowPaywall,
                  icon: const Icon(Icons.workspace_premium_rounded),
                  label: const Text(
                    'عرض باقات الاشتراك',
                    style: TextStyle(fontFamily: 'IBM', fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: Size(180.w, 48.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
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

class NovelReaderUnavailableView extends StatelessWidget {
  const NovelReaderUnavailableView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(28.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64.w,
                  height: 64.w,
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 30.sp,
                    color: AppColors.error,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  error == null ? 'الرواية غير متاحة حاليًا' : 'تعذر تحميل الرواية',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'IBM',
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8.h),
                Text(
                  'يرجى التأكد من اتصالك بالإنترنت ثم إعادة المحاولة.',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                    fontFamily: 'IBM',
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 18.h),
                FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: const Text(
                    'إعادة المحاولة',
                    style: TextStyle(fontFamily: 'IBM', fontWeight: FontWeight.w700),
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
