import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/plan_provider.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final planProvider = Provider.of<SmartiPlanProvider>(context);
    final completionRate = planProvider.completionRate;

    return Scaffold(
      backgroundColor: SmartiTheme.backgroundGrey,
      appBar: AppBar(
        title: const Text('Analytics & History'),
        backgroundColor: SmartiTheme.primaryNavy,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text('Completion Rate', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 120,
                          width: 120,
                          child: CircularProgressIndicator(
                            value: completionRate,
                            strokeWidth: 12,
                            backgroundColor: Colors.grey[200],
                            color: Colors.orangeAccent,
                          ),
                        ),
                        Text(
                          '${(completionRate * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatBox(context, 'Total Tasks', planProvider.totalTasks.toString(), SmartiTheme.primaryNavy),
                        _buildStatBox(context, 'Completed', planProvider.completedTasks.toString(), Colors.green),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            Text('Category Breakdown', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
            // Categories
            _buildCategoryRow('Mental', planProvider.tasksByCategory('Mental'), Colors.blue),
            _buildCategoryRow('Physical', planProvider.tasksByCategory('Physical'), Colors.red),
            _buildCategoryRow('Spiritual', planProvider.tasksByCategory('Spiritual'), Colors.purple),
            _buildCategoryRow('Work', planProvider.tasksByCategory('Work'), Colors.orange),

            const SizedBox(height: 24),
            Text('Task History', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
            if (planProvider.tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: Text('No tasks recorded yet.')),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: planProvider.tasks.length,
                itemBuilder: (context, index) {
                  final task = planProvider.tasks[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        task.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: task.isCompleted ? Colors.green : Colors.grey,
                      ),
                      title: Text(
                        task.title,
                        style: TextStyle(decoration: task.isCompleted ? TextDecoration.lineThrough : null),
                      ),
                      subtitle: Text(task.category),
                      trailing: Text('${task.scheduledTime.hour}:${task.scheduledTime.minute.toString().padLeft(2, '0')}'),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildCategoryRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(width: 16, height: 16, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
          Text(count.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
