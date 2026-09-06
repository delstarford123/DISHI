import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonBlue = Color(0xFF00E5FF);
const Color _textSecondary = Color(0xFF8B9BB4);

class AvailableAlertsView extends StatelessWidget {
  const AvailableAlertsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Housing Alerts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAlertCard('Water Disconnection', 'Water will be disconnected on Friday from 10 AM to 2 PM for tank cleaning.', Icons.water_drop, Colors.orange),
          _buildAlertCard('Rent Reminder', 'Rent for November is due in 3 days. Pay on time to keep your streak!', Icons.payment, _neonBlue),
          _buildAlertCard('Maintenance Done', 'Your plumbing ticket #402 has been resolved.', Icons.check_circle, Colors.green),
        ],
      ),
    );
  }

  Widget _buildAlertCard(String title, String desc, IconData icon, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: iconColor.withOpacity(0.5))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: iconColor, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text(desc, style: const TextStyle(color: Colors.white, height: 1.4)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
