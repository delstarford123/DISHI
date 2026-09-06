import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/ai_engine.dart';

class CoachingPage extends StatefulWidget {
  const CoachingPage({super.key});

  @override
  State<CoachingPage> createState() => _CoachingPageState();
}

class _CoachingPageState extends State<CoachingPage> {
  final AIEngine _aiEngine = AIEngine();
  String _briefing = 'Loading your morning briefing...';

  @override
  void initState() {
    super.initState();
    _loadBriefing();
  }

  Future<void> _loadBriefing() async {
    final briefing = await _aiEngine.generateMorningBriefing('Student');
    setState(() {
      _briefing = briefing;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Coaching')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.school, size: 80, color: SmartiTheme.secondaryLightBlue),
            const SizedBox(height: 20),
            Text('Strategy Review', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _briefing,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
