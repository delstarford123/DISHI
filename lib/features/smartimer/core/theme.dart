import 'package:flutter/material.dart';

class SmartiTheme {
  static const Color primaryNavy = Color(0xFF1A237E);
  static const Color secondaryLightBlue = Color(0xFF4FC3F7);
  static const Color tertiaryDeepSky = Color(0xFF0288D1);
  static const Color backgroundGrey = Color(0xFFF5F7FA);
  static const Color surfaceWhite = Colors.white;

  static ThemeData get themeData {
    return ThemeData(
      primaryColor: primaryNavy,
      scaffoldBackgroundColor: backgroundGrey,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryNavy,
        secondary: secondaryLightBlue,
        tertiary: tertiaryDeepSky,
        surface: surfaceWhite,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryNavy,
        foregroundColor: surfaceWhite,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: surfaceWhite,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFEEEEEE)), 
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: primaryNavy, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: primaryNavy, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: Colors.black87),
        bodyMedium: TextStyle(color: Colors.black87),
      ),
    );
  }
}
