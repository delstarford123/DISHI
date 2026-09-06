import 'package:flutter/material.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class AnnouncementsView extends StatelessWidget {
  const AnnouncementsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Staff Announcements', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAnnouncementCard('New POS System Update', 'Please remember to restart your POS terminals at the end of the shift today to apply the new updates.', 'Manager', '2 hrs ago'),
          _buildAnnouncementCard('Weekend Rush Prep', 'We are expecting a huge rush this weekend due to the campus event. Ensure all prep stations are fully stocked by Friday evening.', 'Owner', '1 day ago'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _neonOrange,
        onPressed: () {},
        child: const Icon(Icons.add_comment, color: Colors.white),
      ),
    );
  }

  Widget _buildAnnouncementCard(String title, String message, String author, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _surfaceLight),
        boxShadow: [
          BoxShadow(color: _neonOrange.withOpacity(0.05), blurRadius: 10, spreadRadius: 1)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(author, style: const TextStyle(color: _neonOrange, fontWeight: FontWeight.bold, fontSize: 13)),
              Text(time, style: const TextStyle(color: _textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: _textSecondary, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}
