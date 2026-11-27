import 'package:material_ui/material_ui.dart';

class AppTextStyles {
  const AppTextStyles._();

  static const String englishFont = 'Poppins';
  static const String arabicFont = 'Cairo';

  static String fontFamily(Locale locale) =>
      locale.languageCode == 'ar' ? arabicFont : arabicFont;

  static TextTheme textTheme({
    required Color textColor,
    required String fontFamily,
  }) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: textColor,
        fontFamily: fontFamily,
      ),

      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: textColor,
        fontFamily: fontFamily,
      ),

      headlineLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: textColor,
        fontFamily: fontFamily,
      ),

      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textColor,
        fontFamily: fontFamily,
      ),

      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textColor,
        fontFamily: fontFamily,
      ),

      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textColor,
        fontFamily: fontFamily,
      ),

      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: textColor,
        fontFamily: fontFamily,
      ),

      bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: textColor,
        fontFamily: fontFamily,
      ),

      bodySmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: textColor,
        fontFamily: fontFamily,
      ),

      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textColor,
        fontFamily: fontFamily,
      ),

      labelMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textColor,
        fontFamily: fontFamily,
      ),

      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textColor,
        fontFamily: fontFamily,
      ),
    );
  }
}