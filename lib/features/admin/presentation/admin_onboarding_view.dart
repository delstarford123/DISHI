import 'package:flutter/material.dart';
import '../../../core/services/admin_service.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonRed = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class AdminOnboardingView extends StatefulWidget {
  const AdminOnboardingView({super.key});

  @override
  State<AdminOnboardingView> createState() => _AdminOnboardingViewState();
}

class _AdminOnboardingViewState extends State<AdminOnboardingView> {
  final AdminService _adminService = AdminService();

  Future<void> _handleApprove(String type, String id) async {
    try {
      await _adminService.approveOnboarding(type, id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${type.toUpperCase()} approved successfully!')));
        setState(() {}); // refresh list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _neonRed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Vendor Onboarding', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _adminService.getPendingOnboarding(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _neonCyan));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: _neonRed)));
          }

          final pending = snapshot.data ?? [];
          if (pending.isEmpty) {
            return const Center(child: Text('No pending applications.', style: TextStyle(color: _neonCyan, fontSize: 16)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pending.length,
            itemBuilder: (context, index) {
              final user = pending[index];
              return _buildApplicationCard(user);
            },
          );
        },
      ),
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> user) {
    final type = user['type'] ?? 'vendor';
    final name = user['business_name'] ?? user['name'] ?? 'Unknown Business';
    final owner = user['owner_name'] ?? user['name'] ?? 'Unknown Owner';
    final phone = user['phone'] ?? 'N/A';
    final id = user['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: _surfaceLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(type.toString().toUpperCase(), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
              )
            ],
          ),
          const SizedBox(height: 8),
          Text('Owner: $owner', style: const TextStyle(color: _textSecondary, fontSize: 14)),
          Text('Phone: $phone', style: const TextStyle(color: _textSecondary, fontSize: 14)),
          Text('User ID: ${id?.toString().substring(0, 8)}', style: const TextStyle(color: _textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
                  onPressed: () => _handleApprove(type, id),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
