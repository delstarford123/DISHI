import 'package:flutter/material.dart';
import '../../../core/services/admin_service.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonRed = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class AdminAnalyticsView extends StatelessWidget {
  const AdminAnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('System Analytics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: AdminService().getSystemAnalytics(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _neonCyan));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading analytics: ${snapshot.error}', style: const TextStyle(color: _neonRed)));
          }
          
          final data = snapshot.data ?? {};
          final totalRev = data['total_revenue']?.toString() ?? 'KES 0';
          final activeUsers = data['active_users']?.toString() ?? '0';
          final totalVendors = data['total_vendors']?.toString() ?? '0';
          final totalTransactions = data['total_transactions']?.toString() ?? '0';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('System Metrics', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildStatCard('Total Revenue (DISHI Fee)', totalRev, Icons.show_chart, _neonCyan),
              _buildStatCard('Total Active Vendors', totalVendors, Icons.storefront, Colors.orangeAccent),
              _buildStatCard('Total Transactions Processed', totalTransactions, Icons.receipt_long, Colors.blueAccent),
              _buildStatCard('Active Users This Week', activeUsers, Icons.groups, Colors.blue),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: _textSecondary, fontSize: 14)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }
}
