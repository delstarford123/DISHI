import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/admin_service.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class AdminExecutiveAnalyticsView extends StatefulWidget {
  const AdminExecutiveAnalyticsView({super.key});

  @override
  State<AdminExecutiveAnalyticsView> createState() => _AdminExecutiveAnalyticsViewState();
}

class _AdminExecutiveAnalyticsViewState extends State<AdminExecutiveAnalyticsView> with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  late TabController _tabController;

  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _commissionsData;
  Map<String, dynamic>? _studentFlowData;
  String _vendorSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _adminService.getCommissionAnalytics().catchError((e) => <String, dynamic>{'total_commission': 0.0, 'breakdown': {}}),
        _adminService.getStudentDepositAndVendorFlow().catchError((e) => <String, dynamic>{'deposit_intelligence': {}, 'vendor_patronage_flow': {}}),
      ]);

      if (mounted) {
        setState(() {
          _commissionsData = results[0];
          _studentFlowData = results[1];
          _isLoading = false;
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _error = 'Connection timed out. Check network connection.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DISHI Intelligence Hub', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Commissions & Student-Vendor Flows', style: TextStyle(color: _textSecondary, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _neonCyan),
            tooltip: 'Reload Data',
            onPressed: _loadAnalytics,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _neonCyan,
          indicatorWeight: 3,
          labelColor: _neonCyan,
          unselectedLabelColor: _textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.monetization_on_outlined), text: 'Platform Commissions'),
            Tab(icon: Icon(Icons.insights), text: 'Student & Vendor Flow'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _neonCyan))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: _neonPink, size: 48),
                        const SizedBox(height: 16),
                        Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                          onPressed: _loadAnalytics,
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCommissionsTab(),
                    _buildStudentVendorFlowTab(),
                  ],
                ),
    );
  }

  // ==========================================
  // TAB 1: COMMISSIONS & REVENUE BREAKDOWN
  // ==========================================
  Widget _buildCommissionsTab() {
    final totalCommission = (_commissionsData?['total_commission'] as num?)?.toDouble() ?? 0.0;
    final breakdown = (_commissionsData?['breakdown'] as Map<String, dynamic>?) ?? {};

    return RefreshIndicator(
      color: _neonCyan,
      backgroundColor: _cardColor,
      onRefresh: _loadAnalytics,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Total Commission Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF162038), Color(0xFF0F2E3B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _neonCyan.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: _neonCyan.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Net Platform Commission', style: TextStyle(color: _textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _neonCyan.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: _neonCyan, size: 12),
                          SizedBox(width: 4),
                          Text('LIVE REVENUE', style: TextStyle(color: _neonCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'KES ${totalCommission.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aggregated from vendor money cashouts, student gift transfers, dining pre-orders, DeLiv courier gigs, and virtual card setups.',
                  style: TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text('Commission Stream Breakdown', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Stream cards
          _buildCommissionCategoryTile(
            title: 'Vendor Money Cashouts (B2C)',
            subtitle: 'Fee deducted when vendors withdraw to M-PESA',
            data: breakdown['vendor_withdrawals'] as Map<String, dynamic>?,
            icon: Icons.storefront,
            color: _neonCyan,
          ),
          const SizedBox(height: 10),

          _buildCommissionCategoryTile(
            title: 'Student Meal Gifts & Peer Transfers',
            subtitle: 'Platform fee on meal gifting and student send-money',
            data: breakdown['student_gifts'] as Map<String, dynamic>?,
            icon: Icons.card_giftcard,
            color: _neonPink,
          ),
          const SizedBox(height: 10),

          _buildCommissionCategoryTile(
            title: 'Cafeteria Pre-Orders & Dining Swipes',
            subtitle: 'Micro-fee cut on cafeteria items and pre-order meals',
            data: breakdown['preorders_cafeteria'] as Map<String, dynamic>?,
            icon: Icons.restaurant,
            color: _neonOrange,
          ),
          const SizedBox(height: 10),

          _buildCommissionCategoryTile(
            title: 'DeLiv Courier & Fundi Services',
            subtitle: 'Platform fee on campus delivery gigs & student handymen',
            data: breakdown['campus_gigs'] as Map<String, dynamic>?,
            icon: Icons.delivery_dining,
            color: _neonBlue,
          ),
          const SizedBox(height: 10),

          _buildCommissionCategoryTile(
            title: 'Virtual Card & Offline NFC Setups',
            subtitle: 'Issuance and activation fees for student NFC dining cards',
            data: breakdown['virtual_cards'] as Map<String, dynamic>?,
            icon: Icons.nfc,
            color: Colors.purpleAccent,
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildCommissionCategoryTile({
    required String title,
    required String subtitle,
    required Map<String, dynamic>? data,
    required IconData icon,
    required Color color,
  }) {
    final comm = (data?['commission'] as num?)?.toDouble() ?? 0.0;
    final vol = (data?['volume'] as num?)?.toDouble() ?? 0.0;
    final count = (data?['transaction_count'] as num?)?.toInt() ?? 0;
    final avgFee = (data?['avg_fee_per_tx'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(subtitle, style: const TextStyle(color: _textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('KES ${comm.toStringAsFixed(2)}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('$count Txs', style: const TextStyle(color: _textSecondary, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text('Total Volume: KES ${vol.toStringAsFixed(0)}', style: const TextStyle(color: _textSecondary, fontSize: 11)),
              Text('Avg Fee / Tx: KES ${avgFee.toStringAsFixed(2)}', style: const TextStyle(color: _textSecondary, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: STUDENT DEPOSITS & VENDOR SPENDING
  // ==========================================
  Widget _buildStudentVendorFlowTab() {
    final depositInfo = (_studentFlowData?['deposit_intelligence'] as Map<String, dynamic>?) ?? {};
    final vendorFlow = (_studentFlowData?['vendor_patronage_flow'] as Map<String, dynamic>?) ?? {};

    final totalDeposits = (depositInfo['total_student_deposits'] as num?)?.toDouble() ?? 0.0;
    final totalDepositTxs = (depositInfo['total_deposit_transactions'] as num?)?.toInt() ?? 0;
    final uniqueDepositors = (depositInfo['unique_depositing_students'] as num?)?.toInt() ?? 0;
    final avgDeposit = (depositInfo['avg_deposit_amount'] as num?)?.toDouble() ?? 0.0;
    final c2bVol = (depositInfo['c2b_paybill_volume'] as num?)?.toDouble() ?? 0.0;
    final stkVol = (depositInfo['stk_push_volume'] as num?)?.toDouble() ?? 0.0;

    final totalStudentSpend = (vendorFlow['total_student_spend'] as num?)?.toDouble() ?? 0.0;
    final allVendors = (vendorFlow['all_vendors'] as List<dynamic>?) ?? [];

    final filteredVendors = allVendors.where((v) {
      if (_vendorSearchQuery.isEmpty) return true;
      final name = (v['vendor_name'] ?? '').toString().toLowerCase();
      final loc = (v['location'] ?? '').toString().toLowerCase();
      final cat = (v['category'] ?? '').toString().toLowerCase();
      final q = _vendorSearchQuery.toLowerCase();
      return name.contains(q) || loc.contains(q) || cat.contains(q);
    }).toList();

    return RefreshIndicator(
      color: _neonCyan,
      backgroundColor: _cardColor,
      onRefresh: _loadAnalytics,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Total Student Deposits Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF131A2A), Color(0xFF1D283E)],
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
                    const Text('Total Student Inflow (Deposits)', style: TextStyle(color: _textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _neonCyan.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                      child: Text('$uniqueDepositors Students • $totalDepositTxs Txs', style: const TextStyle(color: _neonCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'KES ${totalDeposits.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('C2B Paybill (4050545)', style: TextStyle(color: _textSecondary, fontSize: 10)),
                          Text('KES ${c2bVol.toStringAsFixed(0)}', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('STK In-App Deposit', style: TextStyle(color: _textSecondary, fontSize: 10)),
                          Text('KES ${stkVol.toStringAsFixed(0)}', style: const TextStyle(color: _neonBlue, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Avg Deposit Size', style: TextStyle(color: _textSecondary, fontSize: 10)),
                          Text('KES ${avgDeposit.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Vendor Spend Overview Banner
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Where Students Spend Money',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Total: KES ${totalStudentSpend.toStringAsFixed(0)}', style: const TextStyle(color: _neonOrange, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Track vendor revenue, dining frequency, and campus stall locations for strategic food supply decisions.', style: TextStyle(color: _textSecondary, fontSize: 11)),
          const SizedBox(height: 12),

          // Search Field
          TextField(
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search vendor by name, location, or food category...',
              hintStyle: const TextStyle(color: _textSecondary, fontSize: 12),
              prefixIcon: const Icon(Icons.search, color: _neonCyan, size: 20),
              filled: true,
              fillColor: _cardColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: (val) => setState(() => _vendorSearchQuery = val),
          ),
          const SizedBox(height: 14),

          // Vendor Ranked List
          if (filteredVendors.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: const Text('No vendor spending activity matched your search.', style: TextStyle(color: _textSecondary)),
            )
          else
            ...filteredVendors.map((v) => _buildVendorFlowCard(v, totalStudentSpend)),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildVendorFlowCard(Map<String, dynamic> v, double totalSpend) {
    final name = (v['vendor_name'] ?? 'Vendor').toString();
    final loc = (v['location'] ?? 'Main Campus').toString();
    final campus = (v['campus'] ?? 'Campus').toString();
    final cat = (v['category'] ?? 'Dining').toString();
    final amt = (v['total_amount'] as num?)?.toDouble() ?? 0.0;
    final count = (v['frequency_count'] as num?)?.toInt() ?? 0;
    final unique = (v['unique_students_count'] as num?)?.toInt() ?? 0;
    final avgSpend = (v['avg_spend_per_order'] as num?)?.toDouble() ?? 0.0;
    final share = (v['market_share_percent'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _surfaceLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: _neonCyan.withValues(alpha: 0.5)),
                ),
                child: const Center(
                  child: Icon(Icons.restaurant_menu, color: _neonCyan, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: _neonOrange, size: 12),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            '$loc • $campus • $cat',
                            style: const TextStyle(color: _textSecondary, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'KES ${amt.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _neonCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$count Purchases',
                      style: const TextStyle(color: _neonCyan, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Market Share Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (share / 100).clamp(0.01, 1.0),
              backgroundColor: _surfaceLight,
              color: _neonCyan,
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 8),

          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 4,
            children: [
              Text('Market Share: $share%', style: const TextStyle(color: _neonCyan, fontSize: 11, fontWeight: FontWeight.bold)),
              Text('Patronage: $unique students', style: const TextStyle(color: _textSecondary, fontSize: 11)),
              Text('Avg Ticket: KES ${avgSpend.toStringAsFixed(0)}', style: const TextStyle(color: _textSecondary, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
