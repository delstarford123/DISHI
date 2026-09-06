import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _textSecondary = Color(0xFF8B9BB4);

class CarePackageOrder extends StatelessWidget {
  const CarePackageOrder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Send Care Package', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _buildPackageCard('Exam Prep Kit', 'Snacks & Redbull', 'KES 1,200', Icons.book),
          _buildPackageCard('Healthy Box', 'Fruits & Nuts', 'KES 850', Icons.eco),
          _buildPackageCard('Pizza Night', 'Large Pizza Deal', 'KES 1,500', Icons.local_pizza),
          _buildPackageCard('Custom Amount', 'Wallet Top-up', 'Custom', Icons.wallet),
        ],
      ),
    );
  }

  Widget _buildPackageCard(String title, String subtitle, String price, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: _surfaceLight)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _neonPink, size: 40),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: _textSecondary, fontSize: 12)),
          const Spacer(),
          Text(price, style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
