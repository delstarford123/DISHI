import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/services/api_config.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/preorder_model.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class VendorKdsView extends StatefulWidget {
  const VendorKdsView({super.key});

  @override
  State<VendorKdsView> createState() => _VendorKdsViewState();
}

class _VendorKdsViewState extends State<VendorKdsView> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('preorders').doc(orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }


  Future<void> _showCourierHandoffDialog(PreorderModel order) async {
    final expectedPin = order.vendorPickupPin ?? '';
    final pinController = TextEditingController(text: expectedPin);
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.verified_user, color: _neonCyan),
              SizedBox(width: 10),
              Text('Courier Handover', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Verify the DeLiv rider at your counter matches this order before handing over goods.',
                style: TextStyle(color: _textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 14),
              if (order.driverName != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFF0C101B),
                        radius: 18,
                        child: Icon(Icons.two_wheeler, color: _neonOrange, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(order.driverName!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(order.driverVehicle ?? 'DISHI Courier', style: const TextStyle(color: _textSecondary, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withAlpha(120)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Expected Courier PIN:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          Text(expectedPin.isNotEmpty ? expectedPin : 'Ask Rider',
                            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Rider PIN',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _surfaceLight,
                  prefixIcon: const Icon(Icons.pin, color: _neonCyan),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _neonCyan,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isSubmitting ? null : () async {
                final enteredPin = pinController.text.trim();
                if (enteredPin.isEmpty) return;
                setDialogState(() => isSubmitting = true);

                try {
                  final resp = await http.post(
                    Uri.parse(ApiConfig.campusGigsVerifyHandoff),
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode({
                      'order_id': order.id,
                      'vendor_id': _currentUserId,
                      'vendor_pickup_pin': enteredPin,
                    }),
                  ).timeout(const Duration(seconds: 30));

                  Navigator.pop(dCtx);

                  if (resp.statusCode == 200) {
                    await _updateOrderStatus(order.id, 'in_transit');
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text('✅ Handover confirmed! Food/goods handed to courier.'), backgroundColor: _neonCyan),
                      );
                    }
                  } else {
                    String msg = 'Invalid pickup PIN';
                    try {
                      final p = json.decode(resp.body);
                      msg = p['error'] ?? resp.body;
                    } catch (_) {}
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text('Error: $msg'), backgroundColor: Colors.redAccent),
                      );
                    }
                  }
                } on TimeoutException {
                  Navigator.pop(dCtx);
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('Request timed out. Please try again.'), backgroundColor: Colors.redAccent),
                    );
                  }
                } catch (e) {
                  Navigator.pop(dCtx);
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              },
              child: Text(isSubmitting ? 'Verifying...' : 'Confirm Handover', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vendorUid = _currentUserId.isEmpty ? 'MOCK_ID' : _currentUserId;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Live Kitchen Queue (KDS)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('preorders')
            .where('vendorId', isEqualTo: vendorUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: _neonOrange));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }

          final docs = snapshot.data?.docs ?? [];
          final orders = docs.map((doc) => 
            PreorderModel.fromJson(Map<String, dynamic>.from(doc.data() as Map), doc.id)
          ).toList();

          final activeOrders = orders.where((o) => o.status != 'fulfilled' && o.status != 'completed' && o.status != 'cancelled').toList();

          if (activeOrders.isEmpty) return _buildEmptyState();

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: activeOrders.length,
            itemBuilder: (context, index) {
              return _buildOrderTicket(activeOrders[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.kitchen, size: 64, color: _textSecondary),
          SizedBox(height: 16),
          Text('No active orders', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Waiting for student pre-orders...', style: TextStyle(color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _buildOrderTicket(PreorderModel order) {
    bool isPending = order.status == 'pending';
    bool isPreparing = order.status == 'preparing';
    bool isReady = order.status == 'ready';
    bool isInTransit = order.status == 'in_transit';
    bool isCourier = order.fulfillmentType == 'deliv_courier' || order.delivRequestId != null;

    Color accentColor = isPending ? Colors.amber : (isPreparing ? _neonCyan : (isInTransit ? Colors.purpleAccent : _neonOrange));

    final String displayOrderNum = order.id.length >= 5 ? order.id.substring(0, 5).toUpperCase() : order.id.toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(color: accentColor.withOpacity(0.12), blurRadius: 10, spreadRadius: 1),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.18),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('#$displayOrderNum', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 12)),
                    if (isCourier) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.two_wheeler, color: _neonOrange, size: 12),
                    ],
                  ],
                ),
                Text(
                  '${order.pickupTime.hour}:${order.pickupTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: _neonCyan, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.studentName.isNotEmpty ? order.studentName : 'Student',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isCourier)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _neonOrange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping, color: _neonOrange, size: 12),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        order.driverName != null ? 'Rider: ${order.driverName}' : 'Awaiting Courier...',
                        style: const TextStyle(color: _neonOrange, fontSize: 10, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${order.quantity}x', style: TextStyle(color: accentColor, fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    order.mealName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('Ksh ${order.price.toStringAsFixed(0)}', style: const TextStyle(color: _textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                if (isPending) {
                  _updateOrderStatus(order.id, 'preparing');
                } else if (isPreparing) {
                  _updateOrderStatus(order.id, 'ready');
                } else if (isReady && isCourier) {
                  _showCourierHandoffDialog(order);
                } else if (isInTransit) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Order is currently with courier in transit.'), backgroundColor: Colors.purpleAccent),
                  );
                } else {
                  _updateOrderStatus(order.id, 'fulfilled');
                }
              },
              child: Text(
                isPending
                    ? 'START PREP'
                    : (isPreparing
                        ? 'MARK READY'
                        : (isReady && isCourier
                            ? 'VERIFY HANDOVER'
                            : (isInTransit ? 'IN TRANSIT 🛵' : 'FULFILL'))),
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          )
        ],
      ),
    );
  }
}
