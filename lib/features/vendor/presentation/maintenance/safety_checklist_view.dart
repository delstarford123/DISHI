import 'package:flutter/material.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class SafetyChecklistView extends StatelessWidget {
  const SafetyChecklistView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Daily Safety Checklist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Morning Prep Checklist', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildCheckItem('Fire extinguishers accessible', true),
          _buildCheckItem('Fridges at correct temperature (< 4°C)', false),
          _buildCheckItem('All floors dry and clean', true),
          _buildCheckItem('First aid kit stocked', false),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String title, bool isChecked) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isChecked ? _neonOrange.withOpacity(0.5) : _surfaceLight),
      ),
      child: CheckboxListTile(
        value: isChecked,
        onChanged: (bool? value) {},
        title: Text(title, style: TextStyle(color: isChecked ? Colors.white : _textSecondary, decoration: isChecked ? TextDecoration.lineThrough : null)),
        activeColor: _neonOrange,
        checkColor: Colors.white,
      ),
    );
  }
}
