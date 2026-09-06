import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonBlue = Color(0xFF00E5FF);
const Color _textSecondary = Color(0xFF8B9BB4);

class UtilitySplitterView extends StatelessWidget {
  const UtilitySplitterView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Utility Splitter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: _surfaceLight)),
            child: const Column(
              children: [
                Text('Total Electricity Bill (Tokens)', style: TextStyle(color: _textSecondary, fontSize: 14)),
                SizedBox(height: 8),
                Text('KES 1,200.00', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                Text('Split equally among 3 roommates (KES 400.00 each)', style: TextStyle(color: _neonBlue, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Roommate Contributions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildPayerRow('You', 'KES 400', true),
          _buildPayerRow('Alex', 'KES 400', true),
          _buildPayerRow('John', 'KES 400', false),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonBlue, padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: () {},
            child: const Text('SEND PAYMENT REMINDER', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildPayerRow(String name, String amount, bool hasPaid) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          Row(
            children: [
              Text(amount, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Icon(hasPaid ? Icons.check_circle : Icons.timer, color: hasPaid ? Colors.green : Colors.orange),
            ],
          )
        ],
      ),
    );
  }
}
