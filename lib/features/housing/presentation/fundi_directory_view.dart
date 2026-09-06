import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonBlue = Color(0xFF00E5FF);
const Color _textSecondary = Color(0xFF8B9BB4);

class FundiDirectoryView extends StatelessWidget {
  const FundiDirectoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Fundi Directory', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search for plumber, electrician...',
              hintStyle: const TextStyle(color: _textSecondary),
              prefixIcon: const Icon(Icons.search, color: _textSecondary),
              filled: true,
              fillColor: _surfaceLight,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          _buildFundiCard('John (Plumber)', '4.8 ★ (120 jobs)', 'KES 500/hr'),
          _buildFundiCard('Mike (Electrician)', '4.9 ★ (89 jobs)', 'KES 600/hr'),
          _buildFundiCard('Sarah (Cleaning)', '5.0 ★ (200 jobs)', 'KES 300/hr'),
        ],
      ),
    );
  }

  Widget _buildFundiCard(String name, String rating, String rate) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const CircleAvatar(backgroundColor: _surfaceLight, child: Icon(Icons.handyman, color: _textSecondary)),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(rating, style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(rate, style: const TextStyle(color: _neonBlue, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _neonBlue, borderRadius: BorderRadius.circular(20)),
                child: const Text('HIRE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
              )
            ],
          )
        ],
      ),
    );
  }
}
