import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonBlue = Color(0xFF00E5FF);
const Color _textSecondary = Color(0xFF8B9BB4);

class MaintenancePortalView extends StatelessWidget {
  const MaintenancePortalView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Maintenance SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Report an Issue', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildIssueCategory('Plumbing', Icons.plumbing),
          _buildIssueCategory('Electrical', Icons.electrical_services),
          _buildIssueCategory('Carpentry', Icons.handyman),
          const SizedBox(height: 24),
          TextField(
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Describe the issue (e.g., Leaking sink in Room 42)...',
              hintStyle: const TextStyle(color: _textSecondary),
              filled: true,
              fillColor: _surfaceLight,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.camera_alt, color: _neonBlue),
            label: const Text('Attach Photo', style: TextStyle(color: _neonBlue, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: _neonBlue), padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonBlue, padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: () {},
            child: const Text('SUBMIT TICKET', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildIssueCategory(String title, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: _neonBlue),
          const SizedBox(width: 16),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
