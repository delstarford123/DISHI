import 'package:flutter/material.dart';
import '../../../core/services/admin_service.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonRed = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class AdminPayoutsView extends StatefulWidget {
  const AdminPayoutsView({super.key});

  @override
  State<AdminPayoutsView> createState() => _AdminPayoutsViewState();
}

class _AdminPayoutsViewState extends State<AdminPayoutsView> {
  final AdminService _adminService = AdminService();
  bool _isLoading = false;

  Future<void> _handleRetry(String txId) async {
    setState(() => _isLoading = true);
    try {
      await _adminService.retryFailedPayout(txId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payout queued for retry!')));
        setState(() {}); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _neonRed));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Financial Ops', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: _neonCyan))
        : FutureBuilder(
            future: Future.wait([
              _adminService.getEscrowSummary(),
              _adminService.getFailedPayouts(),
            ]),
            builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _neonCyan));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: _neonRed)));
              }

              final escrowData = snapshot.data![0] as Map<String, dynamic>;
              final failedPayouts = snapshot.data![1] as List<dynamic>;

              final totalEscrow = (escrowData['total_escrow'] as num?)?.toDouble() ?? 0.0;
              final tuitionEscrow = (escrowData['tuition_escrow'] as num?)?.toDouble() ?? 0.0;
              final housingEscrow = (escrowData['housing_escrow'] as num?)?.toDouble() ?? 0.0;

              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildEscrowCard('Total Platform Escrow', totalEscrow, _neonCyan),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildEscrowCard('Tuition', tuitionEscrow, Colors.orangeAccent, small: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildEscrowCard('Housing', housingEscrow, Colors.blueAccent, small: true)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text('Failed Payouts', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (failedPayouts.isEmpty)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('All payouts are healthy!', style: TextStyle(color: _neonCyan, fontSize: 16)),
                    )),
                  ...failedPayouts.map((tx) => _buildFailedTxCard(tx)).toList(),
                ],
              );
            },
          ),
    );
  }

  Widget _buildEscrowCard(String title, double amount, Color color, {bool small = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: _textSecondary, fontSize: small ? 12 : 14)),
          const SizedBox(height: 8),
          Text('Ksh ${amount.toStringAsFixed(2)}', style: TextStyle(color: color, fontSize: small ? 20 : 28, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFailedTxCard(Map<String, dynamic> tx) {
    String id = tx['id'] ?? '';
    double amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    String type = tx['type'] ?? 'Payout';
    String phone = tx['phone'] ?? 'N/A';
    int retries = tx['retry_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: _neonRed.withOpacity(0.5))),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _neonRed, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ksh $amount', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('$type | $phone', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                Text('Retries: $retries', style: const TextStyle(color: _neonRed, fontSize: 10)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonRed, foregroundColor: Colors.white),
            onPressed: () => _handleRetry(id),
            child: const Text('RETRY'),
          )
        ],
      ),
    );
  }
}
