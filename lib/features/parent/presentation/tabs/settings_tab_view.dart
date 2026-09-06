import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonPink = Color(0xFFF92B60);
const Color _textSecondary = Color(0xFF8B9BB4);

class SettingsTabView extends StatelessWidget {
  final Map<String, dynamic> user;
  
  const SettingsTabView({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Document & ID Vault
        const Text('Document & ID Vault', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Secure storage for school IDs and medical slips.', style: TextStyle(color: _textSecondary, fontSize: 12)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildDocCard('School ID', Icons.badge)),
            const SizedBox(width: 12),
            Expanded(child: _buildDocCard('Insurance', Icons.health_and_safety)),
            const SizedBox(width: 12),
            Expanded(child: _buildDocCard('Upload', Icons.upload_file, isUpload: true)),
          ],
        ),
        
        const SizedBox(height: 32),
        
        // Notifications Center
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Notifications Center', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(onPressed: () {}, child: const Text('Mark all read', style: TextStyle(color: _neonCyan))),
          ],
        ),
        const SizedBox(height: 8),
        _buildNotificationItem('Allergy Warning', 'Attempted purchase of peanuts blocked.', true),
        _buildNotificationItem('Chore Completed', 'John marked "Clean Room" as done.', false),
        _buildNotificationItem('Low Balance', 'Vault balance is below Ksh 1000.', false),
      ],
    );
  }

  Widget _buildDocCard(String title, IconData icon, {bool isUpload = false}) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: isUpload ? Colors.transparent : _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isUpload ? _textSecondary : Colors.transparent, style: isUpload ? BorderStyle.solid : BorderStyle.solid),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isUpload ? _textSecondary : _neonCyan, size: 32),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: isUpload ? _textSecondary : Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(String title, String message, bool isAlert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: isAlert ? Border.all(color: _neonPink.withOpacity(0.5)) : null,
      ),
      child: Row(
        children: [
          Icon(isAlert ? Icons.warning_amber_rounded : Icons.notifications_none, color: isAlert ? _neonPink : _neonCyan),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: isAlert ? _neonPink : Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(color: _textSecondary, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
