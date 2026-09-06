import 'package:hive_flutter/hive_flutter.dart';
import 'models.dart';

class SmartiHiveService {
  static const String tasksBoxName = 'smartiTasks';
  static const String goalsBoxName = 'smartiGoals';
  static const String settingsBoxName = 'smartiSettings';

  static Future<void> init() async {
    await Hive.initFlutter();
    
    // Register Adapters
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(SmartiTaskAdapter());
    }
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(SmartiGoalAdapter());
    }
    
    // Open Boxes
    await Hive.openBox<SmartiTask>(tasksBoxName);
    await Hive.openBox<SmartiGoal>(goalsBoxName);
    await Hive.openBox(settingsBoxName);
  }

  static Box<SmartiTask> get tasksBox => Hive.box<SmartiTask>(tasksBoxName);
  static Box<SmartiGoal> get goalsBox => Hive.box<SmartiGoal>(goalsBoxName);
  static Box get settingsBox => Hive.box(settingsBoxName);
}
