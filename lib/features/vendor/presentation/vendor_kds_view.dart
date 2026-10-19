import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/preorder_model.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
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
    Color accentColor = isPending ? Colors.amber : (isPreparing ? _neonCyan : _neonOrange);

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
                Text('#$displayOrderNum', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 12)),
                Text(
                  '${order.pickupTime.hour}:${order.pickupTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                } else {
                  _updateOrderStatus(order.id, 'fulfilled');
                }
              },
              child: Text(
                isPending ? 'START PREP' : (isPreparing ? 'MARK READY' : 'FULFILL'),
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          )
        ],
      ),
    );
  }
}
