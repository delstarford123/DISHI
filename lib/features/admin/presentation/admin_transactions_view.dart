import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/models/transaction_model.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonRed = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class AdminTransactionsView extends StatefulWidget {
  const AdminTransactionsView({super.key});

  @override
  State<AdminTransactionsView> createState() => _AdminTransactionsViewState();
}

class _AdminTransactionsViewState extends State<AdminTransactionsView> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('System Ledger', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.streamCollection(
          'transactions',
          orderByField: 'timestamp',
          descending: true,
          limit: 100, // Limit to 100 to prevent massive read costs on global ledger
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _neonRed));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No transactions in system.', style: TextStyle(color: _textSecondary)));
          }

          final transactions = snapshot.data!.docs.map((doc) => 
            TransactionModel.fromJson(doc.data() as Map<String, dynamic>, doc.id)
          ).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final tx = transactions[index];
              return _buildTxCard(tx);
            },
          );
        },
      ),
    );
  }

  Widget _buildTxCard(TransactionModel tx) {
    bool isCredit = tx.type == 'topup' || tx.type == 'refund';
    Color amountColor = isCredit ? _neonCyan : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.description, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('ID: ${tx.id.substring(0, 8)} | User: ${tx.studentId.substring(0, 5)}', style: const TextStyle(color: _textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${isCredit ? '+' : '-'} Ksh ${tx.amount.toStringAsFixed(2)}', style: TextStyle(color: amountColor, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                tx.timestamp != null 
                  ? '${tx.timestamp!.hour}:${tx.timestamp!.minute.toString().padLeft(2, '0')}' 
                  : 'Now',
                style: const TextStyle(color: _textSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
