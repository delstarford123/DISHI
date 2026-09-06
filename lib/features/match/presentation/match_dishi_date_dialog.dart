import 'package:flutter/material.dart';

const Color _neonPink = Color(0xFFFF2A6D);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _cardColor = Color(0xFF131A2A);
const Color _textSecondary = Color(0xFF8B9BB4);

class MatchDishiDateDialog extends StatefulWidget {
  const MatchDishiDateDialog({super.key});

  @override
  State<MatchDishiDateDialog> createState() => _MatchDishiDateDialogState();
}

class _MatchDishiDateDialogState extends State<MatchDishiDateDialog> {
  final TextEditingController _venueController = TextEditingController(text: 'Campus Cafe');
  final TextEditingController _amountController = TextEditingController(text: '500');

  void _submit() {
    final venue = _venueController.text.trim();
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    
    if (venue.isNotEmpty && amount > 0) {
      Navigator.pop(context, {'venue': venue, 'splitAmount': amount});
    }
  }

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
            const Icon(Icons.restaurant, color: Colors.orange, size: 64),
            const SizedBox(height: 16),
            const Text('Propose a DISHI Date', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Suggest a venue and propose a 50/50 wallet split.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            TextField(
              controller: _venueController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Venue Name',
                labelStyle: TextStyle(color: _textSecondary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _surfaceLight)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Your Share (KSH)',
                labelStyle: TextStyle(color: _textSecondary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _surfaceLight)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: _submit,
                child: const Text('SEND DATE PROPOSAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
