import 'package:material_ui/material_ui.dart';
import '../../../core/theme/app_colors.dart';

class OnboardingIndicators extends StatelessWidget {
  final int currentPage;
  final int totalPages;

  const OnboardingIndicators({
    super.key,
    required this.currentPage,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalPages, _buildDot),
    );
  }

  Widget _buildDot(int index) {
    final isActive = index == currentPage;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 28 : 9,
      height: 9,
      decoration: BoxDecoration(
        color: isActive ? Color(0xFF7C3AED) : AppColors.indicatorInactive,
        borderRadius: BorderRadius.circular(5),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Color(0xFF7C3AED).withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
    );
  }
}
