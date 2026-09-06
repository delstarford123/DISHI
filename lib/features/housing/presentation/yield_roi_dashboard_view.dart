import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonBlue = Color(0xFF00E5FF);
const Color _textSecondary = Color(0xFF8B9BB4);

class YieldRoiDashboardView extends StatelessWidget {
  const YieldRoiDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Yield & ROI Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_neonBlue, Color(0xFF005B9F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gross Yield (Annual)', style: TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('12.4%', style: TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('QWETU Properties Portfolio', style: TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Key Metrics', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMetricCard('Occupancy Rate', '95%', Icons.home_work)),
              const SizedBox(width: 16),
              Expanded(child: _buildMetricCard('Net Operating Income', 'KES 1.2M', Icons.account_balance_wallet)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMetricCard('Expense Ratio', '15%', Icons.pie_chart)),
              const SizedBox(width: 16),
              Expanded(child: _buildMetricCard('Cash on Cash ROI', '8.2%', Icons.trending_up)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: _surfaceLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _neonBlue, size: 28),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: _textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }
}
