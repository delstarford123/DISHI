import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/models/transaction_model.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class VendorReportsView extends StatefulWidget {
  const VendorReportsView({super.key});

  @override
  State<VendorReportsView> createState() => _VendorReportsViewState();
}

class _VendorReportsViewState extends State<VendorReportsView> {
  final FirestoreService _firestoreService = FirestoreService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Transaction Reports', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.streamCollection(
          'transactions',
          whereField: 'vendor_id',
          isEqualTo: _currentUserId.isEmpty ? 'MOCK_ID' : _currentUserId,
          orderByField: 'timestamp',
          descending: true,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _neonOrange));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No transactions yet.', style: TextStyle(color: _textSecondary, fontSize: 16)),
            );
          }

          final transactions = snapshot.data!.docs.map((doc) => 
            TransactionModel.fromJson(doc.data() as Map<String, dynamic>, doc.id)
          ).toList();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            separatorBuilder: (context, index) => const Divider(color: _cardColor, thickness: 2),
            itemBuilder: (context, index) {
              final tx = transactions[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: _neonOrange.withOpacity(0.2),
                  child: const Icon(Icons.arrow_downward, color: _neonOrange),
                ),
                title: Text(tx.description, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(
                  tx.timestamp != null 
                    ? '${tx.timestamp!.day}/${tx.timestamp!.month}/${tx.timestamp!.year} • ${tx.timestamp!.hour}:${tx.timestamp!.minute.toString().padLeft(2, '0')}' 
                    : 'Processing...',
                  style: const TextStyle(color: _textSecondary, fontSize: 12),
                ),
                trailing: Text(
                  '+ Ksh. ${tx.amount.toStringAsFixed(2)}',
                  style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
