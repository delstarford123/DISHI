import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonPurple = Color(0xFF9C27B0);
const Color _textSecondary = Color(0xFF8B9BB4);

class MatchProfileSetup extends StatelessWidget {
  const MatchProfileSetup({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Build Your Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(color: _surfaceLight, shape: BoxShape.circle, border: Border.all(color: _neonPink, width: 2)),
                  child: const Icon(Icons.person, size: 64, color: _textSecondary),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: _neonPink, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text('About Me', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'I love late-night coding and spicy food...',
              hintStyle: const TextStyle(color: _textSecondary),
              filled: true,
              fillColor: _surfaceLight,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          const Text('My Interests', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInterestChip('Anime', true),
              _buildInterestChip('Tech', true),
              _buildInterestChip('Music', false),
              _buildInterestChip('Sports', false),
            ],
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _neonPink,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {},
            child: const Text('ACTIVATE PROFILE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
    );
  }

  Widget _buildInterestChip(String label, bool isSelected) {
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : _textSecondary)),
      selected: isSelected,
      selectedColor: _neonPurple,
      backgroundColor: _surfaceLight,
      onSelected: (bool selected) {},
    );
  }
}
