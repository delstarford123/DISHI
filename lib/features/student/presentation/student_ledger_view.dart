import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/models/transaction_model.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _textSecondary = Color(0xFF8B9BB4);

class StudentLedgerView extends StatefulWidget {
  const StudentLedgerView({super.key});

  @override
  State<StudentLedgerView> createState() => _StudentLedgerViewState();
}

class _StudentLedgerViewState extends State<StudentLedgerView> {
  final FirestoreService _firestoreService = FirestoreService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        title: const Text('Digital Ledger', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: _neonCyan),
            onPressed: () {},
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.streamCollection(
          'transactions',
          whereField: 'student_id',
          isEqualTo: _currentUserId.isEmpty ? 'MOCK_ID' : _currentUserId,
          orderByField: 'timestamp',
          descending: true,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _neonCyan));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading ledger: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final transactions = snapshot.data!.docs.map((doc) => 
            TransactionModel.fromJson(doc.data() as Map<String, dynamic>, doc.id)
          ).toList();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final tx = transactions[index];
              return Dismissible(
                key: Key(tx.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  FirebaseFirestore.instance.collection('transactions').doc(tx.id).delete();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction deleted.')));
                },
                child: _buildTransactionCard(tx),
              );
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
          Icon(Icons.receipt_long, size: 64, color: _textSecondary),
          SizedBox(height: 16),
          Text('No transactions yet.', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('When you pay for a meal, it will appear here.', style: TextStyle(color: _textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(TransactionModel tx) {
    bool isCredit = tx.type == 'topup' || tx.type == 'refund';
    Color amountColor = isCredit ? _neonCyan : Colors.white;
    IconData icon = Icons.payment;
    if (tx.type == 'topup') icon = Icons.account_balance_wallet;
    if (tx.type == 'transfer') icon = Icons.send;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1A2235)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCredit ? _neonCyan.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isCredit ? _neonCyan : Colors.redAccent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.description, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  tx.timestamp != null 
                    ? '${tx.timestamp!.day}/${tx.timestamp!.month}/${tx.timestamp!.year} • ${tx.timestamp!.hour}:${tx.timestamp!.minute.toString().padLeft(2, '0')}' 
                    : 'Processing...',
                  style: const TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'} Ksh. ${tx.amount.toStringAsFixed(2)}',
            style: TextStyle(color: amountColor, fontWeight: FontWeight.bold, fontSize: 16),
          )
        ],
      ),
    );
  }
}
