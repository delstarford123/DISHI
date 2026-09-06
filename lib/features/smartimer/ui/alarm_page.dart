import 'package:flutter/material.dart';
import '../core/theme.dart';

class AlarmPage extends StatelessWidget {
  const AlarmPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SmartiTheme.primaryNavy,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.alarm, size: 100, color: SmartiTheme.secondaryLightBlue),
            const SizedBox(height: 20),
            const Text(
              'Wake Up!',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: SmartiTheme.secondaryLightBlue,
                foregroundColor: SmartiTheme.primaryNavy,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Stop Alarm'),
            ),
          ],
        ),
      ),
    );
  }
}
