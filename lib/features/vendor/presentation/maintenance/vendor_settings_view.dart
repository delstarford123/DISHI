import 'package:flutter/material.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class VendorSettingsView extends StatelessWidget {
  const VendorSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Vendor Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('General Settings', style: TextStyle(color: _neonOrange, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildSettingTile(Icons.store, 'Store Profile', 'Edit store name, hours, and description'),
          _buildSettingTile(Icons.fastfood, 'Menu Management', 'Add, edit, or remove items'),
          const SizedBox(height: 24),
          const Text('Security & Operations', style: TextStyle(color: _neonOrange, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildSettingTile(Icons.security, 'App PIN / Passcode', 'Require PIN for POS actions'),
          _buildSettingTile(Icons.print, 'Receipt Printer', 'Configure Bluetooth thermal printers'),
          const SizedBox(height: 24),
          const Text('Account', style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildSettingTile(Icons.logout, 'Log Out', 'Sign out of Vendor Dashboard', iconColor: Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildSettingTile(IconData icon, String title, String subtitle, {Color iconColor = Colors.white}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icon, color: iconColor),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: _textSecondary, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: _textSecondary),
        onTap: () {},
      ),
    );
  }
}
