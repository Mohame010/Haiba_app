import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/services/app_preferences.dart';
import '../../data/onboarding_data.dart';
import 'onboarding_state.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit() : super(const OnboardingState());

  final PageController pageController = PageController();

  final pages = onboardingPages;

  void onPageChanged(int index) {
    emit(state.copyWith(currentPage: index));
  }

  Future<void> next(BuildContext context) async {
    if (state.isLastPage) {
      await AppPreferences.setOnboardingCompleted(true);
      if (context.mounted) {
        context.go(AppRoutes.login);
      }
      return;
    }

    await pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> skip(BuildContext context) async {
    await AppPreferences.setOnboardingCompleted(true);
    if (context.mounted) {
      context.go(AppRoutes.login);
    }
  }


  @override
  Future<void> close() {
    pageController.dispose();
    return super.close();
  }
}