import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _textSecondary = Color(0xFF8B9BB4);

class FinancialLiteracyHub extends StatelessWidget {
  const FinancialLiteracyHub({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Financial Literacy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildArticleCard('Budgeting in Campus', 'Learn how to help your student budget effectively.', Icons.menu_book),
          _buildArticleCard('Understanding Okoa Food', 'How the micro-credit facility protects students.', Icons.shield),
          _buildArticleCard('M-PESA Scams to Avoid', 'Security tips for online payments.', Icons.security),
        ],
      ),
    );
  }

  Widget _buildArticleCard(String title, String subtitle, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: _neonCyan),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: _textSecondary, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
