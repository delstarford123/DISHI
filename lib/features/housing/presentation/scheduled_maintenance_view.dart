import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonBlue = Color(0xFF00E5FF);
const Color _textSecondary = Color(0xFF8B9BB4);

class ScheduledMaintenanceView extends StatelessWidget {
  const ScheduledMaintenanceView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Maintenance Schedule', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.add, color: _neonBlue), onPressed: () {})
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Upcoming Operations', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildScheduleCard('Water Tank Cleaning', 'Oct 20, 2026', 'Fundi: J&J Cleaners', Colors.blue),
          _buildScheduleCard('Pest Control Fumigation', 'Nov 01, 2026', 'Fundi: SafeHomes Pest', Colors.orange),
          _buildScheduleCard('Fire Extinguisher Service', 'Dec 15, 2026', 'Fundi: FireTech Ltd', Colors.red),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(String title, String date, String fundi, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_note, color: iconColor, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(date, style: const TextStyle(color: _textSecondary, fontSize: 14)),
                const SizedBox(height: 8),
                Text(fundi, style: TextStyle(color: _neonBlue, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
