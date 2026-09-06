import 'package:flutter/material.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class HousekeepingView extends StatelessWidget {
  const HousekeepingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Housekeeping & Waste', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Food Waste Logs', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildLogCard('Leftover Rice', '2 kg', 'Disposed', Icons.delete_outline),
          _buildLogCard('Expired Milk', '1 L', 'Disposed', Icons.warning_amber),
          const SizedBox(height: 32),
          const Text('Maintenance Tickets', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildLogCard('Leaking Sink', 'Kitchen Station 2', 'Pending Repair', Icons.plumbing),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _neonOrange,
        onPressed: () {},
        child: const Icon(Icons.add_task, color: Colors.white),
      ),
    );
  }

  Widget _buildLogCard(String title, String detail, String status, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: _neonOrange),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(detail, style: const TextStyle(color: _textSecondary, fontSize: 14)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(8)),
            child: Text(status, style: const TextStyle(color: _textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}
