import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonBlue = Color(0xFF00E5FF);
const Color _textSecondary = Color(0xFF8B9BB4);

class MerchantRoomDetailView extends StatelessWidget {
  const MerchantRoomDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Manage Room 402', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Current Tenants (2/4)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildTenantCard('James O.', 'Paid (Oct)', true),
          _buildTenantCard('Kevin M.', 'Pending (Oct)', false),
          const SizedBox(height: 24),
          const Text('Room Actions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildActionTile('Evict/Remove Tenant', Icons.person_remove, Colors.orange),
          _buildActionTile('Generate Digital Lease', Icons.description, _neonBlue),
          _buildActionTile('Log Damages', Icons.broken_image, _neonBlue),
        ],
      ),
    );
  }

  Widget _buildTenantCard(String name, String status, bool hasPaid) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const CircleAvatar(backgroundColor: _surfaceLight, child: Icon(Icons.person, color: _textSecondary)),
              const SizedBox(width: 16),
              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          Text(status, style: TextStyle(color: hasPaid ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActionTile(String title, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: _surfaceLight)),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 16),
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
