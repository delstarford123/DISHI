import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(ThemeMode.dark);
  static const String _themePrefKey = 'dishi_app_theme_mode';

  /// Initializes the theme controller from local persistent preferences
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_themePrefKey);
      if (saved == 'light') {
        themeMode.value = ThemeMode.light;
      } else {
        themeMode.value = ThemeMode.dark;
      }
    } catch (_) {
      themeMode.value = ThemeMode.dark;
    }
  }

  /// Sets and persists the app theme mode
  static Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themePrefKey, mode == ThemeMode.light ? 'light' : 'dark');
    } catch (_) {}
  }

  /// Toggles between light and dark modes
  static Future<void> toggleTheme() async {
    final newMode = themeMode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(newMode);
  }

  /// Checks if the active mode is dark
  static bool get isDark => themeMode.value == ThemeMode.dark;
}

