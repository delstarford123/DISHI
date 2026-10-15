import 'package:flutter/material.dart';
import '../../../core/theme/mpesa_theme.dart';

class AdvancedControlsView extends StatelessWidget {
  final Map<String, dynamic> user;

  const AdvancedControlsView({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MPesaTheme.darkBg,
      appBar: AppBar(
        title: const Text('Advanced Controls', style: TextStyle(color: Colors.white, fontFamily: 'Outfit')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const Center(
        child: Text('Parent Advanced Controls', style: TextStyle(color: Colors.white70)),
      ),
    );
  }
}