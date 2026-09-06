import 'package:flutter/material.dart';

class MPesaTheme {
  static const Color primaryGreen = Color(0xFF1EA152);
  static const Color darkGreen = Color(0xFF136E37);
  static const Color lightGreen = Color(0xFFE8F5E9);
  
  static const Color primaryRed = Color(0xFFE53935);
  static const Color errorBackground = Color(0xFFFFEBEE);

  static const Color darkBg = Color(0xFF0B101A); // Deep dark blueish background
  static const Color cardDark = Color(0xFF131A26); // Slightly lighter for cards
  
  // Neon accents based on design
  static const Color neonGreen = Color(0xFF00E676);
  static const Color neonCyan = Color(0xFF18FFFF);
  static const Color neonPink = Color(0xFFFF4081);
  static const Color neonPurple = Color(0xFFD500F9);
  
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color grey = Color(0xFF9E9E9E);
  static const Color lightGray = Color(0xFFEEEEEE);

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      fontFamily: 'Outfit',
      primaryColor: primaryGreen,
      scaffoldBackgroundColor: white,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: white,
        elevation: 0,
      ),
      colorScheme: const ColorScheme.light(
        primary: primaryGreen,
        secondary: darkGreen,
        error: primaryRed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: 'Outfit',
      primaryColor: primaryGreen,
      scaffoldBackgroundColor: darkBg,
      cardColor: cardDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: cardDark,
        foregroundColor: white,
        elevation: 0,
      ),
      colorScheme: const ColorScheme.dark(
        primary: primaryGreen,
        secondary: darkGreen,
        error: primaryRed,
        surface: cardDark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
