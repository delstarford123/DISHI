import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _textSecondary = Color(0xFF8B9BB4);

class IntelligentInsightsView extends StatelessWidget {
  const IntelligentInsightsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('AI Insights', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInsightCard('High Spending Alert', 'Your student spent 40% more on fast food this week compared to last week.', Icons.fastfood, _neonPink),
          _buildInsightCard('Academic Correlation', 'Focus hours dropped by 2h the day after the late-night spending spike.', Icons.school, Colors.orange),
          _buildInsightCard('Savings Opportunity', 'Switching from daily top-ups to weekly top-ups will save you KES 24 in M-PESA fees.', Icons.savings, _neonCyan),
        ],
      ),
    );
  }

  Widget _buildInsightCard(String title, String insight, IconData icon, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: iconColor.withOpacity(0.5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 12),
              Text(title, style: TextStyle(color: iconColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Text(insight, style: const TextStyle(color: Colors.white, height: 1.5)),
        ],
      ),
    );
  }
}
