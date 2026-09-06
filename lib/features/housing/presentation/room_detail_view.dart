import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonBlue = Color(0xFF00E5FF);
const Color _textSecondary = Color(0xFF8B9BB4);

class RoomDetailView extends StatelessWidget {
  final String propertyId;
  final Map<String, dynamic> user;

  const RoomDetailView({super.key, required this.propertyId, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Room 402 - QWETU', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 200,
            decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(16)),
            child: const Center(child: Icon(Icons.bed, size: 80, color: _textSecondary)),
          ),
          const SizedBox(height: 24),
          const Text('Room Features', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildFeatureIcon(Icons.wifi, 'Fast Wi-Fi'),
              _buildFeatureIcon(Icons.shower, 'Hot Shower'),
              _buildFeatureIcon(Icons.security, '24/7 Security'),
            ],
          ),
          const SizedBox(height: 32),
          const Text('Your Roommates', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildRoommateCard('Alex Kamau', 'Hostel Rep'),
          _buildRoommateCard('John Doe', 'Roommate'),
        ],
      ),
    );
  }

  Widget _buildFeatureIcon(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: _neonBlue, size: 32),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: _textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _buildRoommateCard(String name, String role) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const CircleAvatar(backgroundColor: _surfaceLight, child: Icon(Icons.person, color: _textSecondary)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text(role, style: const TextStyle(color: _neonBlue, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }
}
