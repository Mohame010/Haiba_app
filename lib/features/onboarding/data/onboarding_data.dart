import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_images.dart';
import 'onboarding_model.dart';

final List<OnboardingModel> onboardingPages = [
  const OnboardingModel(
    image: AppImages.onboarding1,
    badgeText: "تعلم إنجليزي بسهولة 🇬🇧",
    titlePart1: "طوّر لغتك الإنجليزية ",
    titlePart2: "من الصفر للاحتراف",
    description:
        "شروحات مبسطة وكورسات متكاملة في القواعد، الكلمات، والمحادثة هتخليك تتقن الإنجليزي خطوة بخطوة بكل سهولة.",
    accentColor: Color(0xFFF89A6F),
    gradientColors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
  ),
  const OnboardingModel(
    image: AppImages.onboarding2,
    badgeText: "كورسات تفاعلية 🎓",
    titlePart1: "أقوى الكورسات والدروس ",
    titlePart2: "في مكان واحد",
    description:
        "فيديوهات تفاعلية عالية الجودة وتمارين بعد كل درس لضمان فهمك وتطبيقك لكل القواعد والكلمات عملياً.",
    accentColor: Color(0xFF6366F1),
    gradientColors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
  ),
  const OnboardingModel(
    image: AppImages.onboarding3,
    badgeText: "تطبيق واختبارات 🚀",
    titlePart1: "اختبر مستواك ",
    titlePart2: "وشوف تقدمك يوم بعد يوم",
    description:
        "امتحانات دورية وتدريبات مستمرة بتحدد مستواك ونقاط قوتك، وتساعدك تتكلم وتكتب إنجليزي بطلاقة وثقة.",
    accentColor: Color(0xFF10B981),
    gradientColors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
  ),
];
