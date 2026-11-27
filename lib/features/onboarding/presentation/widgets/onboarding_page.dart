import 'package:material_ui/material_ui.dart';
import '../../../core/theme/app_colors.dart';
import '../../data/onboarding_model.dart';

class OnboardingPage extends StatelessWidget {
  final OnboardingModel model;

  const OnboardingPage({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 10),

          // Badge Tag
          // Container(
          //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          //   decoration: BoxDecoration(
          //     gradient: LinearGradient(
          //       colors: [
          //         model.accentColor.withValues(alpha: 0.15),
          //         model.accentColor.withValues(alpha: 0.05),
          //       ],
          //     ),
          //     borderRadius: BorderRadius.circular(30),
          //     border: Border.all(
          //       color: model.accentColor.withValues(alpha: 0.3),
          //       width: 1,
          //     ),
          //   ),
          //   child: Text(
          //     model.badgeText,
          //     style: Theme.of(context).textTheme.labelMedium?.copyWith(
          //           color: model.accentColor,
          //           fontWeight: FontWeight.w700,
          //         ),
          //   ),
          // ),
          // const SizedBox(height: 20),

          // Hero Image Card
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Soft Gradient Radial Backdrop
                Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        model.gradientColors[1].withValues(alpha: 0.7),
                        model.gradientColors[0].withValues(alpha: 0.1),
                      ],
                      radius: 0.85,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
                // Hero Image
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(model.image, fit: BoxFit.contain),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Title
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: model.titlePart1,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    color: AppColors.secondary,
                    height: 1.3,
                  ),
                ),
                TextSpan(
                  text: model.titlePart2,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 25,
                    color: model.accentColor,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Description (Egyptian Arabic)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              model.description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 15,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
