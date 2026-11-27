import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/onboarding_data.dart';
import '../cubit/onboarding_cubit.dart';
import '../cubit/onboarding_state.dart';
import '../widgets/onboarding_footer.dart';
import '../widgets/onboarding_header.dart';
import '../widgets/onboarding_page.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();

    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<OnboardingCubit, OnboardingState>(
          builder: (context, state) {
            return Column(
              children: [
                OnboardingHeader(onSkip: () => cubit.skip(context)),

                Expanded(
                  child: PageView.builder(
                    controller: cubit.pageController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: onboardingPages.length,
                    onPageChanged: cubit.onPageChanged,
                    itemBuilder: (context, index) {
                      return OnboardingPage(model: onboardingPages[index]);
                    },
                  ),
                ),
                const SizedBox(height: 10),

                OnboardingFooter(
                  currentPage: state.currentPage,
                  totalPages: onboardingPages.length,
                  isLastPage: state.isLastPage,
                  onNext: () => cubit.next(context),
                ),

                const SizedBox(height: 25),
              ],
            );
          },
        ),
      ),
    );
  }
}
