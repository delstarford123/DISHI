import 'package:flutter/material.dart';

class SafetyPinsView extends StatelessWidget {
  const SafetyPinsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Safety Pins', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const Center(
        child: Text(
          'Safety Pins Map',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}
