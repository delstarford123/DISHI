import 'package:flutter/material.dart';

class MatchSecretAdmirerView extends StatelessWidget {
  const MatchSecretAdmirerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: const Text('Secret Admirer 💌')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite, color: Colors.pinkAccent, size: 80),
            const SizedBox(height: 20),
            const Text('Send an anonymous crush!', style: TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent), child: const Text('Send a Crush'))
          ],
        ),
      ),
    );
  }
}
