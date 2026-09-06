import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonPink = Color(0xFFF92B60);
const Color _textSecondary = Color(0xFF8B9BB4);

class ParentFinancialsTab extends StatelessWidget {
  final List<Map<String, dynamic>> linkedStudents;

  const ParentFinancialsTab({
    super.key,
    required this.linkedStudents,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          const Text('Financial Hub', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Manage allowances, view analytics, and track spending.', style: TextStyle(color: _textSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildActionGridButton(context, Icons.bar_chart, 'Spending Analytics', _neonCyan, () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Spending Analytics coming soon')));
              }),
              _buildActionGridButton(context, Icons.schedule, 'Digital Allowances', _neonBlue, () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Digital Allowances coming soon')));
              }),
              _buildActionGridButton(context, Icons.pie_chart, 'Category Budgets', _neonOrange, () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category Budgets coming soon')));
              }),
              _buildActionGridButton(context, Icons.health_and_safety, 'Emergency Fund', _neonPink, () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Emergency Fund coming soon')));
              }),
              _buildActionGridButton(context, Icons.receipt_long, 'Receipts & Disputes', Colors.tealAccent, () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipts coming soon')));
              }),
              _buildActionGridButton(context, Icons.account_balance, 'Tax & Fee Summary', Colors.amberAccent, () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tax Summary coming soon')));
              }),
              _buildActionGridButton(context, Icons.money_off, 'Overdraft Protection', Colors.redAccent, () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Overdraft Protection coming soon')));
              }),
            ],
          ),
          const SizedBox(height: 100),
        ]),
      ),
    );
  }

  Widget _buildActionGridButton(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
