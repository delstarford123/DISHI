import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/firestore_service.dart';
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
  final FirestoreService _firestoreService = FirestoreService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    await _firestoreService.updateDocument('orders', orderId, {'status': newStatus});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Live KDS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.streamCollection(
          'orders',
          whereField: 'vendor_id',
          isEqualTo: _currentUserId.isEmpty ? 'MOCK_ID' : _currentUserId,
          orderByField: 'pickupTime',
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _neonOrange));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final orders = snapshot.data!.docs.map((doc) => 
            PreorderModel.fromJson(doc.data() as Map<String, dynamic>, doc.id)
          ).toList();

          final activeOrders = orders.where((o) => o.status == 'pending' || o.status == 'preparing').toList();

          if (activeOrders.isEmpty) return _buildEmptyState();

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
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
          Text('Waiting for students to order...', style: TextStyle(color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _buildOrderTicket(PreorderModel order) {
    bool isPending = order.status == 'pending';
    Color accentColor = isPending ? Colors.amber : _neonOrange;

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Column(
              children: [
                Text('ORDER #${order.id.substring(0, 5).toUpperCase()}', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Pickup: ${order.pickupTime.hour}:${order.pickupTime.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${order.quantity}x', style: const TextStyle(color: _neonCyan, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(order.mealName, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                _updateOrderStatus(order.id, isPending ? 'preparing' : 'ready');
              },
              child: Text(isPending ? 'START PREP' : 'MARK READY', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}
