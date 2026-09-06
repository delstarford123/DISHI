import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _textSecondary = Color(0xFF8B9BB4);

class NutritionalHeatmap extends StatelessWidget {
  const NutritionalHeatmap({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Nutritional Heatmap', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Weekly Food Categories', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildCategoryBar('Fast Food (Fries, Burgers)', 0.6, _neonPink),
          _buildCategoryBar('Beverages (Soda, Juice)', 0.2, Colors.orange),
          _buildCategoryBar('Healthy (Salad, Veggies)', 0.1, _neonCyan),
          _buildCategoryBar('Staples (Rice, Ugali)', 0.4, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildCategoryBar(String title, double percentage, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('${(percentage * 100).toInt()}%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: _surfaceLight,
            color: color,
            minHeight: 12,
            borderRadius: BorderRadius.circular(6),
          )
        ],
      ),
    );
  }
}
