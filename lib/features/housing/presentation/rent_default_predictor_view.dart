import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonBlue = Color(0xFF00E5FF);
const Color _textSecondary = Color(0xFF8B9BB4);

class RentDefaultPredictorView extends StatelessWidget {
  const RentDefaultPredictorView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('AI Default Predictor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('High Risk Tenants (Next 30 Days)', style: TextStyle(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('2 Tenants', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                Text('Based on historical payment patterns and DISHI wallet activity.', style: TextStyle(color: _textSecondary, fontSize: 12, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Risk Analysis', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildRiskCard('James O. (Room 101)', '85% Default Risk', 'Consistently late for the past 3 months. Frequent Okoa usage.', Colors.red),
          _buildRiskCard('Sarah K. (Room 104)', '40% Default Risk', 'Irregular deposit patterns detected.', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildRiskCard(String name, String riskLvl, String reason, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text(riskLvl, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(reason, style: const TextStyle(color: _textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}
