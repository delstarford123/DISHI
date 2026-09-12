import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class GiftMealDialog extends StatefulWidget {
  const GiftMealDialog({super.key});

  @override
  State<GiftMealDialog> createState() => _GiftMealDialogState();
}

class _GiftMealDialogState extends State<GiftMealDialog> {
  final _dishiIdController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _sendGift() async {
    final dishiId = _dishiIdController.text.trim();
    final amountText = _amountController.text.trim();
    
    if (dishiId.isEmpty || amountText.isEmpty) {
      setState(() => _errorMessage = 'Please fill all fields');
      return;
    }
    
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'Invalid amount');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });
    
    try {
      final userQuery = await FirebaseFirestore.instance.collection('users').where('dishiId', isEqualTo: dishiId).get();
      if (userQuery.docs.isEmpty) {
        setState(() { _isLoading = false; _errorMessage = 'User with this DISHI ID not found.'; });
        return;
      }
      
      final recipientUid = userQuery.docs.first.id;
      final senderUid = FirebaseAuth.instance.currentUser!.uid;
      
      if (recipientUid == senderUid) {
        setState(() { _isLoading = false; _errorMessage = 'You cannot gift yourself.'; });
        return;
      }
      
      final response = await http.post(
        Uri.parse('https://dishi.delstarfordworks.co.ke/api/v1/match_interactive/gift/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'senderUid': senderUid,
          'recipientUid': recipientUid,
          'amount': amount,
        }),
      ).timeout(const Duration(seconds: 30));
      
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: const Color(0xFF00F0FF), duration: const Duration(seconds: 4)));
        }
      } else {
        setState(() { _errorMessage = data['error'] ?? 'Failed to send gift.'; });
      }
    } catch (e) {
      setState(() { _errorMessage = 'Network error. Please try again.'; });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const cardColor = Color(0xFF1E293B);
    const neonCyan = Color(0xFF00F0FF);
    
    return AlertDialog(
      backgroundColor: cardColor,
      title: const Text('Gift a Meal', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Enter their DISHI ID and amount. Gifts over 100 KSH include a 10 KSH commission.', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 16),
          if (_errorMessage != null)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
          TextField(
            controller: _dishiIdController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Recipient DISHI ID', labelStyle: TextStyle(color: neonCyan), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: neonCyan))),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount (KSH)', labelStyle: TextStyle(color: neonCyan), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: neonCyan))),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendGift,
          style: ElevatedButton.styleFrom(backgroundColor: neonCyan),
          child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) : const Text('Send Gift', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
