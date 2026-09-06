import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonBlue = Color(0xFF00E5FF);
const Color _textSecondary = Color(0xFF8B9BB4);

class TaxReportView extends StatelessWidget {
  const TaxReportView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Tax & Compliance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.download, color: _neonBlue), onPressed: () {})
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: _surfaceLight)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('KRA Rental Income Tax (MRI)', style: TextStyle(color: _textSecondary, fontSize: 14)),
                SizedBox(height: 8),
                Text('KES 18,500.00', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                Text('Estimated tax for October (7.5% of gross).', style: TextStyle(color: _textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text('Recent Filings', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildFilingCard('September 2026', 'KES 18,000 Paid', true),
          _buildFilingCard('August 2026', 'KES 17,500 Paid', true),
        ],
      ),
    );
  }

  Widget _buildFilingCard(String month, String status, bool isPaid) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(month, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          Row(
            children: [
              Text(status, style: TextStyle(color: isPaid ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Icon(isPaid ? Icons.check_circle : Icons.warning, color: isPaid ? Colors.green : Colors.orange),
            ],
          )
        ],
      ),
    );
  }
}
