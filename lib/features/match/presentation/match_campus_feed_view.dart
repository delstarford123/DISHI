import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonPurple = Color(0xFF9C27B0);
const Color _textSecondary = Color(0xFF8B9BB4);

class MatchCampusFeedView extends StatelessWidget {
  const MatchCampusFeedView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Campus Feed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPostCard('Sarah Kamau', 'Who is down for a coffee date at Highland Cafe? ☕', '10 mins ago', 24),
          _buildPostCard('John Doe', 'Any CS majors here? Need a study buddy for the upcoming exams! 💻', '1 hr ago', 5),
          _buildPostCard('Anonymous', 'Crushing on the girl who always sits at the front in Calculus... 😍', '3 hrs ago', 89),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _neonPink,
        onPressed: () {},
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  Widget _buildPostCard(String name, String content, String time, int likes) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: _surfaceLight, child: Text(name[0], style: const TextStyle(color: Colors.white))),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(time, style: const TextStyle(color: _textSecondary, fontSize: 12)),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          Text(content, style: const TextStyle(color: Colors.white, height: 1.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.favorite_border, color: _neonPink, size: 20),
              const SizedBox(width: 8),
              Text('$likes', style: const TextStyle(color: _neonPink)),
              const Spacer(),
              const Icon(Icons.chat_bubble_outline, color: _textSecondary, size: 20),
              const SizedBox(width: 8),
              const Text('Reply', style: TextStyle(color: _textSecondary)),
            ],
          )
        ],
      ),
    );
  }
}
