import 'package:flutter/material.dart';

const Color _neonPink = Color(0xFFFF2A6D);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _cardColor = Color(0xFF131A2A);

class MatchVibeCheckDialog extends StatelessWidget {
  const MatchVibeCheckDialog({super.key});

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
            const Icon(Icons.flash_on, color: _neonPink, size: 64),
            const SizedBox(height: 16),
            const Text('Send a Vibe Check!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Skip the queue and send a direct notification to let them know you are interested.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _neonPink, padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: () => Navigator.pop(context),
                child: const Text('SEND VIBE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
