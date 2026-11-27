import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_constants.dart';

class GradeDropdownField extends StatefulWidget {
  final String stage;
  final String? selectedGrade;
  final ValueChanged<String> onGradeSelected;
  final String? errorText;

  const GradeDropdownField({
    super.key,
    required this.stage,
    required this.selectedGrade,
    required this.onGradeSelected,
    this.errorText,
  });

  @override
  State<GradeDropdownField> createState() => _GradeDropdownFieldState();
}

class _GradeDropdownFieldState extends State<GradeDropdownField> {
  bool _isOpen = false;

  List<String> get _grades => AppConstants.getGradesForStage(widget.stage);

  @override
  Widget build(BuildContext context) {
    final isUniversity = widget.stage == AppConstants.stageUniversity;
    final fieldLabel = isUniversity ? 'الفرقة' : 'الصف';
    final hasSelection =
        widget.selectedGrade != null && widget.selectedGrade!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fieldLabel,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E1B4B),
            fontFamily: 'IBM',
          ),
        ),
        SizedBox(height: 8.h),
        InkWell(
          onTap: () {
            setState(() {
              _isOpen = !_isOpen;
            });
          },
          borderRadius: BorderRadius.circular(14.r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 52.h,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: widget.errorText != null
                    ? const Color(0xFFEF4444)
                    : _isOpen
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFFE5E7EB),
                width: _isOpen ? 1.5 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasSelection ? widget.selectedGrade! : 'اختر $fieldLabel',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: hasSelection
                          ? const Color(0xFF1E1B4B)
                          : const Color(0xFF9CA3AF),
                      fontFamily: 'IBM',
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _isOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF6B7280),
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Inline Dropdown List matching screenshot
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            margin: EdgeInsets.only(top: 8.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14.r),
              child: Column(
                children: _grades.map((grade) {
                  final isSelected = widget.selectedGrade == grade;
                  return Material(
                    color: isSelected
                        ? const Color(0xFFF5F3FF)
                        : Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        widget.onGradeSelected(grade);
                        setState(() {
                          _isOpen = false;
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 18.w,
                          vertical: 14.h,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: const Color(0xFFF3F4F6),
                              width: grade == _grades.last ? 0 : 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                grade,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? const Color(0xFF7C3AED)
                                      : const Color(0xFF374151),
                                  fontFamily: 'IBM',
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_rounded,
                                color: Color(0xFF7C3AED),
                                size: 18,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          crossFadeState: _isOpen
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),

        if (widget.errorText != null) ...[
          SizedBox(height: 6.h),
          Text(
            widget.errorText!,
            style: TextStyle(
              fontSize: 12.sp,
              color: const Color(0xFFEF4444),
              fontFamily: 'IBM',
            ),
          ),
        ],
      ],
    );
  }
}
