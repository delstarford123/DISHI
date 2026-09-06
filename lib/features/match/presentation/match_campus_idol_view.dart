import 'package:flutter/material.dart';

class MatchCampusIdolView extends StatelessWidget {
  const MatchCampusIdolView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: const Text('Campus Idol 🎤')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mic, color: Colors.blueAccent, size: 80),
            const SizedBox(height: 20),
            const Text('Listen to 10s voice notes.', style: TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent), child: const Text('Play Feed'))
          ],
        ),
      ),
    );
  }
}
