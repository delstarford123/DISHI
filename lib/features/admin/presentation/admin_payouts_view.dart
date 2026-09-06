import 'package:flutter/material.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonRed = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class AdminPayoutsView extends StatelessWidget {
  const AdminPayoutsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('B2C Mass Payouts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: _neonRed.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: _neonRed)),
              child: const Column(
                children: [
                  Icon(Icons.warning, color: _neonRed, size: 40),
                  SizedBox(height: 16),
                  Text('Initiate M-PESA B2C Payouts', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('This will instantly transfer funds to 45 pending vendors.', textAlign: TextAlign.center, style: TextStyle(color: _textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _neonRed, padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: () {},
              child: const Text('PROCESS PAYOUTS NOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}
