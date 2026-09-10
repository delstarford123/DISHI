import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/mpesa_theme.dart';

class SafterPinView extends StatefulWidget {
  const SafterPinView({super.key});

  @override
  State<SafterPinView> createState() => _SafterPinViewState();
}

class _SafterPinViewState extends State<SafterPinView> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isLoading = false;

  // ─── Create/Deposit ───────────────────────────────────────────────────────
  void _showDepositDialog() {
    final amountCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.savings, color: MPesaTheme.primaryGreen),
          SizedBox(width: 8),
          Text('Lock Funds (Safter Pin)',
              style: TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Lock money in your Safter Pin. It stays locked until you withdraw it.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: labelCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Label (e.g. Rent, Emergency)',
                labelStyle: TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Color(0xFF1A2235),
                border: OutlineInputBorder(borderSide: BorderSide.none),
                prefixIcon: Icon(Icons.label, color: MPesaTheme.primaryGreen),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Amount (KES)',
                labelStyle: TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Color(0xFF1A2235),
                border: OutlineInputBorder(borderSide: BorderSide.none),
                prefixIcon: Icon(Icons.money, color: MPesaTheme.primaryGreen),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: MPesaTheme.primaryGreen),
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
              if (amount <= 0) return;
              Navigator.pop(context);
              await FirebaseFirestore.instance
                  .collection('safter_pins')
                  .add({
                'uid': _uid,
                'label': labelCtrl.text.trim().isEmpty
                    ? 'Savings'
                    : labelCtrl.text.trim(),
                'amount': amount,
                'status': 'locked',
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('KES ${amount.toStringAsFixed(2)} locked!'),
                    backgroundColor: MPesaTheme.primaryGreen));
              }
            },
            child: const Text('Lock Funds',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── Withdraw ─────────────────────────────────────────────────────────────
  void _showWithdrawDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final phoneCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.amber, width: 1.5)),
        title: Row(children: [
          const Icon(Icons.account_balance_wallet, color: Colors.amber),
          const SizedBox(width: 8),
          Text('Withdraw KES ${(data['amount'] as num).toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontSize: 15)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your M-PESA number to receive the funds.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'M-PESA Phone (e.g. 254712345678)',
                labelStyle: TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Color(0xFF1A2235),
                border: OutlineInputBorder(borderSide: BorderSide.none),
                prefixIcon: Icon(Icons.phone, color: Colors.amber),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700),
            onPressed: () async {
              final phone = phoneCtrl.text.trim();
              if (phone.length < 10) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Enter a valid M-PESA number')));
                return;
              }
              Navigator.pop(context);
              // Create withdrawal request — backend processes M-PESA STK
              await FirebaseFirestore.instance
                  .collection('safter_pin_withdrawals')
                  .add({
                'pin_id': doc.id,
                'uid': _uid,
                'amount': data['amount'],
                'phone': phone,
                'status': 'pending',
                'createdAt': FieldValue.serverTimestamp(),
              });
              // Mark pin as withdrawn
              await doc.reference.update({'status': 'withdrawn'});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        '✅ Withdrawal initiated! M-PESA prompt incoming.'),
                    backgroundColor: MPesaTheme.primaryGreen,
                    duration: Duration(seconds: 4)));
              }
            },
            child: const Text('Withdraw via M-PESA',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Safter Pin — Safe Savings',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton.icon(
            onPressed: _showDepositDialog,
            icon: const Icon(Icons.lock, color: MPesaTheme.primaryGreen),
            label: const Text('Lock Funds',
                style: TextStyle(
                    color: MPesaTheme.primaryGreen,
                    fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('safter_pins')
            .where('uid', isEqualTo: _uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: MPesaTheme.primaryGreen));
          }

          if (snapshot.hasError) {
            return Center(
                child: Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: MPesaTheme.primaryGreen.withOpacity(0.1)),
                    child: const Icon(Icons.savings,
                        size: 56, color: MPesaTheme.primaryGreen),
                  ),
                  const SizedBox(height: 16),
                  const Text('No Saved Funds Yet',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'Lock funds to keep them safe.\nWithdraw anytime via M-PESA.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _showDepositDialog,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: MPesaTheme.primaryGreen,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12)),
                    icon: const Icon(Icons.lock, color: Colors.black),
                    label: const Text('Lock Your First Funds',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }

          // Compute total locked
          final total = docs.fold<double>(
              0,
              (sum, d) =>
                  sum +
                  ((d.data() as Map)['amount'] as num? ?? 0).toDouble());

          return Column(
            children: [
              // Summary header
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [
                        MPesaTheme.primaryGreen,
                        MPesaTheme.primaryGreen.withOpacity(0.6)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Locked',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 13)),
                        Text('KES ${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Icon(Icons.savings, size: 40, color: Colors.white),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final isWithdrawn = data['status'] == 'withdrawn';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: const Color(0xFF131A2A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: isWithdrawn
                                  ? Colors.white12
                                  : MPesaTheme.primaryGreen.withOpacity(0.3))),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: isWithdrawn
                                    ? Colors.white12
                                    : MPesaTheme.primaryGreen.withOpacity(0.15),
                                shape: BoxShape.circle),
                            child: Icon(
                                isWithdrawn ? Icons.lock_open : Icons.lock,
                                color: isWithdrawn
                                    ? Colors.white38
                                    : MPesaTheme.primaryGreen),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['label'] ?? 'Savings',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                Text(
                                    'KES ${(data['amount'] as num).toStringAsFixed(2)}',
                                    style: TextStyle(
                                        color: isWithdrawn
                                            ? Colors.white38
                                            : MPesaTheme.primaryGreen,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                if (isWithdrawn)
                                  const Text('Withdrawn',
                                      style: TextStyle(
                                          color: Colors.white38, fontSize: 12)),
                              ],
                            ),
                          ),
                          if (!isWithdrawn)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.shade700,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8)),
                              onPressed: () => _showWithdrawDialog(doc),
                              child: const Text('Withdraw',
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showDepositDialog,
        backgroundColor: MPesaTheme.primaryGreen,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('Lock Funds',
            style:
                TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
