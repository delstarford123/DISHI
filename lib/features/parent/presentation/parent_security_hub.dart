import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _textSecondary = Color(0xFF8B9BB4);

class ParentSecurityHub extends StatelessWidget {
  const ParentSecurityHub({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Security Hub', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHubCard(Icons.warning, 'Compromised Alerts', '0 Active Alerts', _neonCyan),
          _buildHubCard(Icons.location_on, 'Location Outliers', '1 Flagged Transaction', Colors.orange),
          _buildHubCard(Icons.devices, 'Active Devices', '2 Devices logged in', _neonPink),
        ],
      ),
    );
  }

  Widget _buildHubCard(IconData icon, String title, String subtitle, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(color: _textSecondary, fontSize: 12)),
            ],
          ),
          const Spacer(),
          const Icon(Icons.arrow_forward_ios, color: _surfaceLight, size: 16)
        ],
      ),
    );
  }
}
