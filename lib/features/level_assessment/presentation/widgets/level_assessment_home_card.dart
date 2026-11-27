import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../data/services/level_assessment_service.dart';
import '../../domain/entities/level_assessment.dart';

class LevelAssessmentHomeCard extends StatefulWidget {
  final VoidCallback onTap;

  const LevelAssessmentHomeCard({super.key, required this.onTap});

  @override
  State<LevelAssessmentHomeCard> createState() =>
      _LevelAssessmentHomeCardState();
}

class _LevelAssessmentHomeCardState extends State<LevelAssessmentHomeCard> {
  late Future<LevelAssessmentResult?> _future;

  @override
  void initState() {
    super.initState();
    _future = LevelAssessmentService.instance.latestResult();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LevelAssessmentResult?>(
      future: _future,
      builder: (context, snapshot) {
        final result = snapshot.data;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(22.r),
              child: Ink(
                padding: EdgeInsets.all(17.w),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Color(0xFF312E81), Color(0xFF6D28D9)],
                  ),
                  borderRadius: BorderRadius.circular(22.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(42),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : result == null
                    ? _buildInvitation()
                    : _buildResult(result),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInvitation() {
    return Row(
      children: [
        Container(
          width: 54.w,
          height: 54.w,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(28),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: const Icon(
            Icons.psychology_alt_rounded,
            color: Color(0xFFFDE68A),
            size: 31,
          ),
        ),
        SizedBox(width: 13.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'اكتشف مستواك في الإنجليزي',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'IBM',
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                'اختبار قصير يحدد مستواك ويرشحلك الكورس المناسب',
                style: TextStyle(
                  color: Colors.white.withAlpha(205),
                  fontSize: 11.5.sp,
                  height: 1.4,
                  fontFamily: 'IBM',
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.arrow_back_rounded, color: Colors.white),
      ],
    );
  }

  Widget _buildResult(LevelAssessmentResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              color: Color(0xFFFDE68A),
            ),
            SizedBox(width: 7.w),
            Text(
              'مستواك: ${result.overallLevel.arabicName}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w900,
                fontFamily: 'IBM',
              ),
            ),
            const Spacer(),
            Text(
              '${result.overallScore}%',
              style: TextStyle(
                color: const Color(0xFFFDE68A),
                fontSize: 17.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: AssessmentSkill.values
              .map(
                (skill) => Expanded(
                  child: Column(
                    children: [
                      Text(
                        skill.arabicName,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10.sp,
                          fontFamily: 'IBM',
                        ),
                      ),
                      Text(
                        result.levelFor(skill).arabicName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'IBM',
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
        SizedBox(height: 9.h),
        Text(
          'اضغط لإعادة الاختبار',
          textAlign: TextAlign.end,
          style: TextStyle(
            color: const Color(0xFFFDE68A),
            fontSize: 10.5.sp,
            fontWeight: FontWeight.w700,
            fontFamily: 'IBM',
          ),
        ),
      ],
    );
  }
}
