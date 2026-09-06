import 'package:flutter/material.dart';

const Color _neonPink = Color(0xFFFF2A6D);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _cardColor = Color(0xFF131A2A);

class MatchLoveLanguageDialog extends StatelessWidget {
  const MatchLoveLanguageDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite, color: _neonPink, size: 64),
            const SizedBox(height: 16),
            const Text('Your Love Language', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Select your primary love language to help matches understand you better.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            _buildLanguageOption('Words of Affirmation', true),
            _buildLanguageOption('Quality Time', false),
            _buildLanguageOption('Receiving Gifts', false),
            _buildLanguageOption('Acts of Service', false),
            _buildLanguageOption('Physical Touch', false),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _neonPink, padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: () => Navigator.pop(context),
                child: const Text('SAVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String title, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? _neonPink.withOpacity(0.2) : _surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? _neonPink : Colors.transparent),
      ),
      child: RadioListTile(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        value: isSelected,
        groupValue: true,
        activeColor: _neonPink,
        onChanged: (val) {},
      ),
    );
  }
}
