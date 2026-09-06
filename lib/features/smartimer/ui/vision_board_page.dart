import 'package:flutter/material.dart';
import '../core/theme.dart';

class VisionBoardPage extends StatelessWidget {
  const VisionBoardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vision Board')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.rocket_launch, size: 80, color: SmartiTheme.tertiaryDeepSky),
            const SizedBox(height: 20),
            Text('Long-term Goals', style: Theme.of(context).textTheme.headlineMedium),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Align your daily tasks with your grand vision. "Where there is no vision, the people perish." - Proverbs 29:18',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
