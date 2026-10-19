import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../../../core/models/user_model.dart';
import '../../../core/services/api_config.dart';
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => _VendorMenuView(vendor: vendor)));
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

          final vendors = snapshot.data!.docs
              .where((d) => d.data() != null)
              .map((d) => UserModel.fromJson(Map<String, dynamic>.from(d.data() as Map), d.id))
              .toList();

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

class _VendorMenuView extends StatefulWidget {
  final UserModel vendor;
  const _VendorMenuView({required this.vendor});

  @override
  State<_VendorMenuView> createState() => _VendorMenuViewState();
}

class _VendorMenuViewState extends State<_VendorMenuView> {
  TimeOfDay _pickupTime = const TimeOfDay(hour: 12, minute: 30);
  bool _isSubmitting = false;

  void _submitOrder(Map<String, dynamic> item) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSubmitting = true);

    try {
      final now = DateTime.now();
      final pickupDateTime = DateTime(now.year, now.month, now.day, _pickupTime.hour, _pickupTime.minute);
      final String orderId = const Uuid().v4();
      final double totalCost = (item['price'] as num).toDouble();
      final String timestamp = DateTime.now().toUtc().toIso8601String();

      // Sign request with HMAC matching backend transaction_routes.py
      final rawData = '$uid:$totalCost:${widget.vendor.uid}:$orderId:$timestamp';
      final hmac = Hmac(sha256, utf8.encode('super-secret-vendor-key'));
      final signature = hmac.convert(utf8.encode(rawData)).toString();

      final payload = {
        'uid': uid,
        'amount': totalCost,
        'vendorId': widget.vendor.uid,
        'vendorName': widget.vendor.displayName,
        'mealName': item['name'],
        'txId': orderId,
        'timestamp': timestamp,
        'signature': signature,
        'dayOfWeek': 'Today',
        'pickupTime': pickupDateTime.toIso8601String(),
      };

      final response = await http.post(
        Uri.parse(ApiConfig.transactionPreorder),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Preorder paid & placed successfully!'),
              backgroundColor: _neonCyan,
            ),
          );
        }
      } else {
        String errMsg = 'Failed to place preorder';
        try {
          final parsed = jsonDecode(response.body);
          errMsg = parsed['error'] ?? 'Server error (${response.statusCode})';
        } catch (_) {
          errMsg = 'Server returned error (${response.statusCode})';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errMsg), backgroundColor: Colors.red),
          );
        }
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request timed out. Please check your internet connection.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error placing order: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showCheckoutDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: _cardColor,
              title: Text('Checkout: ${item['name']}', style: const TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Price: Ksh ${item['price']}', style: const TextStyle(color: _neonCyan, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('Pickup Time', style: TextStyle(color: Colors.white)),
                  TextButton(
                    onPressed: () async {
                      final t = await showTimePicker(context: context, initialTime: _pickupTime);
                      if (t != null) setStateDialog(() => _pickupTime = t);
                    },
                    child: Text(_pickupTime.format(context), style: const TextStyle(color: _neonCyan, fontSize: 16, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
                  onPressed: () {
                    Navigator.pop(context);
                    _submitOrder(item);
                  },
                  child: const Text('Confirm Preorder', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text('${widget.vendor.displayName} Menu', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isSubmitting 
        ? const Center(child: CircularProgressIndicator(color: _neonCyan))
        : StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('vendor_menus').where('vendorId', isEqualTo: widget.vendor.uid).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _neonCyan));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('This vendor has no menu items yet.', style: TextStyle(color: _textSecondary)));
              }

              final items = snapshot.data!.docs;
              
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final data = items[index].data() as Map<String, dynamic>;
                  final imageUrl = data['imageUrl'] as String?;
                  
                  return Card(
                    color: _cardColor,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: (imageUrl != null && imageUrl.isNotEmpty)
                              ? Image.network(imageUrl, fit: BoxFit.cover)
                              : Container(color: Colors.black26, child: const Icon(Icons.fastfood, color: Colors.white54, size: 40)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Ksh ${data['price']}', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold)),
                                  GestureDetector(
                                    onTap: () => _showCheckoutDialog(data),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: _neonCyan, borderRadius: BorderRadius.circular(4)),
                                      child: const Text('Buy', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                  )
                                ],
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                },
              );
            },
          ),
    );
  }
}
