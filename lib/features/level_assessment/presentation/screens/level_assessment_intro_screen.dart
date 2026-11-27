import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';

class LevelAssessmentIntroScreen extends StatelessWidget {
  final bool firstLogin;

  const LevelAssessmentIntroScreen({super.key, this.firstLogin = false});

  void _close(BuildContext context) {
    if (firstLogin || !context.canPop()) {
      context.go(AppRoutes.main);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _close(context);
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF7F5FF),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(22.w, 18.h, 22.w, 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => _close(context),
                  child: const Text(
                    'تخطي الآن',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontFamily: 'IBM',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 190.w,
                      height: 190.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primary.withAlpha(45),
                            AppColors.primary.withAlpha(2),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 112.w,
                      height: 112.w,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [Color(0xFF4C1D95), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(34.r),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withAlpha(60),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.psychology_alt_rounded,
                        color: Colors.white,
                        size: 58.w,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 28.h),
              Text(
                'حدد مستواك دلوقتي',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 27.sp,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'IBM',
                  color: const Color(0xFF1E1B4B),
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'اعرف مستواك في النطق والقراءة والكتابة، وهنرشحلك الكورسات المناسبة ليك.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  height: 1.65,
                  fontFamily: 'IBM',
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 28.h),
              Row(
                children: const [
                  Expanded(
                    child: _FeaturePill(
                      icon: Icons.record_voice_over_rounded,
                      label: 'النطق',
                      color: Color(0xFFEC4899),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _FeaturePill(
                      icon: Icons.menu_book_rounded,
                      label: 'القراءة',
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _FeaturePill(
                      icon: Icons.edit_note_rounded,
                      label: 'الكتابة',
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: const Color(0xFFEDE9FE)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      color: AppColors.primary,
                      size: 19,
                    ),
                    SizedBox(width: 7.w),
                    Text(
                      '18 سؤال • حوالي 8 دقائق • النتيجة فورية',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'IBM',
                        color: const Color(0xFF5B21B6),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.push(AppRoutes.levelAssessment),
                style: FilledButton.styleFrom(
                  minimumSize: Size.fromHeight(56.h),
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                ),
                child: Text(
                  'ابدأ اختبار تحديد المستوى',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'IBM',
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              TextButton(
                onPressed: () => _close(context),
                child: const Text(
                  'هعمله بعدين',
                  style: TextStyle(
                    fontFamily: 'IBM',
                    fontWeight: FontWeight.w700,
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

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FeaturePill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 23),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: 'IBM',
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
