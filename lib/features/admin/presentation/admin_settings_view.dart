import 'package:flutter/material.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonRed = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class AdminSettingsView extends StatelessWidget {
  const AdminSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('System Config', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Security Limits', style: TextStyle(color: _neonRed, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildSettingTile('Max Wallet Limit (CBK)', 'KES 3,000.00'),
          _buildSettingTile('Daily PIN-less Limit', 'KES 200.00'),
          const SizedBox(height: 24),
          const Text('Platform Fees', style: TextStyle(color: _neonCyan, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildSettingTile('Vendor Commission', '1.5%'),
          _buildSettingTile('Fundi Juaji Fee', '1.5%'),
          _buildSettingTile('Housing Booking Fee', 'KES 1,500.00'),
        ],
      ),
    );
  }

  Widget _buildSettingTile(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        trailing: Text(value, style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}
