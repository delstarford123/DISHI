import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonBlue = Color(0xFF00E5FF);
const Color _textSecondary = Color(0xFF8B9BB4);

class ExpenseTrackingView extends StatelessWidget {
  const ExpenseTrackingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Property Expenses', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.add, color: _neonBlue), onPressed: () {})
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_neonBlue, Color(0xFF00838F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Expenses (Oct)', style: TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('KES 45,200.00', style: TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Recent Expenses', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildExpenseRow('Plumbing Repair (Rm 42)', 'Oct 14', 'KES 2,500', Icons.plumbing),
          _buildExpenseRow('Caretaker Salary', 'Oct 01', 'KES 15,000', Icons.person),
          _buildExpenseRow('Garbage Collection', 'Oct 01', 'KES 3,000', Icons.delete),
        ],
      ),
    );
  }

  Widget _buildExpenseRow(String title, String date, String amount, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: _surfaceLight, child: Icon(icon, color: _textSecondary)),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(date, style: const TextStyle(color: _textSecondary, fontSize: 12)),
                ],
              ),
            ],
          ),
          Text(amount, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
