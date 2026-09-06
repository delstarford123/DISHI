import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _textSecondary = Color(0xFF8B9BB4);

class MultiChildHub extends StatelessWidget {
  const MultiChildHub({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Linked Students', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildChildCard('Delstarford', 'MMUST University', 'KES 1,250', true),
          _buildChildCard('Sarah', 'Strathmore University', 'KES 450', false),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.person_add, color: _neonCyan),
            label: const Text('Link Another Student', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: _neonCyan), padding: const EdgeInsets.symmetric(vertical: 16)),
          )
        ],
      ),
    );
  }

  Widget _buildChildCard(String name, String school, String balance, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: isActive ? _neonCyan : Colors.transparent)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: _surfaceLight, child: Text(name[0], style: const TextStyle(color: Colors.white))),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(school, style: const TextStyle(color: _textSecondary, fontSize: 12)),
                ],
              ),
            ],
          ),
          Text(balance, style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
