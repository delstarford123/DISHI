import 'package:hive_flutter/hive_flutter.dart';

class LocalCache {
  static const String _boxName = 'swapeat_cache';
  
  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
  }

  static Box get _box => Hive.box(_boxName);

  // --- Theme Mode ---
  static void saveThemeMode(bool isDark) {
    _box.put('is_dark_mode', isDark);
  }

  static bool isDarkMode() {
    return _box.get('is_dark_mode', defaultValue: false);
  }

  // --- Onboarding Status ---
  static void setHasSeenOnboarding(bool hasSeen) {
    _box.put('has_seen_onboarding', hasSeen);
  }

  static bool hasSeenOnboarding() {
    return _box.get('has_seen_onboarding', defaultValue: false);
  }

  // --- Clear Cache ---
  static Future<void> clear() async {
    await _box.clear();
  }
}
