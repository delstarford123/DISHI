import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonBlue = Color(0xFF00E5FF);
const Color _textSecondary = Color(0xFF8B9BB4);

class GatePassHistoryView extends StatelessWidget {
  const GatePassHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Gate Pass Log', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPassCard('TV Installation (Fundi)', 'Oct 14, 2026 - 14:00', 'Approved'),
          _buildPassCard('Friend Visit (Sarah)', 'Oct 12, 2026 - 18:30', 'Expired'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _neonBlue,
        onPressed: () {},
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('NEW GATE PASS', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildPassCard(String title, String time, String status) {
    bool isActive = status == 'Approved';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(time, style: const TextStyle(color: _textSecondary, fontSize: 12)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: isActive ? Colors.green.withOpacity(0.1) : _surfaceLight, borderRadius: BorderRadius.circular(8)),
            child: Text(status, style: TextStyle(color: isActive ? Colors.green : _textSecondary, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}
