import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonBlue = Color(0xFF00E5FF);
const Color _textSecondary = Color(0xFF8B9BB4);

class AddPropertyView extends StatelessWidget {
  const AddPropertyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Add New Property', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Property Details', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildTextField('Property Name (e.g. QWETU Hostels)'),
          _buildTextField('Location (e.g. Madaraka)'),
          _buildTextField('Number of Units', isNumber: true),
          const SizedBox(height: 24),
          const Text('Amenities', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildAmenityChip('Wi-Fi', true),
              _buildAmenityChip('Water Included', false),
              _buildAmenityChip('CCTV', true),
              _buildAmenityChip('Gym', false),
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonBlue, padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: () {},
            child: const Text('SAVE PROPERTY', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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

  Widget _buildAmenityChip(String label, bool isSelected) {
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white)),
      selected: isSelected,
      selectedColor: _neonBlue,
      backgroundColor: _surfaceLight,
      onSelected: (bool selected) {},
    );
  }
}
