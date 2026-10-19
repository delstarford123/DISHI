import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/admin_service.dart';
import '../../../core/theme/mpesa_theme.dart';
import 'widgets/admin_record_details_dialog.dart';
import 'admin_c2b_collections_view.dart';
import 'admin_employee_payroll_view.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonRed = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class AdminB2BFinanceView extends StatefulWidget {
  const AdminB2BFinanceView({super.key});

  @override
  State<AdminB2BFinanceView> createState() => _AdminB2BFinanceViewState();
}

class _AdminB2BFinanceViewState extends State<AdminB2BFinanceView> {
  final AdminService _adminService = AdminService();
  bool _isLoading = true;
  String? _error;
  List<dynamic> _transfers = [];
  Map<String, dynamic>? _liquidityOverview;
  String _filterStatus = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchTransfers();
  }

  Future<void> _fetchTransfers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _adminService.getB2BTransfers(),
        _adminService.getB2BLiquidityOverview().catchError((_) => <String, dynamic>{}),
      ]);
      if (mounted) {
        setState(() {
          _transfers = results[0] as List<dynamic>;
          _liquidityOverview = results[1] as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _error = 'Connection timed out. Check server connectivity.';
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

  void _showInitiateB2BModal({String? prefillName, String? prefillNumber, double? prefillAmount}) {
    final nameCtrl = TextEditingController(text: prefillName ?? '');
    final numberCtrl = TextEditingController(text: prefillNumber ?? '');
    final amountCtrl = TextEditingController(text: prefillAmount != null ? prefillAmount.toStringAsFixed(0) : '');
    final accountRefCtrl = TextEditingController(text: 'DISHI-B2B');
    final purposeCtrl = TextEditingController(text: 'Supplier Invoice');
    String recipientType = (prefillNumber != null && prefillNumber.length <= 6) ? 'buygoods' : 'buygoods';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.swap_horiz, color: _neonCyan, size: 24),
                        SizedBox(width: 8),
                        Text('Initiate M-PESA B2B Payout', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Transfer corporate funds directly to vendor Paybills or BuyGoods Tills via Safaricom B2B Daraja API.',
                  style: TextStyle(color: _textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 20),

                // Recipient Type Selector
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => recipientType = 'buygoods'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: recipientType == 'buygoods' ? _neonCyan.withOpacity(0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: recipientType == 'buygoods' ? _neonCyan : Colors.transparent),
                            ),
                            child: Center(
                              child: Text(
                                'BuyGoods Till (Merchant)',
                                style: TextStyle(
                                  color: recipientType == 'buygoods' ? _neonCyan : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => recipientType = 'paybill'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: recipientType == 'paybill' ? _neonBlue.withOpacity(0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: recipientType == 'paybill' ? _neonBlue : Colors.transparent),
                            ),
                            child: Center(
                              child: Text(
                                'Paybill (Utility/Co)',
                                style: TextStyle(
                                  color: recipientType == 'paybill' ? _neonBlue : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Recipient Name
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Vendor / Supplier Name *',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    prefixIcon: const Icon(Icons.storefront, color: _neonCyan),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),

                // Till / Shortcode
                TextField(
                  controller: numberCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: recipientType == 'buygoods' ? 'Till Number (5-6 digits) *' : 'Paybill Business Shortcode *',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    prefixIcon: const Icon(Icons.dialpad, color: _neonBlue),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),

                // Account Reference (Paybill requirement)
                TextField(
                  controller: accountRefCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Account Reference / Invoice No.',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    prefixIcon: const Icon(Icons.confirmation_number_outlined, color: Colors.amberAccent),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),

                // Amount
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Transfer Amount (KES) *',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    prefixIcon: const Icon(Icons.monetization_on, color: _neonCyan),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),

                // Purpose
                TextField(
                  controller: purposeCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Purpose / Note',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    prefixIcon: const Icon(Icons.notes, color: Colors.white54),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),

                isSubmitting
                    ? const Center(child: CircularProgressIndicator(color: _neonCyan))
                    : ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _neonCyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.send_rounded, size: 20),
                        label: const Text('Execute Daraja B2B Transfer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          final number = numberCtrl.text.trim();
                          final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                          final accountRef = accountRefCtrl.text.trim();
                          final purpose = purposeCtrl.text.trim();

                          if (name.isEmpty || number.isEmpty || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please complete all required fields with valid values'), backgroundColor: _neonRed),
                            );
                            return;
                          }

                          setModalState(() => isSubmitting = true);
                          try {
                            final res = await _adminService.executeB2BPayment(
                              recipientName: name,
                              recipientType: recipientType,
                              destinationNumber: number,
                              amount: amount,
                              accountRef: accountRef.isEmpty ? 'DISHI-B2B' : accountRef,
                              purpose: purpose.isEmpty ? 'Supplier Payout' : purpose,
                            );

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('B2B Payout initiated: ${res['message'] ?? 'Queued to Safaricom'}'),
                                  backgroundColor: _neonCyan,
                                ),
                              );
                              _fetchTransfers();
                            }
                          } catch (e) {
                            setModalState(() => isSubmitting = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: _neonRed),
                              );
                            }
                          }
                        },
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate statistics
    double totalDisbursed = 0.0;
    int successCount = 0;
    int pendingCount = 0;

    for (var t in _transfers) {
      final amt = (t['amount'] as num?)?.toDouble() ?? 0.0;
      final st = (t['status'] ?? 'pending').toString().toLowerCase();
      if (st == 'completed' || st == 'success') {
        totalDisbursed += amt;
        successCount++;
      } else {
        pendingCount++;
      }
    }

    // Filter list
    final filtered = _transfers.where((t) {
      final st = (t['status'] ?? 'pending').toString().toLowerCase();
      final name = (t['recipient_name'] ?? '').toString().toLowerCase();
      final numRef = (t['destination_number'] ?? '').toString().toLowerCase();
      final accRef = (t['account_reference'] ?? '').toString().toLowerCase();

      final matchesStatus = _filterStatus == 'all' ||
          (_filterStatus == 'completed' && (st == 'completed' || st == 'success')) ||
          (_filterStatus == 'pending' && st != 'completed' && st != 'success');

      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery) ||
          numRef.contains(_searchQuery) ||
          accRef.contains(_searchQuery);

      return matchesStatus && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: const Text('B2B Commercial Liquidity', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _neonCyan),
            tooltip: 'Refresh Ledger',
            onPressed: _fetchTransfers,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _neonCyan,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('New B2B Payout', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showInitiateB2BModal,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Banner with B2C and C2B shortcuts
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: _surfaceLight,
              child: Row(
                children: [
                  const Icon(Icons.account_tree_outlined, color: _neonCyan, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('M-PESA Liquidity Channels:', style: TextStyle(color: _textSecondary, fontSize: 12)),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                    icon: const Icon(Icons.people_alt, color: _neonCyan, size: 14),
                    label: const Text('B2C Payroll', style: TextStyle(color: _neonCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminEmployeePayrollView())),
                  ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                    icon: const Icon(Icons.arrow_downward, color: _neonOrange, size: 14),
                    label: const Text('C2B Paybill', style: TextStyle(color: _neonOrange, fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminC2BCollectionsView())),
                  ),
                ],
              ),
            ),

            // Statistics Header Card
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF131A2A), Color(0xFF1B283F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _neonCyan.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total B2B Disbursed', style: TextStyle(color: _textSecondary, fontSize: 12)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: _neonCyan.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                          child: const Text('LIVE B2B CHANNEL', style: TextStyle(color: _neonCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'KES ${totalDisbursed.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMiniStat('Successful', '$successCount', _neonCyan, Icons.check_circle_outline),
                        ),
                        Container(width: 1, height: 32, color: Colors.white12),
                        Expanded(
                          child: _buildMiniStat('Processing', '$pendingCount', _neonOrange, Icons.hourglass_top),
                        ),
                        Container(width: 1, height: 32, color: Colors.white12),
                        Expanded(
                          child: _buildMiniStat('Total Transfers', '${_transfers.length}', _neonBlue, Icons.receipt_long),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Enterprise Liquidity Runway & Health Card
            if (_liquidityOverview != null && _liquidityOverview!.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.health_and_safety, color: _neonCyan, size: 16),
                              SizedBox(width: 6),
                              Text('Liquidity Health Score', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (_liquidityOverview?['health_status'] == 'Optimal' ? _neonCyan : _neonOrange).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${_liquidityOverview?['health_status'] ?? 'Optimal'} (${_liquidityOverview?['liquidity_ratio_percent'] ?? 100}%)',
                              style: TextStyle(
                                color: _liquidityOverview?['health_status'] == 'Optimal' ? _neonCyan : _neonOrange,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Corporate Float Buffer', style: TextStyle(color: _textSecondary, fontSize: 10)),
                                Text('KES ${((_liquidityOverview?['corporate_b2b_float'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0)}', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Vendor Liability Pool', style: TextStyle(color: _textSecondary, fontSize: 10)),
                                Text('KES ${((_liquidityOverview?['vendor_payout_liability'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0)}', style: const TextStyle(color: _neonOrange, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Settlements Ready', style: TextStyle(color: _textSecondary, fontSize: 10)),
                                Text('${_liquidityOverview?['vendors_ready_count'] ?? 0} Vendors', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if ((_liquidityOverview?['vendors_ready_for_settlement'] as List?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 10),
                        const Divider(color: Colors.white10, height: 1),
                        const SizedBox(height: 8),
                        const Text('Quick Vendor Settlements:', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: (_liquidityOverview!['vendors_ready_for_settlement'] as List).take(5).map((v) {
                              final vName = (v['name'] ?? 'Vendor').toString();
                              final vBal = (v['balance'] as num?)?.toDouble() ?? 0.0;
                              final vNum = (v['paybill'] ?? v['phone'] ?? '').toString();
                              return Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _surfaceLight,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _neonCyan.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(vName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                        Text('KES ${vBal.toStringAsFixed(0)}', style: const TextStyle(color: _neonCyan, fontSize: 10)),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () => _showInitiateB2BModal(
                                        prefillName: vName,
                                        prefillNumber: vNum,
                                        prefillAmount: vBal,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: _neonCyan, borderRadius: BorderRadius.circular(6)),
                                        child: const Text('Disburse', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Search and Filter Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search vendor, till, ref...',
                        hintStyle: const TextStyle(color: _textSecondary, fontSize: 13),
                        filled: true,
                        fillColor: _surfaceLight,
                        isDense: true,
                        prefixIcon: const Icon(Icons.search, color: _textSecondary, size: 20),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButtonHideUnderline(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(12)),
                      child: DropdownButton<String>(
                        value: _filterStatus,
                        dropdownColor: _cardColor,
                        icon: const Icon(Icons.filter_list, color: _neonCyan, size: 18),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Status')),
                          DropdownMenuItem(value: 'completed', child: Text('Completed')),
                          DropdownMenuItem(value: 'pending', child: Text('Pending')),
                        ],
                        onChanged: (val) => setState(() => _filterStatus = val ?? 'all'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Main List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: _neonCyan))
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: _neonRed, size: 48),
                              const SizedBox(height: 12),
                              Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
                                onPressed: _fetchTransfers,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inventory_2_outlined, color: _textSecondary.withOpacity(0.5), size: 48),
                                  const SizedBox(height: 12),
                                  const Text('No B2B transfers recorded yet.', style: TextStyle(color: _textSecondary)),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: _showInitiateB2BModal,
                                    child: const Text('+ Initiate First Transfer', style: TextStyle(color: _neonCyan)),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: filtered.length,
                              itemBuilder: (context, idx) {
                                final t = filtered[idx] as Map<String, dynamic>;
                                return _buildTransferCard(t);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: _textSecondary, fontSize: 10)),
      ],
    );
  }

  Widget _buildTransferCard(Map<String, dynamic> t) {
    final name = t['recipient_name'] ?? 'Vendor / Supplier';
    final number = t['destination_number'] ?? 'N/A';
    final type = (t['recipient_type'] ?? 'buygoods').toString().toUpperCase();
    final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;
    final status = (t['status'] ?? 'pending').toString().toLowerCase();
    final ref = t['account_reference'] ?? 'DISHI-B2B';
    final purpose = t['purpose'] ?? 'Payout';
    final createdAt = t['created_at']?.toString().split('T').first ?? 'Recent';

    final isSuccess = status == 'completed' || status == 'success';

    return Card(
      color: _cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isSuccess ? _neonCyan.withOpacity(0.2) : _neonOrange.withOpacity(0.3)),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          AdminRecordDetailsDialog.show(
            context,
            title: 'B2B Transfer Details',
            documentId: t['id']?.toString() ?? t['transfer_id']?.toString() ?? 'B2B-TXN',
            data: t,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: type == 'BUYGOODS' ? _neonCyan.withOpacity(0.15) : _neonBlue.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            type == 'BUYGOODS' ? Icons.store : Icons.apartment,
                            color: type == 'BUYGOODS' ? _neonCyan : _neonBlue,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('$type: $number', style: const TextStyle(color: _textSecondary, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('KES ${amount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSuccess ? _neonCyan.withOpacity(0.15) : _neonOrange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: isSuccess ? _neonCyan : _neonOrange,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Ref: $ref', style: const TextStyle(color: _textSecondary, fontSize: 11)),
                    Text(purpose, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    Text(createdAt, style: const TextStyle(color: _textSecondary, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
