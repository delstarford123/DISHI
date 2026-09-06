import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class UniversalSupportWidget extends StatefulWidget {
  final String userId;
  final String userRole; // 'student', 'parent', 'vendor', 'driver'

  const UniversalSupportWidget({super.key, required this.userId, required this.userRole});

  @override
  State<UniversalSupportWidget> createState() => _UniversalSupportWidgetState();
}

class _UniversalSupportWidgetState extends State<UniversalSupportWidget> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitTicket() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final url = Uri.parse('https://swapeatbackend.vercel.app/api/v2/support/create_ticket');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'user_role': widget.userRole,
          'message': text,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        if (mounted) {
          _messageController.clear();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Support ticket sent to Admins!')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send ticket. Try again later.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: MPesaTheme.primaryGreen.withOpacity(0.3))),
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.support_agent, color: MPesaTheme.primaryGreen),
                SizedBox(width: 8),
                Text('Admin Support', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Describe your issue here...',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitTicket,
                icon: _isSubmitting 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send, size: 18),
                label: Text(_isSubmitting ? 'Sending...' : 'Send to Admin'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MPesaTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
