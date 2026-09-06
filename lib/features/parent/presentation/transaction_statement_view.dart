import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _textSecondary = Color(0xFF8B9BB4);

class TransactionStatementView extends StatelessWidget {
  const TransactionStatementView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('E-Statements', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: _neonCyan),
            onPressed: () {},
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('October 2026', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildTxRow('M-PESA STK Topup', 'Oct 12', '+ KES 1000', Colors.green),
          _buildTxRow('POS Payment', 'Oct 11', '- KES 250', Colors.white),
          _buildTxRow('Okoa Repayment', 'Oct 10', '- KES 50', _neonPink),
        ],
      ),
    );
  }

  Widget _buildTxRow(String title, String date, String amount, Color amountColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(date, style: const TextStyle(color: _textSecondary, fontSize: 12)),
            ],
          ),
          Text(amount, style: TextStyle(color: amountColor, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
