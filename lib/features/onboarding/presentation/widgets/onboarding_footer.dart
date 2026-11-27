import 'package:material_ui/material_ui.dart';
import '../../../core/widgets/primary_button.dart';
import 'onboarding_indicators.dart';

class OnboardingFooter extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final bool isLastPage;
  final VoidCallback onNext;

  const OnboardingFooter({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.isLastPage,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          OnboardingIndicators(
            currentPage: currentPage,
            totalPages: totalPages,
          ),

          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              
              onPressed: onNext,
              text: isLastPage ? "يلا نبدأ" : "التالي",
            ),
          ),
        ],
      ),
    );
  }
}
