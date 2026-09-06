import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonBlue = Color(0xFF00E5FF);
const Color _textSecondary = Color(0xFF8B9BB4);

class MerchantReconciliationView extends StatelessWidget {
  const MerchantReconciliationView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Rent Reconciliation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildReconCard('Room 101 - James Doe', 'KES 15,000 Expected', 'KES 15,000 Paid', true),
          _buildReconCard('Room 102 - Sarah Kamau', 'KES 15,000 Expected', 'KES 10,000 Paid (Partial)', false),
          _buildReconCard('Room 103 - Mark O.', 'KES 15,000 Expected', 'KES 0 Paid', false),
        ],
      ),
    );
  }

  Widget _buildReconCard(String room, String expected, String paid, bool isFullyPaid) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: isFullyPaid ? Colors.green.withOpacity(0.5) : Colors.orange.withOpacity(0.5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(room, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Icon(isFullyPaid ? Icons.check_circle : Icons.warning_amber, color: isFullyPaid ? Colors.green : Colors.orange),
            ],
          ),
          const SizedBox(height: 8),
          Text(expected, style: const TextStyle(color: _textSecondary, fontSize: 14)),
          Text(paid, style: TextStyle(color: isFullyPaid ? Colors.green : Colors.orange, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
