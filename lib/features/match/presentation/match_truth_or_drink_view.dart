import 'package:flutter/material.dart';

class MatchTruthOrDrinkView extends StatelessWidget {
  const MatchTruthOrDrinkView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: const Text('Truth or Drink 🎲')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.liquor, color: Colors.orangeAccent, size: 80),
            const SizedBox(height: 20),
            const Text('Answer bold icebreaker questions.', style: TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent), child: const Text('Start Game'))
          ],
        ),
      ),
    );
  }
}
