import 'package:flutter/material.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class StaffDirectoryView extends StatelessWidget {
  const StaffDirectoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Staff Directory', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStaffCard('Alice Johnson', 'Cashier', '0712 345 678', true),
          _buildStaffCard('Bob Smith', 'Chef', '0723 456 789', true),
          _buildStaffCard('Charlie Davis', 'Cleaner', '0734 567 890', false),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _neonOrange,
        onPressed: () {},
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }

  Widget _buildStaffCard(String name, String role, String phone, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _surfaceLight),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _neonOrange.withOpacity(0.2),
            child: Text(name[0], style: const TextStyle(color: _neonOrange, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(role, style: const TextStyle(color: _neonOrange, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(phone, style: const TextStyle(color: _textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isActive ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(isActive ? 'Active' : 'Offline', style: TextStyle(color: isActive ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
