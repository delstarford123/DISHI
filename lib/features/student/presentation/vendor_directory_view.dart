import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/user_model.dart';
import 'package:uuid/uuid.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _textSecondary = Color(0xFF8B9BB4);

class VendorDirectoryView extends StatefulWidget {
  const VendorDirectoryView({super.key});

  @override
  State<VendorDirectoryView> createState() => _VendorDirectoryViewState();
}

class _VendorDirectoryViewState extends State<VendorDirectoryView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _showPreorderDialog(UserModel vendor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _PreorderSheet(vendor: vendor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Vendor Directory', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('users').where('roles', arrayContains: 'vendor').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _neonCyan));
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading vendors', style: TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No vendors available right now.', style: TextStyle(color: _textSecondary, fontSize: 16)),
            );
          }

          final vendors = snapshot.data!.docs.map((d) => UserModel.fromJson(d.data() as Map<String, dynamic>, d.id)).toList();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: vendors.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final vendor = vendors[index];
              return ListTile(
                tileColor: _cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: CircleAvatar(
                  backgroundColor: _neonCyan.withOpacity(0.2),
                  backgroundImage: vendor.profileImageUrl != null ? NetworkImage(vendor.profileImageUrl!) : null,
                  child: vendor.profileImageUrl == null ? const Icon(Icons.store, color: _neonCyan) : null,
                ),
                title: Text(vendor.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Tap to preorder meals', style: TextStyle(color: _textSecondary, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, color: _neonCyan, size: 16),
                onTap: () => _showPreorderDialog(vendor),
              );
            },
          );
        },
      ),
    );
  }
}

class _PreorderSheet extends StatefulWidget {
  final UserModel vendor;
  const _PreorderSheet({required this.vendor});

  @override
  State<_PreorderSheet> createState() => _PreorderSheetState();
}

class _PreorderSheetState extends State<_PreorderSheet> {
  final _mealController = TextEditingController(text: 'Ugali Nyama');
  int _quantity = 1;
  double _pricePerItem = 250.0;
  TimeOfDay _pickupTime = const TimeOfDay(hour: 12, minute: 30);
  bool _isSubmitting = false;

  void _submitOrder() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSubmitting = true);

    try {
      final now = DateTime.now();
      final pickupDateTime = DateTime(now.year, now.month, now.day, _pickupTime.hour, _pickupTime.minute);
      final String orderId = const Uuid().v4();

      await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
        'vendor_id': widget.vendor.uid,
        'vendor_name': widget.vendor.displayName,
        'student_id': uid,
        'meal_name': _mealController.text,
        'quantity': _quantity,
        'price': _pricePerItem * _quantity,
        'pickupTime': Timestamp.fromDate(pickupDateTime),
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preorder placed! Waiting for vendor approval.'), backgroundColor: _neonCyan));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error placing order: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Preorder from ${widget.vendor.displayName}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _mealController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Meal Item (Mocked for now)',
              labelStyle: TextStyle(color: _textSecondary),
              filled: true,
              fillColor: Color(0xFF1A2235),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Quantity', style: TextStyle(color: Colors.white, fontSize: 16)),
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.remove_circle_outline, color: _neonCyan), onPressed: () => setState(() => _quantity = _quantity > 1 ? _quantity - 1 : 1)),
                  Text('$_quantity', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.add_circle_outline, color: _neonCyan), onPressed: () => setState(() => _quantity++)),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Pickup Time', style: TextStyle(color: Colors.white, fontSize: 16)),
              TextButton(
                onPressed: () async {
                  final t = await showTimePicker(context: context, initialTime: _pickupTime);
                  if (t != null) setState(() => _pickupTime = t);
                },
                child: Text(_pickupTime.format(context), style: const TextStyle(color: _neonCyan, fontSize: 16, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total:', style: TextStyle(color: _textSecondary, fontSize: 18)),
              Text('Ksh ${(_pricePerItem * _quantity).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _neonCyan,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSubmitting ? null : _submitOrder,
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text('Place Preorder', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )
        ],
      ),
    );
  }
}
