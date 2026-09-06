import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonBlue = Color(0xFF00E5FF);
const Color _textSecondary = Color(0xFF8B9BB4);

class MerchantTicketingView extends StatelessWidget {
  const MerchantTicketingView({super.key});

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
          _buildTicketCard('Ticket #405 - Leaking Tap', 'Room 102 - Raised 2hrs ago', 'URGENT', Colors.orange),
          _buildTicketCard('Ticket #404 - Broken Bulb', 'Corridor B - Raised 1 day ago', 'PENDING', _neonBlue),
          _buildTicketCard('Ticket #403 - Wi-Fi Down', 'Room 301 - Raised 2 days ago', 'RESOLVED', Colors.green),
        ],
      ),
    );
  }

  Widget _buildTicketCard(String title, String subtitle, String status, Color statusColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: _textSecondary, fontSize: 14)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: _neonBlue)),
                  onPressed: () {},
                  child: const Text('ASSIGN FUNDI', style: TextStyle(color: _neonBlue, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _surfaceLight),
                  onPressed: () {},
                  child: const Text('MARK RESOLVED', style: TextStyle(color: _textSecondary, fontSize: 12)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
