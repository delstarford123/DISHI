import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonBlue = Color(0xFF00E5FF);
const Color _textSecondary = Color(0xFF8B9BB4);

class DepositTrackerView extends StatelessWidget {
  const DepositTrackerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Deposit Tracker', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: _neonBlue)),
              child: const Column(
                children: [
                  Text('Secured Deposit', style: TextStyle(color: _textSecondary, fontSize: 14)),
                  SizedBox(height: 8),
                  Text('KES 10,000.00', style: TextStyle(color: _neonBlue, fontSize: 32, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  Text('Held securely in Escrow until Move-Out.', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('Deduction History', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield, color: _surfaceLight, size: 64),
                    const SizedBox(height: 16),
                    const Text('No Deductions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const Text('Your deposit is fully intact.', style: TextStyle(color: _textSecondary)),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
