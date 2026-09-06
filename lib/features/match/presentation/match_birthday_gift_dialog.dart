import 'package:flutter/material.dart';

const Color _neonPink = Color(0xFFFF2A6D);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _cardColor = Color(0xFF131A2A);

class MatchBirthdayGiftDialog extends StatelessWidget {
  const MatchBirthdayGiftDialog({super.key});

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
            const Icon(Icons.cake, color: _neonPink, size: 64),
            const SizedBox(height: 16),
            const Text('Send a Birthday Gift', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Buy them a coffee or a meal directly via DISHI.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            TextField(
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Amount (KES)',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: _surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _neonPink, padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: () => Navigator.pop(context),
                child: const Text('SEND GIFT NOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
