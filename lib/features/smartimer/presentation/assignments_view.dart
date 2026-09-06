import 'package:flutter/material.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class AssignmentsView extends StatelessWidget {
  const AssignmentsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Backward Planning', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Active Assignments', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildAssignmentCard('Software Eng Project', 'Due in 4 Days', 40),
          _buildAssignmentCard('Physics Lab Report', 'Due Tomorrow', 80),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _neonCyan,
        onPressed: () {},
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildAssignmentCard(String title, String dueDate, double progress) {
    bool isUrgent = dueDate.contains('Tomorrow') || dueDate.contains('Today');
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: isUrgent ? _neonPink.withOpacity(0.1) : _neonCyan.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(dueDate, style: TextStyle(color: isUrgent ? _neonPink : _neonCyan, fontWeight: FontWeight.bold, fontSize: 12)),
              )
            ],
          ),
          const SizedBox(height: 16),
          const Text('Micro-Chapters breakdown', style: TextStyle(color: _textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress / 100,
            backgroundColor: _surfaceLight,
            color: isUrgent ? _neonPink : _neonCyan,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(side: const BorderSide(color: _surfaceLight), minimumSize: const Size(double.infinity, 40)),
            child: const Text('View Daily Breakdown', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}
