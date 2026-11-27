import 'package:material_ui/material_ui.dart';
import 'package:equatable/equatable.dart';

class OnboardingModel extends Equatable {
  final String image;
  final String badgeText;
  final String titlePart1;
  final String titlePart2;
  final String description;
  final Color accentColor;
  final List<Color> gradientColors;

  const OnboardingModel({
    required this.image,
    required this.badgeText,
    required this.titlePart1,
    required this.titlePart2,
    required this.description,
    required this.accentColor,
    required this.gradientColors,
  });

  @override
  List<Object?> get props => [
        image,
        badgeText,
        titlePart1,
        titlePart2,
        description,
        accentColor,
        gradientColors,
      ];
}