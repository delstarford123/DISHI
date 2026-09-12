import 'package:flutter/material.dart';
import '../../../core/services/admin_service.dart';

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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('System Ledger (Rich Audit)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: AdminService().getRichTransactions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _neonCyan));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No transactions in system.', style: TextStyle(color: _textSecondary)));
          }

          final transactions = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final tx = transactions[index];
              return _buildRichTxCard(tx);
            },
          );
        },
      ),
    );
  }

  Widget _buildRichTxCard(Map<String, dynamic> tx) {
    bool isCredit = tx['type'] == 'topup' || tx['type'] == 'refund';
    Color amountColor = isCredit ? _neonCyan : Colors.white;
    
    final student = tx['student_data'] ?? {};
    final vendor = tx['vendor_data'] ?? {};
    
    // Determine the primary user info to display based on transaction direction
    Map<String, dynamic> primaryUser = isCredit ? student : (tx['type'] == 'payment' ? vendor : student);
    if (primaryUser.isEmpty && student.isNotEmpty) primaryUser = student; // Fallback

    String name = primaryUser['name'] ?? 'Unknown User';
    String email = primaryUser['email'] ?? 'N/A';
    String phone = primaryUser['phone'] ?? 'N/A';
    String imageUrl = primaryUser['image'] ?? '';
    double amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    String desc = tx['description'] ?? 'Transaction';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: _surfaceLight,
            backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
            child: imageUrl.isEmpty ? const Icon(Icons.person, color: _textSecondary) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(desc, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Text(name, style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.email, color: _textSecondary, size: 12),
                    const SizedBox(width: 4),
                    Expanded(child: Text(email, style: const TextStyle(color: _textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.phone, color: _textSecondary, size: 12),
                    const SizedBox(width: 4),
                    Text(phone, style: const TextStyle(color: _textSecondary, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('TX ID: ${tx['id']?.toString().substring(0, 8) ?? 'N/A'}', style: const TextStyle(color: _surfaceLight, fontSize: 10)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${isCredit ? '+' : '-'} Ksh ${amount.toStringAsFixed(2)}', style: TextStyle(color: amountColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }
}
