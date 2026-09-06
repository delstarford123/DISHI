import 'package:flutter/material.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class ExpenseTrackerView extends StatelessWidget {
  const ExpenseTrackerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Expense Tracker', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Expenses (This Month)', style: TextStyle(color: _textSecondary, fontSize: 14)),
                    const SizedBox(height: 8),
                    const Text('KES 45,200', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_downward, color: Colors.red),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          const Text('Recent Expenses', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildExpenseCard('Produce (Tomatoes & Onions)', 'KES 2,500', 'Today, 8:00 AM', Icons.local_grocery_store),
          _buildExpenseCard('Staff Wages (Alice)', 'KES 1,000', 'Yesterday', Icons.people),
          _buildExpenseCard('Cooking Oil (20L)', 'KES 4,800', 'Sep 1st', Icons.oil_barrel),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _neonOrange,
        onPressed: () {},
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Log Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildExpenseCard(String title, String amount, String time, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.redAccent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(time, style: const TextStyle(color: _textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(amount, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
