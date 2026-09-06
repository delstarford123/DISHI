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

class StudentPreordersView extends StatefulWidget {
  const StudentPreordersView({super.key});

  @override
  State<StudentPreordersView> createState() => _StudentPreordersViewState();
}

class _StudentPreordersViewState extends State<StudentPreordersView> {
  final FirestoreService _firestoreService = FirestoreService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        title: const Text('My Pre-orders', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.streamCollection(
          'orders',
          whereField: 'student_id',
          isEqualTo: _currentUserId.isEmpty ? 'MOCK_ID' : _currentUserId,
          orderByField: 'pickupTime',
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _neonCyan));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading orders: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final orders = snapshot.data!.docs.map((doc) => 
            PreorderModel.fromJson(doc.data() as Map<String, dynamic>, doc.id)
          ).toList();

          // Filter out completed ones unless we want history
          final activeOrders = orders.where((o) => o.status != 'completed' && o.status != 'cancelled').toList();

          if (activeOrders.isEmpty) return _buildEmptyState();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: activeOrders.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _buildOrderCard(activeOrders[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.fastfood_outlined, size: 64, color: _textSecondary),
          const SizedBox(height: 16),
          const Text('No active pre-orders', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Skip the lines by ordering ahead.', style: TextStyle(color: _textSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _neonCyan,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context); // Go back to dashboard
            },
            child: const Text('Browse Vendors', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildOrderCard(PreorderModel order) {
    Color statusColor = _neonCyan;
    if (order.status == 'preparing') statusColor = _neonOrange;
    if (order.status == 'pending') statusColor = Colors.amber;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: statusColor.withOpacity(0.1), blurRadius: 10, spreadRadius: 1)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(order.vendorName, style: const TextStyle(color: _textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(order.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${order.quantity}x ${order.mealName}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Ksh ${order.price.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.schedule, color: _textSecondary, size: 16),
              const SizedBox(width: 6),
              Text(
                'Pickup at ${order.pickupTime.hour}:${order.pickupTime.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: _textSecondary, fontSize: 14),
              ),
              const Spacer(),
              if (order.status == 'ready')
                const Icon(Icons.qr_code, color: _neonCyan),
            ],
          )
        ],
      ),
    );
  }
}
