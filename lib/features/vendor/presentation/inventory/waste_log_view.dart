import 'package:flutter/material.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class WasteLogView extends StatelessWidget {
  const WasteLogView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Detailed Waste Logs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Recent Spoilage & Shrinkage', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildWasteCard('Overcooked Rice', '0.5 Kg', 'Kitchen Staff Error', 'Today'),
          _buildWasteCard('Spoiled Tomatoes', '2.0 Kg', 'Storage Temperature Issue', 'Yesterday'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _neonOrange,
        onPressed: () {},
        child: const Icon(Icons.delete, color: Colors.white),
      ),
    );
  }

  Widget _buildWasteCard(String item, String quantity, String reason, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.warning, color: Colors.amber),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Reason: $reason', style: const TextStyle(color: _textSecondary, fontSize: 13)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(quantity, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(time, style: const TextStyle(color: _textSecondary, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }
}
