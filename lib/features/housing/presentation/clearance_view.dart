import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonBlue = Color(0xFF00E5FF);
const Color _textSecondary = Color(0xFF8B9BB4);

class ClearanceView extends StatelessWidget {
  const ClearanceView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Move-Out Clearance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange)),
            child: const Column(
              children: [
                Icon(Icons.pending_actions, color: Colors.orange, size: 40),
                SizedBox(height: 12),
                Text('Clearance Pending', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 18)),
                SizedBox(height: 8),
                Text('You must complete the checklist before receiving your deposit refund.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Checklist', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildCheckItem('Hand over keys to caretaker', true),
          _buildCheckItem('Room inspection (Walls & Floor)', false),
          _buildCheckItem('Clear outstanding utility bills', true),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _surfaceLight, padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: null,
            child: const Text('REQUEST DEPOSIT REFUND', style: TextStyle(color: _textSecondary, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildCheckItem(String title, bool isDone) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked, color: isDone ? Colors.green : _textSecondary),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: TextStyle(color: isDone ? Colors.white : _textSecondary))),
        ],
      ),
    );
  }
}
