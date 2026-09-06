import 'package:flutter/material.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class MaintenanceTicketsView extends StatelessWidget {
  const MaintenanceTicketsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Maintenance Tickets', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Active Tickets', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildTicketCard('Plumbing Issue', 'Sink 2 is leaking heavily.', 'Urgent', 'Today 9:00 AM'),
          _buildTicketCard('Electrical', 'Flickering lights in dining area.', 'Normal', 'Yesterday'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _neonOrange,
        onPressed: () {},
        child: const Icon(Icons.build, color: Colors.white),
      ),
    );
  }

  Widget _buildTicketCard(String title, String desc, String priority, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(priority == 'Urgent' ? Icons.warning : Icons.settings, color: _neonOrange),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(time, style: const TextStyle(color: _textSecondary, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: _textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
