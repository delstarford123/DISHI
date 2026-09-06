import 'package:flutter/material.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonRed = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class AdminDelivView extends StatelessWidget {
  const AdminDelivView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('DeLiv & SOS Monitor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _neonRed.withOpacity(0.1), border: Border.all(color: _neonRed), borderRadius: BorderRadius.circular(16)),
            child: const Row(
              children: [
                Icon(Icons.warning_amber, color: _neonRed, size: 32),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('No Active SOS Alerts', style: TextStyle(color: _neonRed, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('All students are safe.', style: TextStyle(color: _textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Active DeLiv Drivers', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildDriverCard('Michael O.', 'KCE 123G', 'On Trip'),
          _buildDriverCard('Sarah K.', 'KDE 442Y', 'Available'),
        ],
      ),
    );
  }

  Widget _buildDriverCard(String name, String plate, String status) {
    Color statusColor = status == 'On Trip' ? Colors.orange : Colors.green;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.two_wheeler, color: _neonCyan),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(plate, style: const TextStyle(color: _textSecondary, fontSize: 12)),
                ],
              ),
            ],
          ),
          Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}
