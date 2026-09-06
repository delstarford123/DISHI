import 'package:flutter/material.dart';
import 'daily_focus_view.dart';
import 'flashcards_view.dart';
import 'leaderboard_view.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _textSecondary = Color(0xFF8B9BB4);

class AcademicSetupView extends StatelessWidget {
  const AcademicSetupView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('SmartI Setup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Configure Semester', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildSetupField('Academic Year', 'e.g. 2026/2027'),
            const SizedBox(height: 12),
            _buildSetupField('Semester', 'e.g. Semester 1'),
            const SizedBox(height: 24),
            
            const Text('Current Units & Targets', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildUnitCard('Data Structures', 'Target: A (75%)'),
            _buildUnitCard('Software Engineering', 'Target: B (65%)'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, color: _neonCyan),
              label: const Text('Add Unit', style: TextStyle(color: _neonCyan)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _neonCyan),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 32),
            
            const Text('SmartI Hub', style: TextStyle(color: _neonPink, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildQuickNav(context, Icons.timer, 'Daily Focus', const DailyFocusView(), _neonPink),
            _buildQuickNav(context, Icons.style, 'Flashcards', const FlashcardsView(), Colors.purpleAccent),
            _buildQuickNav(context, Icons.leaderboard, 'Leaderboard', const LeaderboardView(), Colors.amber),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupField(String label, String hint) {
    return TextField(
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textSecondary),
        hintText: hint,
        hintStyle: TextStyle(color: _textSecondary.withOpacity(0.5)),
        filled: true,
        fillColor: _surfaceLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildUnitCard(String title, String target) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(target, style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildQuickNav(BuildContext context, IconData icon, String title, Widget destination, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => destination)),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _surfaceLight),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 16),
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
