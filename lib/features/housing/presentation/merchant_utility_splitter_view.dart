import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonBlue = Color(0xFF00E5FF);
const Color _textSecondary = Color(0xFF8B9BB4);

class MerchantUtilitySplitterView extends StatelessWidget {
  const MerchantUtilitySplitterView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Distribute Utilities', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Create New Bill', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildTextField('Bill Name (e.g. Oct Water Bill)'),
          _buildTextField('Total Amount (KES)', isNumber: true),
          const SizedBox(height: 16),
          const Text('Select Target Rooms', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildRoomSelector('Room 101', true),
          _buildRoomSelector('Room 102', true),
          _buildRoomSelector('Room 103', false),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonBlue, padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: () {},
            child: const Text('SPLIT & SEND INVOICES', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildTextField(String hint, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: hint,
          labelStyle: const TextStyle(color: _textSecondary),
          filled: true,
          fillColor: _surfaceLight,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildRoomSelector(String room, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
      child: CheckboxListTile(
        title: Text(room, style: const TextStyle(color: Colors.white)),
        activeColor: _neonBlue,
        checkColor: Colors.black,
        value: isSelected,
        onChanged: (val) {},
      ),
    );
  }
}
