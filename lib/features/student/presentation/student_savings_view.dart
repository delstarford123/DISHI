import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/api_config.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonBlue = Color(0xFF00B2FE);
const Color _neonPink = Color(0xFFF92B60);
const Color _textSecondary = Color(0xFF8B9BB4);

class StudentSavingsView extends StatefulWidget {
  const StudentSavingsView({super.key});

  @override
  State<StudentSavingsView> createState() => _StudentSavingsViewState();
}

class _StudentSavingsViewState extends State<StudentSavingsView> {
  String _currentUid = '';
  double _walletBalance = 0.0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _vaults = [];
  List<Map<String, dynamic>> _pendingLiquidations = [];
  double _totalSaved = 0.0;

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _loadData();
  }

  Future<void> _loadData() async {
    if (_currentUid.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      // 1. Fetch user wallet balance
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUid).get();
      if (userDoc.exists && mounted) {
        final data = userDoc.data() ?? {};
        _walletBalance = (data['walletBalance'] as num?)?.toDouble() ?? 0.0;
      }

      // 2. Fetch vaults from backend
      final resp = await http.get(
        Uri.parse('${ApiConfig.v6SavingsList}/$_currentUid'),
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200 && mounted) {
        final resData = json.decode(resp.body);
        setState(() {
          _vaults = List<Map<String, dynamic>>.from(resData['vaults'] ?? []);
          _pendingLiquidations = List<Map<String, dynamic>>.from(resData['pending_liquidations'] ?? []);
          _totalSaved = (resData['total_saved'] as num?)?.toDouble() ?? 0.0;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _getCategoryIcon(String category) {
    if (category.contains('Emergency')) return Icons.shield_rounded;
    if (category.contains('Education')) return Icons.school_rounded;
    if (category.contains('Tech')) return Icons.laptop_mac_rounded;
    if (category.contains('Living') || category.contains('Rent')) return Icons.home_rounded;
    if (category.contains('Career')) return Icons.workspace_premium_rounded;
    return Icons.savings_rounded;
  }

  Color _getCategoryColor(String category) {
    if (category.contains('Emergency')) return _neonPink;
    if (category.contains('Education')) return _neonCyan;
    if (category.contains('Tech')) return _neonBlue;
    if (category.contains('Living') || category.contains('Rent')) return _neonOrange;
    return const Color(0xFF9C27B0);
  }

  void _showCreateVaultSheet() {
    final titleController = TextEditingController();
    final targetController = TextEditingController();
    final initialController = TextEditingController();
    String selectedCategory = 'Emergency Savings';
    String selectedLock = 'flexible';

    final categories = [
      'Emergency Savings',
      'Education & Tuition',
      'Campus Tech & Gear',
      'Semester Living & Groceries',
      'Graduation & Career',
      'General Goal'
    ];

    final lockOptions = [
      {'key': 'flexible', 'label': 'Flexible (Instant Access)'},
      {'key': '1_month', 'label': '1 Month (30 Days)'},
      {'key': '3_months', 'label': '3 Months (Full Semester)'},
      {'key': '6_months', 'label': '6 Months (Academic Year)'},
      {'key': '1_year', 'label': '1 Year (Long-term)'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Create Savings Vault', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),

                // Category selector
                const Text('Category', style: TextStyle(color: _textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedCategory,
                      dropdownColor: _surfaceLight,
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) {
                        if (val != null) setSheetState(() => selectedCategory = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Vault Title
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Vault Title (e.g. Laptop Repair, Exam Books)',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                // Target Amount
                TextField(
                  controller: targetController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Target Amount (KES)',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                // Lock-In Period
                const Text('Discipline Lock Period', style: TextStyle(color: _textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedLock,
                      dropdownColor: _surfaceLight,
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      items: lockOptions.map((opt) => DropdownMenuItem(value: opt['key'], child: Text(opt['label']!))).toList(),
                      onChanged: (val) {
                        if (val != null) setSheetState(() => selectedLock = val);
                      },
                    ),
                  ),
                ),
                if (selectedLock != 'flexible')
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '🔒 Locked savings cannot be withdrawn until maturity unless liquidated by admin for emergency.',
                      style: TextStyle(color: _neonOrange.withOpacity(0.9), fontSize: 11),
                    ),
                  ),
                const SizedBox(height: 12),

                // Initial Deposit
                TextField(
                  controller: initialController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Initial Deposit (Optional, from wallet)',
                    hintText: 'Available: KES ${_walletBalance.toStringAsFixed(2)}',
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final title = titleController.text.trim().isEmpty ? selectedCategory : titleController.text.trim();
                    final target = double.tryParse(targetController.text.trim()) ?? 1000.0;
                    final initial = double.tryParse(initialController.text.trim()) ?? 0.0;

                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);

                    try {
                      final resp = await http.post(
                        Uri.parse(ApiConfig.v6SavingsCreate),
                        headers: {'Content-Type': 'application/json'},
                        body: json.encode({
                          'user_id': _currentUid,
                          'category': selectedCategory,
                          'title': title,
                          'target_amount': target,
                          'lock_period': selectedLock,
                          'initial_deposit': initial,
                        }),
                      ).timeout(const Duration(seconds: 15));

                      final data = json.decode(resp.body);
                      if (resp.statusCode == 201) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(data['message'] ?? 'Vault created!'), backgroundColor: _neonCyan),
                        );
                        _loadData();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(data['error'] ?? 'Failed to create vault'), backgroundColor: _neonPink),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: _neonPink),
                      );
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                  child: const Text('Create Vault', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDepositDialog(Map<String, dynamic> vault) {
    final amtController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Deposit to ${vault['title']}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available Wallet: KES ${_walletBalance.toStringAsFixed(2)}', style: const TextStyle(color: _textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: amtController,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Amount (KES)',
                labelStyle: const TextStyle(color: _textSecondary),
                filled: true,
                fillColor: _surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
            onPressed: () async {
              final amt = double.tryParse(amtController.text.trim()) ?? 0.0;
              if (amt <= 0) return;
              Navigator.pop(ctx);
              setState(() => _isLoading = true);

              try {
                final resp = await http.post(
                  Uri.parse(ApiConfig.v6SavingsDeposit),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({
                    'user_id': _currentUid,
                    'vault_id': vault['id'],
                    'amount': amt,
                  }),
                ).timeout(const Duration(seconds: 15));

                final data = json.decode(resp.body);
                if (resp.statusCode == 200) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(data['message'] ?? 'Deposited!'), backgroundColor: _neonCyan),
                  );
                  _loadData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(data['error'] ?? 'Deposit failed'), backgroundColor: _neonPink),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: _neonPink),
                );
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Confirm Deposit'),
          ),
        ],
      ),
    );
  }

  void _showWithdrawOrLiquidateDialog(Map<String, dynamic> vault) {
    final bool isLocked = vault['is_locked'] == true;
    final bool isMatured = vault['is_matured'] == true;
    final double balance = (vault['current_balance'] as num?)?.toDouble() ?? 0.0;

    if (balance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No funds available to withdraw in this vault.'), backgroundColor: _neonPink),
      );
      return;
    }

    if (isLocked && !isMatured) {
      _showEarlyLiquidationRequestSheet(vault);
    } else {
      _showDirectWithdrawDialog(vault);
    }
  }

  void _showDirectWithdrawDialog(Map<String, dynamic> vault) {
    final amtController = TextEditingController();
    final double balance = (vault['current_balance'] as num?)?.toDouble() ?? 0.0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Withdraw from ${vault['title']}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available to Withdraw: KES ${balance.toStringAsFixed(2)}', style: const TextStyle(color: _neonCyan, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: amtController,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Amount (KES)',
                labelStyle: const TextStyle(color: _textSecondary),
                filled: true,
                fillColor: _surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonOrange, foregroundColor: Colors.white),
            onPressed: () async {
              final amt = double.tryParse(amtController.text.trim()) ?? 0.0;
              if (amt <= 0 || amt > balance) return;
              Navigator.pop(ctx);
              setState(() => _isLoading = true);

              try {
                final resp = await http.post(
                  Uri.parse(ApiConfig.v6SavingsWithdraw),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({
                    'user_id': _currentUid,
                    'vault_id': vault['id'],
                    'amount': amt,
                  }),
                ).timeout(const Duration(seconds: 15));

                final data = json.decode(resp.body);
                if (resp.statusCode == 200) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(data['message'] ?? 'Withdrawn!'), backgroundColor: _neonCyan),
                  );
                  _loadData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(data['error'] ?? 'Withdrawal failed'), backgroundColor: _neonPink),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: _neonPink),
                );
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Withdraw to Wallet'),
          ),
        ],
      ),
    );
  }

  void _showEarlyLiquidationRequestSheet(Map<String, dynamic> vault) {
    final amtController = TextEditingController(text: (vault['current_balance'] ?? 0).toString());
    final explanationController = TextEditingController();
    String reasonCategory = 'Medical Emergency';

    final reasons = [
      'Medical Emergency',
      'Tuition / Exam Fee Deadline',
      'Family Emergency',
      'Urgent Hostel Rent / Eviction',
      'Other Critical Need'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Request Early Liquidation', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _neonOrange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _neonOrange.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_clock, color: _neonOrange, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This vault is locked for ${vault['days_left'] ?? 0} more days. To safeguard student goals, early liquidation requires system admin review.',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Amount
                TextField(
                  controller: amtController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Amount to Liquidate (Max KES ${vault['current_balance']})',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                // Reason dropdown
                const Text('Reason Category', style: TextStyle(color: _textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: reasonCategory,
                      dropdownColor: _surfaceLight,
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (val) {
                        if (val != null) setSheetState(() => reasonCategory = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Explanation
                TextField(
                  controller: explanationController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Brief Explanation for Admin',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final amt = double.tryParse(amtController.text.trim()) ?? 0.0;
                    final exp = explanationController.text.trim();
                    if (amt <= 0) return;

                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);

                    try {
                      final resp = await http.post(
                        Uri.parse(ApiConfig.v6SavingsEarlyLiquidationRequest),
                        headers: {'Content-Type': 'application/json'},
                        body: json.encode({
                          'user_id': _currentUid,
                          'vault_id': vault['id'],
                          'amount': amt,
                          'reason_category': reasonCategory,
                          'explanation': exp,
                        }),
                      ).timeout(const Duration(seconds: 15));

                      final data = json.decode(resp.body);
                      if (resp.statusCode == 201) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(data['message'] ?? 'Liquidation request submitted!'), backgroundColor: _neonCyan),
                        );
                        _loadData();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(data['error'] ?? 'Submission failed'), backgroundColor: _neonPink),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: _neonPink),
                      );
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                  child: const Text('Submit Request to Admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Savings Vault', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: _cardColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _neonCyan),
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _neonCyan,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('New Vault', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showCreateVaultSheet,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _neonCyan))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: _neonCyan,
              backgroundColor: _cardColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Total Savings Hero Card
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _neonCyan.withOpacity(0.3)),
                        boxShadow: [BoxShadow(color: _neonCyan.withOpacity(0.12), blurRadius: 18, spreadRadius: 2)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Campus Savings', style: TextStyle(color: Colors.white70, fontSize: 14)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: _neonCyan.withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
                                child: Text('${_vaults.length} Vaults Active', style: const TextStyle(color: _neonCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'KES ${_totalSaved.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Icon(Icons.account_balance_wallet_outlined, size: 16, color: _textSecondary),
                              const SizedBox(width: 6),
                              Text('Main Wallet Available: KES ${_walletBalance.toStringAsFixed(2)}', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Pending Liquidation Requests Tray
                    if (_pendingLiquidations.isNotEmpty) ...[
                      const Text('Pending Early Liquidation Reviews', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      ..._pendingLiquidations.map((req) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _neonOrange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _neonOrange.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.hourglass_top_rounded, color: _neonOrange, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('KES ${(req['amount'] ?? 0).toString()} — ${req['vault_title'] ?? "Vault"}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(height: 2),
                                    Text('Reason: ${req['reason_category'] ?? "Emergency"} (Under Admin Review)', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: _neonOrange, borderRadius: BorderRadius.circular(8)),
                                child: const Text('Pending', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // Categories List
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Your Category Vaults', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        TextButton.icon(
                          onPressed: _showCreateVaultSheet,
                          icon: const Icon(Icons.add_circle, color: _neonCyan, size: 16),
                          label: const Text('Add Goal', style: TextStyle(color: _neonCyan, fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_vaults.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          children: [
                            const Icon(Icons.savings_outlined, color: _textSecondary, size: 48),
                            const SizedBox(height: 12),
                            const Text('No savings vaults yet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 6),
                            const Text('Create your first goal: Emergency Fund, Exam Fees, Laptop, or Hostel Rent.', textAlign: TextAlign.center, style: TextStyle(color: _textSecondary, fontSize: 12)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
                              onPressed: _showCreateVaultSheet,
                              child: const Text('Start Saving Now'),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _vaults.length,
                        itemBuilder: (context, idx) {
                          final v = _vaults[idx];
                          final cat = v['category'] ?? 'General Goal';
                          final color = _getCategoryColor(cat);
                          final icon = _getCategoryIcon(cat);
                          final cBal = (v['current_balance'] as num?)?.toDouble() ?? 0.0;
                          final tAmt = (v['target_amount'] as num?)?.toDouble() ?? 1000.0;
                          final progress = ((cBal / (tAmt > 0 ? tAmt : 1.0)) * 100.0).clamp(0.0, 100.0);
                          final isLocked = v['is_locked'] == true;
                          final isMatured = v['is_matured'] == true;
                          final daysLeft = v['days_left'] ?? 0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _cardColor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: color.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: color.withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
                                      child: Icon(icon, color: color, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(v['title'] ?? cat, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                          Text(cat, style: const TextStyle(color: _textSecondary, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    // Lock Status Tag
                                    if (isLocked && !isMatured)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: _neonOrange.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: _neonOrange.withOpacity(0.5))),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.lock, color: _neonOrange, size: 12),
                                            const SizedBox(width: 4),
                                            Text('$daysLeft d left', style: const TextStyle(color: _neonOrange, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: _neonCyan.withOpacity(0.18), borderRadius: BorderRadius.circular(8)),
                                        child: const Text('Unlocked', style: TextStyle(color: _neonCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Balances
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('KES ${cBal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                                    Text('Target: KES ${tAmt.toStringAsFixed(0)}', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Progress Bar
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: progress / 100.0,
                                    backgroundColor: _surfaceLight,
                                    valueColor: AlwaysStoppedAnimation<Color>(color),
                                    minHeight: 8,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text('${progress.toStringAsFixed(0)}% achieved', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(height: 12),

                                // Action Buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: _neonCyan,
                                          side: const BorderSide(color: _neonCyan),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        icon: const Icon(Icons.add_circle_outline, size: 16),
                                        label: const Text('Deposit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        onPressed: () => _showDepositDialog(v),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: (isLocked && !isMatured) ? _neonOrange.withOpacity(0.2) : _neonOrange,
                                          foregroundColor: (isLocked && !isMatured) ? _neonOrange : Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            side: BorderSide(color: _neonOrange.withOpacity(0.6)),
                                          ),
                                        ),
                                        icon: Icon((isLocked && !isMatured) ? Icons.emergency : Icons.arrow_downward, size: 16),
                                        label: Text(
                                          (isLocked && !isMatured) ? 'Request Liquidation' : 'Withdraw',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                        onPressed: () => _showWithdrawOrLiquidateDialog(v),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
