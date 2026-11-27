import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../domain/entities/exam_entity.dart';
import '../cubits/exams_list/exams_list_cubit.dart';
import '../cubits/exams_list/exams_list_state.dart';

class ExamsListScreen extends StatefulWidget {
  const ExamsListScreen({super.key});

  @override
  State<ExamsListScreen> createState() => _ExamsListScreenState();
}

class _ExamsListScreenState extends State<ExamsListScreen> {
  String _selectedType = 'exam';

  @override
  void initState() {
    super.initState();
    context.read<ExamsListCubit>().loadExams();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'الامتحانات والتحديات',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontFamily: 'IBM',
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTabs(),
            SizedBox(height: 10.h),
            Expanded(
              child: BlocBuilder<ExamsListCubit, ExamsListState>(
                builder: (context, state) {
                  if (state is ExamsListLoading || state is ExamsListInitial) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }
                  if (state is ExamsListError) {
                    return _message(state.message, isError: true);
                  }
                  if (state is ExamsListLoaded) {
                    final items = state.exams
                        .where((exam) => exam.examType == _selectedType)
                        .toList();
                    if (items.isEmpty) {
                      return _message(
                        _selectedType == 'challenge'
                            ? 'لا توجد تحديات متاحة حالياً'
                            : 'لا توجد امتحانات متاحة حالياً',
                      );
                    }
                    return RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () =>
                          context.read<ExamsListCubit>().loadExams(),
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 12.h,
                        ),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => SizedBox(height: 14.h),
                        itemBuilder: (context, index) =>
                            _buildCard(items[index]),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Container(
        height: 48.h,
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.borderLight, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildTabItem(
              title: 'الامتحانات',
              icon: Icons.assignment_rounded,
              isSelected: _selectedType == 'exam',
              onTap: () {
                if (_selectedType != 'exam') {
                  setState(() => _selectedType = 'exam');
                }
              },
            ),
            SizedBox(width: 6.w),
            _buildTabItem(
              title: 'التحديات',
              icon: Icons.bolt_rounded,
              isSelected: _selectedType == 'challenge',
              onTap: () {
                if (_selectedType != 'challenge') {
                  setState(() => _selectedType = 'challenge');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18.w,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
                SizedBox(width: 6.w),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontFamily: 'IBM',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _message(String message, {bool isError = false}) => Center(
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 14.sp,
        color: isError ? AppColors.error : AppColors.textSecondary,
        fontFamily: 'IBM',
      ),
    ),
  );

  Widget _buildCard(ExamEntity exam) {
    final accent = exam.isChallenge
        ? const Color(0xFFF97316)
        : AppColors.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(20.r),
      onTap: () async {
        await context.push(AppRoutes.examDetails, extra: exam.id);
        if (mounted) context.read<ExamsListCubit>().loadExams();
      },
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58.w,
              height: 58.w,
              decoration: BoxDecoration(
                color: accent.withAlpha(20),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Icon(
                exam.isChallenge
                    ? Icons.bolt_rounded
                    : Icons.assignment_turned_in_rounded,
                color: accent,
                size: 30,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (exam.isChallenge)
                    Text(
                      'تحدٍ مفتوح لكل الصفوف',
                      style: TextStyle(
                        color: accent,
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'IBM',
                      ),
                    ),
                  Text(
                    exam.title,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFamily: 'IBM',
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    '${exam.durationMinutes} دقيقة • ${exam.totalScore} نقطة',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      color: accent,
                      fontFamily: 'IBM',
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.textMuted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
