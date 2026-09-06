import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _textSecondary = Color(0xFF8B9BB4);

class TreatBounties extends StatelessWidget {
  const TreatBounties({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Academic Bounties', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Reward Good Grades', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildBountyCard('Score an A in Calculus', 'KES 1,000 Reward', true),
          _buildBountyCard('10-Day Study Streak', 'KFC Meal Treat', false),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: () {},
            icon: const Icon(Icons.add, color: Colors.black),
            label: const Text('CREATE NEW BOUNTY', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildBountyCard(String title, String reward, bool isCompleted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(reward, style: const TextStyle(color: _neonCyan, fontSize: 12)),
              ],
            ),
          ),
          if (isCompleted)
             const Icon(Icons.check_circle, color: _neonCyan, size: 32)
          else
             const Icon(Icons.pending, color: Colors.orange, size: 32)
        ],
      ),
    );
  }
}
