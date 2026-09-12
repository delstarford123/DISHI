import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _neonPink = Color(0xFFFF2A6D);
const Color _cardColor = Color(0xFF131A2A);

class MatchSecretAdmirerDialog extends StatefulWidget {
  final Map<String, dynamic>? userModel;
  final String targetUid;

  const MatchSecretAdmirerDialog({super.key, this.userModel, required this.targetUid});

  @override
  State<MatchSecretAdmirerDialog> createState() => _MatchSecretAdmirerDialogState();
}

class _MatchSecretAdmirerDialogState extends State<MatchSecretAdmirerDialog> {
  bool _isSending = false;
  final TextEditingController _crushNameController = TextEditingController();
  final TextEditingController _hintController = TextEditingController();

  Future<void> _sendCrush() async {
    if (_crushNameController.text.trim().isEmpty) return;
    setState(() => _isSending = true);

    try {
      await FirebaseFirestore.instance.collection('secret_admirers').add({
        'crushName': _crushNameController.text.trim(),
        'hint': _hintController.text.trim(),
        'senderUid': 'anonymous',
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Secret crush sent! Shhh... 🤫')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
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
            const Icon(Icons.visibility_off, color: _neonPink, size: 64),
            const SizedBox(height: 16),
            const Text('Send Secret Vibe', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Your identity will be hidden until they vibe back. Available to Premium members only.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _neonPink, padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: _isSending ? null : _sendCrush,
                child: _isSending 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white)) 
                    : const Text('SEND ANONYMOUSLY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
