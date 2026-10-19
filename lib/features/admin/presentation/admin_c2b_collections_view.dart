import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/admin_service.dart';
import 'widgets/admin_record_details_dialog.dart';
import 'admin_b2b_finance_view.dart';
import 'admin_employee_payroll_view.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonRed = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class AdminC2BCollectionsView extends StatefulWidget {
  const AdminC2BCollectionsView({super.key});

  @override
  State<AdminC2BCollectionsView> createState() => _AdminC2BCollectionsViewState();
}

class _AdminC2BCollectionsViewState extends State<AdminC2BCollectionsView> {
  final AdminService _adminService = AdminService();
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _overview;
  String _searchQuery = '';
  String _filterType = 'all'; // all, credited, unmatched

  @override
  void initState() {
    super.initState();
    _fetchC2BData();
  }

  Future<void> _fetchC2BData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _adminService.getC2BOverview();
      if (mounted) {
        setState(() {
          _overview = data;
          _isLoading = false;
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _error = 'Connection timed out. Server taking too long to respond.';
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

  void _showSimulateC2BModal() {
    final phoneCtrl = TextEditingController(text: '254712345678');
    final amountCtrl = TextEditingController(text: '100');
    final billRefCtrl = TextEditingController(text: 'WALLET-TOPUP');
    final nameCtrl = TextEditingController(text: 'Comrade Student');
    bool isSimulating = false;

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
                        Icon(Icons.bolt, color: Colors.amberAccent, size: 24),
                        SizedBox(width: 8),
                        Text('Test C2B Paybill Simulation', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                  'Simulate an inbound Paybill payment to test account resolution, wallet crediting, and ledger updates live.',
                  style: TextStyle(color: _textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Customer MSISDN (Phone) *',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: billRefCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'BillRefNumber (Account Reference) *',
                    hintText: 'e.g. Phone, Reg No, Student ID, or WALLET',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 11),
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Customer Name (Optional)',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Amount (KES) *',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                isSimulating
                    ? const Center(child: CircularProgressIndicator(color: _neonCyan))
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amberAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final phone = phoneCtrl.text.trim();
                          final billRef = billRefCtrl.text.trim();
                          final amount = double.tryParse(amountCtrl.text.trim()) ?? 100.0;
                          final custName = nameCtrl.text.trim();

                          if (phone.isEmpty || billRef.isEmpty || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter valid phone, account reference, and amount'), backgroundColor: _neonRed),
                            );
                            return;
                          }

                          setModalState(() => isSimulating = true);
                          try {
                            final result = await _adminService.simulateC2B(
                              phone: phone,
                              amount: amount,
                              billRef: billRef,
                              customerName: custName.isNotEmpty ? custName : null,
                            );

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              final msg = result['message'] ?? 'Simulation completed';
                              final matched = result['matched'] == true;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(msg),
                                  backgroundColor: matched ? _neonCyan : Colors.amberAccent,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                              _fetchC2BData();
                            }
                          } catch (e) {
                            setModalState(() => isSimulating = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Simulation error: $e'), backgroundColor: _neonRed),
                              );
                            }
                          }
                        },
                        child: const Text('Simulate Webhook Inbound', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showReconcileDialog(Map<String, dynamic> c) {
    final transId = (c['trans_id'] ?? c['id'] ?? '').toString();
    final amount = (c['amount'] ?? c['trans_amount'] as num?)?.toDouble() ?? 0.0;
    final userCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) => AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.link, color: _neonCyan),
              const SizedBox(width: 8),
              const Text('Link Unmatched Deposit', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Transaction ID: $transId', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text('Amount: KES ${amount.toStringAsFixed(2)}', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 14),
              const Text('Enter target student or vendor User ID to credit their wallet:', style: TextStyle(color: _textSecondary, fontSize: 11)),
              const SizedBox(height: 8),
              TextField(
                controller: userCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Target User ID (UID) *',
                  labelStyle: const TextStyle(color: _neonCyan, fontSize: 12),
                  filled: true,
                  fillColor: _surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            isSubmitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _neonCyan, strokeWidth: 2))
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
                    onPressed: () async {
                      final uid = userCtrl.text.trim();
                      if (uid.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User ID is required'), backgroundColor: _neonRed));
                        return;
                      }
                      setDlgState(() => isSubmitting = true);
                      try {
                        final res = await _adminService.reconcileC2B(transId: transId, userId: uid);
                        if (dlgCtx.mounted) {
                          Navigator.pop(dlgCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(res['message'] ?? 'Deposit reconciled successfully!'), backgroundColor: _neonCyan),
                          );
                          _fetchC2BData();
                        }
                      } catch (e) {
                        setDlgState(() => isSubmitting = false);
                        if (dlgCtx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _neonRed));
                        }
                      }
                    },
                    child: const Text('Reconcile & Credit', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paybill = _overview?['paybill_number'] ?? '4050545';
    final totalCollected = (_overview?['total_collected'] ?? _overview?['total_volume'] as num?)?.toDouble() ?? 0.0;
    final totalTransactions = _overview?['total_transactions'] ?? 0;
    final unmatchedCount = _overview?['unmatched_count'] ?? 0;
    final collections = (_overview?['recent_collections'] as List<dynamic>?) ?? [];

    final filtered = collections.where((c) {
      final receipt = (c['trans_id'] ?? c['mpesaReceiptNumber'] ?? '').toString().toLowerCase();
      final phone = (c['msisdn'] ?? c['phoneNumber'] ?? '').toString().toLowerCase();
      final ref = (c['bill_ref_number'] ?? c['accountReference'] ?? '').toString().toLowerCase();
      final name = (c['customer_name'] ?? c['first_name'] ?? '').toString().toLowerCase();
      final status = (c['status'] ?? '').toString().toLowerCase();
      final isUnmatched = status == 'unmatched' || c['reconciled'] == false;

      final matchesSearch = _searchQuery.isEmpty ||
          receipt.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          ref.contains(_searchQuery) ||
          name.contains(_searchQuery);

      if (!matchesSearch) return false;

      if (_filterType == 'credited') return !isUnmatched;
      if (_filterType == 'unmatched') return isUnmatched;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: const Text('C2B Paybill Collections', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.amberAccent),
            tooltip: 'Simulate C2B Webhook',
            onPressed: _showSimulateC2BModal,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: _neonCyan),
            tooltip: 'Refresh Inbound Stream',
            onPressed: _fetchC2BData,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Banner with B2C and B2B shortcuts
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
                    icon: const Icon(Icons.swap_horiz, color: _neonBlue, size: 14),
                    label: const Text('B2B Finance', style: TextStyle(color: _neonBlue, fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminB2BFinanceView())),
                  ),
                ],
              ),
            ),

            // Paybill Status Card
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF131A2A), Color(0xFF1E2838)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.15), shape: BoxShape.circle),
                              child: const Icon(Icons.call_received, color: Colors.greenAccent, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Safaricom Paybill Inbound', style: TextStyle(color: _textSecondary, fontSize: 11)),
                                Text('Paybill: $paybill', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.greenAccent, size: 12),
                              SizedBox(width: 4),
                              Text('LISTENER ACTIVE', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Inbound Collections', style: TextStyle(color: _textSecondary, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            'KES ${totalCollected.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCollectionStat('Total Deposits', '$totalTransactions txns', Icons.swap_vert, _neonCyan),
                        ),
                        Container(width: 1, height: 30, color: Colors.white12),
                        Expanded(
                          child: _buildCollectionStat(
                            'Avg Deposit',
                            totalTransactions > 0 ? 'KES ${(totalCollected / totalTransactions).toStringAsFixed(0)}' : 'KES 0',
                            Icons.analytics,
                            _neonBlue,
                          ),
                        ),
                        Container(width: 1, height: 30, color: Colors.white12),
                        Expanded(
                          child: _buildCollectionStat('Unmatched', '$unmatchedCount', Icons.warning_amber_rounded, unmatchedCount > 0 ? _neonOrange : Colors.greenAccent),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Search Bar & Filter Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search Receipt, Customer, Phone, or Account...',
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
            const SizedBox(height: 8),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  _buildFilterChip('all', 'All Deposits (${collections.length})'),
                  _buildFilterChip('credited', 'Auto-Credited'),
                  _buildFilterChip('unmatched', 'Unmatched ($unmatchedCount)'),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Inbound Collections Stream
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
                                onPressed: _fetchC2BData,
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
                                  Icon(Icons.inbox_outlined, color: _textSecondary.withOpacity(0.5), size: 48),
                                  const SizedBox(height: 12),
                                  const Text('No recent C2B Paybill deposits found.', style: TextStyle(color: _textSecondary)),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: _showSimulateC2BModal,
                                    child: const Text('Simulate Test Deposit', style: TextStyle(color: Colors.amberAccent)),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: filtered.length,
                              itemBuilder: (context, idx) {
                                final item = filtered[idx] as Map<String, dynamic>;
                                return _buildCollectionItem(item);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _filterType == filterKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
        selected: isSelected,
        selectedColor: _neonCyan,
        backgroundColor: _surfaceLight,
        onSelected: (val) => setState(() => _filterType = filterKey),
      ),
    );
  }

  Widget _buildCollectionStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: _textSecondary, fontSize: 10)),
      ],
    );
  }

  Widget _buildCollectionItem(Map<String, dynamic> c) {
    final receipt = c['trans_id'] ?? c['mpesaReceiptNumber'] ?? 'TXN-PENDING';
    final amount = (c['trans_amount'] ?? c['amount'] as num?)?.toDouble() ?? 0.0;
    final phone = c['msisdn'] ?? c['phoneNumber'] ?? '254...';
    final account = c['bill_ref_number'] ?? c['accountReference'] ?? 'General Deposit';
    final name = '${c['first_name'] ?? ''} ${c['last_name'] ?? ''}'.trim();
    final time = c['trans_time']?.toString() ?? c['timestamp']?.toString() ?? 'Recent';
    final status = (c['status'] ?? '').toString();
    final isUnmatched = status == 'unmatched' || c['reconciled'] == false;
    final matchedUser = c['matched_user_name']?.toString() ?? '';

    return Card(
      color: _cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isUnmatched ? _neonOrange.withOpacity(0.5) : Colors.greenAccent.withOpacity(0.2)),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          AdminRecordDetailsDialog.show(
            context,
            title: 'C2B Inbound Receipt: $receipt',
            documentId: receipt,
            data: c,
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
                            color: (isUnmatched ? _neonOrange : Colors.greenAccent).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isUnmatched ? Icons.help_outline : Icons.arrow_downward,
                            color: isUnmatched ? _neonOrange : Colors.greenAccent,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(receipt, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(name.isNotEmpty ? '$name • $phone' : phone, style: const TextStyle(color: _textSecondary, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('+KES ${amount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isUnmatched ? _neonOrange : Colors.greenAccent).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isUnmatched ? 'UNMATCHED DEPOSIT' : 'AUTO-CREDITED',
                          style: TextStyle(
                            color: isUnmatched ? _neonOrange : Colors.greenAccent,
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
                    Flexible(
                      child: Text(
                        'Account: $account${matchedUser.isNotEmpty ? " • User: $matchedUser" : ""}',
                        style: const TextStyle(color: _textSecondary, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(time, style: const TextStyle(color: _textSecondary, fontSize: 10)),
                  ],
                ),
              ),
              if (isUnmatched) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _showReconcileDialog(c),
                    icon: const Icon(Icons.link, size: 14),
                    label: const Text('Link to Student / Vendor', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
