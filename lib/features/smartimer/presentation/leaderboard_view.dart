import 'package:flutter/material.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class LeaderboardView extends StatelessWidget {
  const LeaderboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Global Leaderboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.privacy_tip, color: _textSecondary),
            tooltip: 'Alias Mode Active',
            onPressed: () {},
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            color: _cardColor,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_fire_department, color: Colors.orange, size: 32),
                SizedBox(width: 12),
                Column(
                  children: [
                    Text('Your Rank: #14', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('24h Focus Time', style: TextStyle(color: _textSecondary, fontSize: 13)),
                  ],
                )
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildLeaderboardRow(1, 'NinjaCoder', '8h 45m', Colors.amber),
                _buildLeaderboardRow(2, 'StudyBeast', '7h 20m', Colors.grey.shade400),
                _buildLeaderboardRow(3, 'GhostProtocol', '6h 50m', Colors.orange.shade700),
                _buildLeaderboardRow(4, 'Delstarford', '5h 10m', _textSecondary),
                _buildLeaderboardRow(5, 'AnonStudent', '4h 30m', _textSecondary),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLeaderboardRow(int rank, String name, String time, Color iconColor) {
    bool isTop3 = rank <= 3;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rank == 4 ? _neonCyan : Colors.transparent, width: rank == 4 ? 1.5 : 0),
      ),
      child: Row(
        children: [
          if (isTop3) Icon(Icons.emoji_events, color: iconColor, size: 24)
          else SizedBox(width: 24, child: Text('#$rank', style: const TextStyle(color: _textSecondary, fontWeight: FontWeight.bold, fontSize: 16))),
          const SizedBox(width: 16),
          Expanded(child: Text(name, style: TextStyle(color: rank == 4 ? _neonCyan : Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
          Text(time, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
