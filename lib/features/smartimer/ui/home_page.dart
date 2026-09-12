import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../providers/plan_provider.dart';
import 'vision_board_page.dart';
import 'coaching_page.dart';
import 'history_page.dart';
import 'focus_mode_view.dart';

class SmartiHomePage extends StatefulWidget {
  const SmartiHomePage({super.key});

  @override
  State<SmartiHomePage> createState() => _SmartiHomePageState();
}

class _SmartiHomePageState extends State<SmartiHomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SmartiPlanProvider>(context, listen: false).loadTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final planProvider = Provider.of<SmartiPlanProvider>(context);

    return Scaffold(
      backgroundColor: SmartiTheme.backgroundGrey,
      appBar: AppBar(
        title: const Text('Smart Routine AI'),
        backgroundColor: SmartiTheme.primaryNavy,
        actions: [
          IconButton(
            icon: const Icon(Icons.rocket_launch),
            tooltip: 'Vision Board',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VisionBoardPage())),
          ),
          IconButton(
            icon: const Icon(Icons.local_library),
            tooltip: 'Focus Mode',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusModeView())),
          ),
          IconButton(
            icon: const Icon(Icons.school),
            tooltip: 'Coaching',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoachingPage())),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Analytics',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage())),
          ),
        ],
      ),
      body: planProvider.tasks.isEmpty
          ? const Center(
              child: Text('No tasks scheduled. Tap + to add.'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: planProvider.tasks.length,
              itemBuilder: (context, index) {
                final task = planProvider.tasks[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Checkbox(
                      value: task.isCompleted,
                      onChanged: (val) {
                        planProvider.toggleTaskComplete(task.id);
                      },
                    ),
                    title: Text(
                      task.title,
                      style: TextStyle(
                        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: Text(task.category),
                    trailing: Text('${task.scheduledTime.hour}:${task.scheduledTime.minute.toString().padLeft(2, '0')}'),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: SmartiTheme.secondaryLightBlue,
        onPressed: () => _showCreateTaskDialog(context, planProvider),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateTaskDialog(BuildContext context, SmartiPlanProvider planProvider) {
    final titleController = TextEditingController();
    String selectedCategory = 'Mental';
    final categories = ['Mental', 'Physical', 'Spiritual', 'Work'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Task Title'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                items: categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => selectedCategory = val);
                },
                decoration: const InputDecoration(labelText: 'Category'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  planProvider.addTask(
                    SmartiTask(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: titleController.text,
                      category: selectedCategory,
                      scheduledTime: DateTime.now().add(const Duration(hours: 1)),
                    ),
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
