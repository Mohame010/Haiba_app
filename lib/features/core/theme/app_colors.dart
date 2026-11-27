import 'package:material_ui/material_ui.dart';

class AppColors {
  const AppColors._();

  // Primary Palette
  static const primary = Color(0xFF7C3AED);
  static const primaryDark = Color(0xFF4F46E5);
  static const primaryPurple = Color(0xFF7C3AED);
  static const secondary = Color(0xFF192244);
  static const navyDark = Color(0xFF0F172A);

  // Indicators
  static const Color indicatorActive = Color(0xFF7C3AED);
  static const Color indicatorInactive = Color(0xFFCBD5E1);

  // Backgrounds
  static const background = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const cardLight = Color(0xFFF1F5F9);
  static const cardBlue = Color(0xFFEFF6FF); 

  // Text Colors
  static const textPrimary = Color(0xFF1E1B4B);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);

  // Status & Badges
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);

  // Borders & Dividers
  static const border = Color(0xFFE2E8F0);
  static const borderLight = Color(0xFFF1F5F9);

  // Medal & Leaderboard Colors
  static const goldMedal = Color(0xFFF59E0B);
  static const silverMedal = Color(0xFF94A3B8);
  static const bronzeMedal = Color(0xFFD97706);
  static const starGold = Color(0xFFFBBF24);

  // Gradients
  static const LinearGradient pointsGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0F172A),
      Color(0xFF312E81),
      Color(0xFF4338CA),
    ],
  );

  static const LinearGradient bannerBlueGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFF1E3A8A),
      Color(0xFF2563EB),
      Color(0xFF38BDF8),
    ],
  );

  static const LinearGradient leaderboardHeaderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E1B4B),
      Color(0xFF3730A3),
      Color(0xFF6366F1),
    ],
  );
}
