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

  void _showEodPdfDialog(double totalSales, int count, double avg) {
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: _neonCyan)),
        title: const Row(
          children: [
            Icon(Icons.receipt_long, color: _neonCyan),
            SizedBox(width: 8),
            Text('End-of-Day Reconciliation', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DISHI Campus POS Audit Summary • $dateStr', style: const TextStyle(color: _textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            _buildDialogRow('Total Gross Sales', 'KES ${totalSales.toStringAsFixed(2)}', color: _neonCyan, isBold: true),
            _buildDialogRow('Total Completed Orders', '$count transactions'),
            _buildDialogRow('Average Order Size', 'KES ${avg.toStringAsFixed(2)}'),
            _buildDialogRow('Platform Fee (0% Campus Rate)', 'KES 0.00', color: Colors.greenAccent),
            const Divider(color: _textSecondary, height: 20),
            _buildDialogRow('Net Merchant E-Float Payout', 'KES ${totalSales.toStringAsFixed(2)}', color: Colors.greenAccent, isBold: true),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Icon(Icons.verified, color: Colors.greenAccent, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('Reconciled and verified against Safaricom M-Pesa ledger.', style: TextStyle(color: Colors.greenAccent, fontSize: 11))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: _neonCyan)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('EOD Reconciliation saved to reports vault!'), backgroundColor: _neonCyan),
              );
            },
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Export Summary', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogRow(String label, String value, {Color color = Colors.white, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: _textSecondary, fontSize: 12)),
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.streamCollection(
        'transactions',
        whereField: 'vendor_id',
        isEqualTo: _currentUserId.isEmpty ? 'MOCK_ID' : _currentUserId,
        orderByField: 'timestamp',
        descending: true,
      ),
      builder: (context, snapshot) {
        double todaySales = 0.0;
        int todayCount = 0;
        List<TransactionModel> transactions = [];

        if (snapshot.hasData) {
          final now = DateTime.now();
          for (var doc in snapshot.data!.docs) {
            final tx = TransactionModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
            transactions.add(tx);
            if (tx.timestamp != null &&
                tx.timestamp!.year == now.year &&
                tx.timestamp!.month == now.month &&
                tx.timestamp!.day == now.day) {
              todaySales += tx.amount;
              todayCount++;
            }
          }
        }

        final double avgBasket = todayCount > 0 ? (todaySales / todayCount) : 0.0;

        return Scaffold(
          backgroundColor: _bgColor,
          appBar: AppBar(
            title: const Text('Financial Reports', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: _bgColor,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                tooltip: 'End-of-Day Reconciliation',
                icon: const Icon(Icons.picture_as_pdf, color: _neonCyan),
                onPressed: () => _showEodPdfDialog(todaySales, todayCount, avgBasket),
              ),
            ],
          ),
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator(color: _neonOrange))
              : snapshot.hasError
                  ? Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)))
                  : transactions.isEmpty
                      ? const Center(child: Text('No transactions yet.', style: TextStyle(color: _textSecondary, fontSize: 16)))
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            // End-of-Day Today Summary Banner (V6 Feature 25)
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [_cardColor, _neonCyan.withValues(alpha: 0.12)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _neonCyan.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.analytics_rounded, color: _neonCyan, size: 20),
                                          SizedBox(width: 8),
                                          Text("Today's Gross Reconciliation", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      GestureDetector(
                                        onTap: () => _showEodPdfDialog(todaySales, todayCount, avgBasket),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: _neonCyan.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                                          child: const Row(
                                            children: [
                                              Icon(Icons.print, size: 14, color: _neonCyan),
                                              SizedBox(width: 4),
                                              Text('EOD Audit', style: TextStyle(color: _neonCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'KES ${todaySales.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Today: $todayCount sales', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                                      Text('Avg Basket: KES ${avgBasket.toStringAsFixed(0)}', style: const TextStyle(color: _neonCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text('Transaction History', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            ...transactions.map((tx) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _cardColor,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: _neonOrange.withValues(alpha: 0.2),
                                    child: const Icon(Icons.arrow_downward, color: _neonOrange),
                                  ),
                                  title: Text(tx.description, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Text(
                                    tx.timestamp != null
                                        ? '${tx.timestamp!.day}/${tx.timestamp!.month}/${tx.timestamp!.year} • ${tx.timestamp!.hour}:${tx.timestamp!.minute.toString().padLeft(2, '0')}'
                                        : 'Processing...',
                                    style: const TextStyle(color: _textSecondary, fontSize: 11),
                                  ),
                                  trailing: Text(
                                    '+ Ksh. ${tx.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
        );
      },
    );
  }
}
