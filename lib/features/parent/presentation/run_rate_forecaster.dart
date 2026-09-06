import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _textSecondary = Color(0xFF8B9BB4);

class RunRateForecaster extends StatelessWidget {
  const RunRateForecaster({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Run-Rate Forecaster', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: _surfaceLight)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Estimated Depletion', style: TextStyle(color: _textSecondary, fontSize: 14)),
                  const SizedBox(height: 8),
                  const Text('4 Days Remaining', style: TextStyle(color: _neonCyan, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: 0.3,
                    backgroundColor: _surfaceLight,
                    color: _neonCyan,
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 16),
                  const Text('Based on the student\'s average spend of KES 250/day, their current balance of KES 1000 will run out by Thursday.', style: TextStyle(color: _textSecondary, height: 1.5)),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, padding: const EdgeInsets.symmetric(vertical: 16), minimumSize: const Size(double.infinity, 50)),
              onPressed: () {},
              child: const Text('TOP UP NOW', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}
