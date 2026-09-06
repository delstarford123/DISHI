import 'package:flutter/material.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonRed = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class AdminNfcManagerView extends StatelessWidget {
  const AdminNfcManagerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('NFC Card Manager', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: _neonCyan.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: _neonCyan),
              ),
              child: const Icon(Icons.nfc, color: _neonCyan, size: 64),
            ),
            const SizedBox(height: 24),
            const Text('Tap an NFC Card to Register', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Hold the student\'s DISHI band or card near your phone.', style: TextStyle(color: _textSecondary)),
          ],
        ),
      ),
    );
  }
}
