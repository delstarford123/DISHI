import 'package:flutter/material.dart';
import '../data/hive_service.dart';
import '../data/models.dart';

class SmartiPlanProvider with ChangeNotifier {
  List<SmartiTask> _tasks = [];

  List<SmartiTask> get tasks => _tasks;

  void loadTasks() {
    _tasks = SmartiHiveService.tasksBox.values.toList();
    notifyListeners();
  }

  void addTask(SmartiTask task) {
    SmartiHiveService.tasksBox.put(task.id, task);
    _tasks.add(task);
    notifyListeners();
  }

  void toggleTaskComplete(String id) {
    final task = SmartiHiveService.tasksBox.get(id);
    if (task != null) {
      task.isCompleted = !task.isCompleted;
      SmartiHiveService.tasksBox.put(id, task);
      loadTasks();
    }
  }

  // Analytics Helpers
  int get totalTasks => _tasks.length;
  int get completedTasks => _tasks.where((t) => t.isCompleted).length;
  double get completionRate => totalTasks == 0 ? 0 : completedTasks / totalTasks;
  
  int tasksByCategory(String category) {
    return _tasks.where((t) => t.category == category).length;
  }
}
