import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _neonPink = Color(0xFFFF2A6D);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _cardColor = Color(0xFF131A2A);

class MatchFeedbackDialog extends StatefulWidget {
  const MatchFeedbackDialog({super.key});

  @override
  State<MatchFeedbackDialog> createState() => _MatchFeedbackDialogState();
}

class _MatchFeedbackDialogState extends State<MatchFeedbackDialog> {
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitFeedback() async {
    final text = _feedbackController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('match_feedback').add({
        'feedback': text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anonymous feedback submitted. Thank you.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
            const Icon(Icons.security, color: Colors.blueAccent, size: 64),
            const SizedBox(height: 16),
            const Text('Anonymous Feedback', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Report issues or give feedback to admins. This is completely anonymous to keep the community safe.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            TextField(
              controller: _feedbackController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Describe the issue...',
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: _isSubmitting ? null : _submitFeedback,
                child: _isSubmitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                    : const Text('SUBMIT SAFELY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
