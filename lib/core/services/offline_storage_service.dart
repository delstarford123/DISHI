import 'package:hive_flutter/hive_flutter.dart';

/// Handles lightning-fast, offline-first local NoSQL storage via Hive.
/// Primarily used for the SmartI module (Tasks, Settings, Goals, Journal).
class OfflineStorageService {
  static const String _tasksBox = 'tasks_box';
  static const String _settingsBox = 'settings_box';
  static const String _goalsBox = 'goals_box';
  static const String _journalBox = 'journal_box';

  static Future<void> initialize() async {
    await Hive.initFlutter();
    
    // Open all necessary boxes
    await Hive.openBox(_tasksBox);
    await Hive.openBox(_settingsBox);
    await Hive.openBox(_goalsBox);
    await Hive.openBox(_journalBox);

    // Set default settings if they don't exist
    final settings = Hive.box(_settingsBox);
    if (!settings.containsKey('strictness_level')) {
      await settings.put('strictness_level', 7.5);
    }
    if (!settings.containsKey('wakeup_phrase')) {
      await settings.put('wakeup_phrase', 'thank you smart');
    }
  }

  // --- Tasks ---
  static Box get tasks => Hive.box(_tasksBox);

  // --- Settings ---
  static Box get settings => Hive.box(_settingsBox);

  // --- Goals ---
  static Box get goals => Hive.box(_goalsBox);

  // --- Journal ---
  static Box get journal => Hive.box(_journalBox);
  
  /// Wipes all local Hive data (e.g. on Account Deletion or Logout)
  static Future<void> clearAll() async {
    await tasks.clear();
    await settings.clear();
    await goals.clear();
    await journal.clear();
  }
}
