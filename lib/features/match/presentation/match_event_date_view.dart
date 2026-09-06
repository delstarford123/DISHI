import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonPurple = Color(0xFF9C27B0);
const Color _textSecondary = Color(0xFF8B9BB4);

class MatchEventDateView extends StatelessWidget {
  const MatchEventDateView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Campus Events', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildEventCard('Freshers Bash 2026', 'Carnivore Grounds', 'Oct 20, 8:00 PM', '25 Matches attending'),
          _buildEventCard('Tech Meetup', 'iHub Nairobi', 'Oct 22, 2:00 PM', '10 Matches attending'),
        ],
      ),
    );
  }

  Widget _buildEventCard(String title, String location, String time, String matches) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            decoration: const BoxDecoration(
              color: _surfaceLight,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: const Center(child: Icon(Icons.event, size: 60, color: _textSecondary)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: _neonPink, size: 16),
                    const SizedBox(width: 4),
                    Text(location, style: const TextStyle(color: _textSecondary)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, color: _neonPurple, size: 16),
                    const SizedBox(width: 4),
                    Text(time, style: const TextStyle(color: _textSecondary)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(matches, style: const TextStyle(color: _neonPink, fontWeight: FontWeight.bold, fontSize: 12)),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _neonPink),
                      onPressed: () {},
                      child: const Text('FIND DATE', style: TextStyle(color: Colors.white)),
                    )
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
