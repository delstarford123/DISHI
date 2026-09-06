import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonBlue = Color(0xFF00E5FF);
const Color _textSecondary = Color(0xFF8B9BB4);

class MerchantPremiumFinanceView extends StatelessWidget {
  const MerchantPremiumFinanceView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Premium Finance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.amber)),
            child: const Column(
              children: [
                Icon(Icons.workspace_premium, color: Colors.amber, size: 48),
                SizedBox(height: 16),
                Text('Landlord Credit Line', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Access capital for property renovations based on your consistent rental income history.', textAlign: TextAlign.center, style: TextStyle(color: _textSecondary, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildStatRow('Eligible Limit', 'KES 500,000'),
          _buildStatRow('Interest Rate', '1.5% / month'),
          _buildStatRow('Repayment Term', '12 Months'),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: () {},
            child: const Text('APPLY FOR FACILITY', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildStatRow(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: _textSecondary, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
