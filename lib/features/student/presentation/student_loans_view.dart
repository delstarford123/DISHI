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

class StudentLoansView extends StatefulWidget {
  const StudentLoansView({super.key});

  @override
  State<StudentLoansView> createState() => _StudentLoansViewState();
}

class _StudentLoansViewState extends State<StudentLoansView> {
  String _currentUid = '';
  double _walletBalance = 0.0;
  bool _isLoading = true;
  bool _hasActiveLoan = false;
  Map<String, dynamic>? _activeLoan;
  int _selectedAmount = 200;
  String _selectedPurpose = 'Food & Cafeteria Meals';

  // Credit Track Record & Security Verification
  int _creditScore = 450;
  String _creditRating = 'Novice Comrade';
  List<int> _unlockedTiers = [100, 200];
  int _repaidCount = 0;
  int _txCount = 0;
  double _okoaDebt = 0.0;

  final List<Map<String, dynamic>> _tiers = [
    {'amount': 100, 'weeks': 1, 'base_fee_pct': 0.0, 'min_repaid': 0, 'purpose': 'Meal Token / Urgent Snack', 'fee': 0.0},
    {'amount': 200, 'weeks': 2, 'base_fee_pct': 1.5, 'min_repaid': 0, 'purpose': 'Food & Exam Printing / Handouts', 'fee': 3.0},
    {'amount': 300, 'weeks': 3, 'base_fee_pct': 3.0, 'min_repaid': 1, 'purpose': 'Course Textbooks & Lab Manuals', 'fee': 9.0},
    {'amount': 400, 'weeks': 4, 'base_fee_pct': 4.5, 'min_repaid': 2, 'purpose': 'Study Modules & Revision Packs', 'fee': 18.0},
    {'amount': 500, 'weeks': 5, 'base_fee_pct': 6.0, 'min_repaid': 3, 'purpose': 'Essential Food Basket & Academic Kit', 'fee': 30.0},
  ];

  final List<String> _purposes = [
    'Food & Cafeteria Meals',
    'Textbooks & Study Handouts',
    'Exam Printing & Stationery',
    'Lab Dissection / Experiment Kit',
    'Semester Academic Project'
  ];

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _loadLoanData();
  }

  Future<void> _loadLoanData() async {
    if (_currentUid.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUid).get();
      if (userDoc.exists && mounted) {
        final uData = userDoc.data() ?? {};
        _walletBalance = (uData['walletBalance'] as num?)?.toDouble() ?? 0.0;
        _okoaDebt = (uData['okoa_debt'] as num?)?.toDouble() ?? 0.0;
      }

      // Fetch active loan
      final resp = await http.get(
        Uri.parse('${ApiConfig.v6LoansActive}/$_currentUid'),
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200 && mounted) {
        final resData = json.decode(resp.body);
        _hasActiveLoan = resData['has_active_loan'] == true;
        _activeLoan = resData['loan'] != null ? Map<String, dynamic>.from(resData['loan']) : null;
      }

      // Fetch credit track record & security eligibility
      final elResp = await http.get(
        Uri.parse('${ApiConfig.v6LoansEligibility}/$_currentUid'),
      ).timeout(const Duration(seconds: 15));

      if (elResp.statusCode == 200 && mounted) {
        final elData = json.decode(elResp.body);
        setState(() {
          _creditScore = (elData['credit_score'] as num?)?.toInt() ?? 450;
          _creditRating = elData['credit_rating'] ?? 'Novice Comrade';
          _repaidCount = (elData['repaid_loans_count'] as num?)?.toInt() ?? 0;
          _txCount = (elData['transactions_count'] as num?)?.toInt() ?? 0;
          _okoaDebt = (elData['okoa_debt'] as num?)?.toDouble() ?? _okoaDebt;
          if (elData['unlocked_tiers'] != null) {
            _unlockedTiers = List<int>.from(elData['unlocked_tiers']);
          }
          // Default selection to first unlocked tier if current is locked
          if (!_unlockedTiers.contains(_selectedAmount) && _unlockedTiers.isNotEmpty) {
            _selectedAmount = _unlockedTiers.first;
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLockedTierDialog(int amount, int minRepaid) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: _neonOrange, width: 1.5)),
        title: Row(
          children: [
            const Icon(Icons.lock, color: _neonOrange),
            const SizedBox(width: 8),
            Text('KES $amount Tier Locked', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To ensure healthy student borrowing, higher loan tiers require a proven repayment track record.',
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Required Settled Loans:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('$minRepaid', style: const TextStyle(color: _neonOrange, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Your Settled Loans:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('$_repaidCount', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '💡 Tip: Start with a KES 100 or KES 200 loan and repay on time to unlock KES 300 to KES 500!',
              style: TextStyle(color: _neonCyan, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  Future<void> _applyForLoan() async {
    if (_currentUid.isEmpty || _hasActiveLoan) return;

    if (_okoaDebt > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please clear your outstanding Okoa Food debt (KES ${_okoaDebt.toStringAsFixed(2)}) before borrowing.'),
          backgroundColor: _neonPink,
        ),
      );
      return;
    }

    if (!_unlockedTiers.contains(_selectedAmount)) {
      final tier = _tiers.firstWhere((t) => t['amount'] == _selectedAmount, orElse: () => _tiers[0]);
      _showLockedTierDialog(_selectedAmount, tier['min_repaid']);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final resp = await http.post(
        Uri.parse(ApiConfig.v6LoansApply),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'student_uid': _currentUid,
          'amount': _selectedAmount,
          'purpose': _selectedPurpose,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(resp.body);
      if (resp.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Loan Disbursed!'), backgroundColor: _neonCyan),
        );
        _loadLoanData();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Loan application rejected'), backgroundColor: _neonPink),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: _neonPink),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _repayLoanStudent() async {
    if (_activeLoan == null) return;
    final totalDue = (_activeLoan!['current_total_due'] as num?)?.toDouble() ?? 0.0;
    if (_walletBalance < totalDue) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient wallet balance (KES ${_walletBalance.toStringAsFixed(2)}) to pay KES ${totalDue.toStringAsFixed(2)}. Top up first.'),
          backgroundColor: _neonPink,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final resp = await http.post(
        Uri.parse(ApiConfig.v6LoansRepayStudent),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'loan_id': _activeLoan!['id']}),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(resp.body);
      if (resp.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Loan repaid in full!'), backgroundColor: _neonCyan),
        );
        _loadLoanData();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Repayment failed'), backgroundColor: _neonPink),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: _neonPink),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestParentToPay() async {
    if (_activeLoan == null) return;
    setState(() => _isLoading = true);

    try {
      final resp = await http.post(
        Uri.parse(ApiConfig.v6LoansRequestParent),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'loan_id': _activeLoan!['id']}),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(resp.body);
      if (resp.statusCode == 200) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: _neonCyan),
                SizedBox(width: 8),
                Text('Assistance Sent!', style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: Text(
              data['message'] ?? 'Emergency loan assistance request has been dispatched to your parent dashboard.',
              style: const TextStyle(color: _textSecondary, fontSize: 13),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Understood'),
              ),
            ],
          ),
        );
        _loadLoanData();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Failed to send parent request'), backgroundColor: _neonPink),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: _neonPink),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTier = _tiers.firstWhere((t) => t['amount'] == _selectedAmount, orElse: () => _tiers[1]);
    final double totalToRepay = (_selectedAmount + (selectedTier['fee'] as double));

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Food & Study Micro-Loans', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: _cardColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: _neonCyan), onPressed: _loadLoanData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _neonCyan))
          : RefreshIndicator(
              onRefresh: _loadLoanData,
              color: _neonCyan,
              backgroundColor: _cardColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Active Loan Card if present
                    if (_hasActiveLoan && _activeLoan != null) ...[
                      _buildActiveLoanCard(_activeLoan!),
                      const SizedBox(height: 20),
                    ],

                    // DISHI Campus Credit Track Record & Security Status Card
                    _buildCreditTrackRecordCard(),
                    const SizedBox(height: 20),

                    if (!_hasActiveLoan) ...[
                      // Choose Loan Tier (KES 100 to 500)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Choose Loan Tier:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(
                            'Max Allowed: KES ${_unlockedTiers.isNotEmpty ? _unlockedTiers.last : 0}',
                            style: const TextStyle(color: _neonCyan, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _tiers.map((tier) {
                            final int amt = tier['amount'];
                            final isSel = (amt == _selectedAmount);
                            final bool isUnlocked = _unlockedTiers.contains(amt);
                            final int minRepaid = tier['min_repaid'] ?? 0;

                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: InkWell(
                                onTap: () {
                                  if (isUnlocked) {
                                    setState(() => _selectedAmount = amt);
                                  } else {
                                    _showLockedTierDialog(amt, minRepaid);
                                  }
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: 116,
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? _neonCyan
                                        : (isUnlocked ? _cardColor : _cardColor.withOpacity(0.5)),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSel
                                          ? _neonCyan
                                          : (isUnlocked ? Colors.white12 : Colors.white10),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'KES $amt',
                                            style: TextStyle(
                                              color: isSel
                                                  ? Colors.black
                                                  : (isUnlocked ? Colors.white : Colors.white38),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16,
                                            ),
                                          ),
                                          if (!isUnlocked) ...[
                                            const SizedBox(width: 4),
                                            const Icon(Icons.lock, size: 13, color: _neonOrange),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${tier['weeks']} Wk Term',
                                        style: TextStyle(
                                          color: isSel
                                              ? Colors.black87
                                              : (isUnlocked ? _textSecondary : Colors.white24),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        tier['base_fee_pct'] == 0.0 ? '0% Fee' : '+${tier['base_fee_pct']}%',
                                        style: TextStyle(
                                          color: isSel
                                              ? Colors.black87
                                              : (isUnlocked ? _neonOrange : Colors.white24),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (!isUnlocked) ...[
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _neonOrange.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            minRepaid == 0 ? 'Req. 2+ Tx' : 'Req. $minRepaid Repaid',
                                            style: const TextStyle(color: _neonOrange, fontSize: 8, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Purpose Dropdown
                      const Text('Purpose of Loan:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white12)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedPurpose,
                            dropdownColor: _surfaceLight,
                            isExpanded: true,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            items: _purposes.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedPurpose = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Repayment Breakdown Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          children: [
                            _breakdownRow('Principal Borrowed', 'KES ${_selectedAmount.toStringAsFixed(0)}'),
                            const SizedBox(height: 8),
                            _breakdownRow(
                              'Base Interest Fee',
                              selectedTier['base_fee_pct'] == 0.0
                                  ? 'KES 0.00 (0%)'
                                  : 'KES ${(selectedTier['fee'] as double).toStringAsFixed(2)} (${selectedTier['base_fee_pct']}%)',
                            ),
                            const SizedBox(height: 8),
                            _breakdownRow('Repayment Period', '${selectedTier['weeks']} Week(s)'),
                            const SizedBox(height: 8),
                            _breakdownRow('Late Overdue Penalty', '+2% after maturity elapsed', isHighlight: true),
                            const Divider(color: Colors.white12, height: 20),
                            _breakdownRow('Total Repayment Due', 'KES ${totalToRepay.toStringAsFixed(2)}', isTotal: true),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Apply Button with Security Checks
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (_okoaDebt > 0 || _unlockedTiers.isEmpty) ? Colors.white12 : _neonCyan,
                          foregroundColor: (_okoaDebt > 0 || _unlockedTiers.isEmpty) ? Colors.white38 : Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: (_isLoading || _okoaDebt > 0 || _unlockedTiers.isEmpty) ? null : _applyForLoan,
                        child: Text(
                          _okoaDebt > 0
                              ? '⚠️ Clear Okoa Food Debt First (-KES ${_okoaDebt.toStringAsFixed(0)})'
                              : (_unlockedTiers.isEmpty
                                  ? '🔒 Build Campus Track Record First'
                                  : 'Disburse KES $_selectedAmount Instantly to Wallet'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Guaranteed Protection Highlights
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DISHI Borrowing Security Protocols', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          SizedBox(height: 10),
                          _BulletPoint(text: 'Strictly 1 Active Loan: Concurrent borrowing is prohibited to prevent student debt distress.'),
                          SizedBox(height: 8),
                          _BulletPoint(text: 'Cross-Debt Protection: Outstanding Okoa Food emergency vouchers must be cleared before cash loans.'),
                          SizedBox(height: 8),
                          _BulletPoint(text: 'Track Record Progression: Higher tiers (KES 300 to 500) require on-time repayment history of smaller loans.'),
                          SizedBox(height: 8),
                          _BulletPoint(text: 'Dual Repayment: Pay from wallet or request your linked parent to settle directly from their dashboard.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCreditTrackRecordCard() {
    final double scorePercent = ((_creditScore - 300) / (850 - 300)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _neonBlue.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: _neonBlue.withOpacity(0.08), blurRadius: 16, spreadRadius: 1)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_outlined, color: _neonBlue, size: 18),
                  SizedBox(width: 8),
                  Text('Credit Track Record', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _neonBlue.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                child: Text('$_creditScore / 850', style: const TextStyle(color: _neonBlue, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: scorePercent,
              minHeight: 6,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(_neonBlue),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Rating: $_creditRating', style: const TextStyle(color: _neonCyan, fontSize: 12, fontWeight: FontWeight.bold)),
              Text('$_repaidCount Repaid Loans', style: const TextStyle(color: _textSecondary, fontSize: 11)),
            ],
          ),
          const Divider(color: Colors.white10, height: 18),

          // Security Verification Badges
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildStatusChip(
                label: _hasActiveLoan ? 'Active Loan Running' : 'Single Loan Compliant',
                isPassed: !_hasActiveLoan,
                icon: _hasActiveLoan ? Icons.warning_amber : Icons.verified_user,
              ),
              _buildStatusChip(
                label: _okoaDebt > 0 ? 'Okoa Debt: -KES ${_okoaDebt.toStringAsFixed(0)}' : 'Zero Food Debt',
                isPassed: _okoaDebt <= 0,
                icon: _okoaDebt > 0 ? Icons.error_outline : Icons.check_circle_outline,
              ),
              _buildStatusChip(
                label: '$_txCount Campus Purchases',
                isPassed: _txCount >= 2,
                icon: Icons.history,
              ),
              _buildStatusChip(
                label: '$_repaidCount Loans Settled',
                isPassed: _repaidCount >= 1,
                icon: Icons.thumb_up_alt_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({required String label, required bool isPassed, required IconData icon}) {
    final Color color = isPassed ? _neonCyan : _neonOrange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActiveLoanCard(Map<String, dynamic> loan) {
    final double amount = (loan['amount'] as num?)?.toDouble() ?? 0.0;
    final double totalDue = (loan['current_total_due'] as num?)?.toDouble() ?? amount;
    final bool isOverdue = loan['is_overdue'] == true;
    final int daysLeft = loan['days_left'] ?? 0;
    final String purpose = loan['purpose'] ?? 'Study & Food Support';
    final bool parentRequested = loan['parent_settlement_requested'] == true;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOverdue
              ? [const Color(0xFF33090F), const Color(0xFF5A101A)]
              : [const Color(0xFF132034), const Color(0xFF1D3557)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isOverdue ? _neonPink : _neonCyan, width: 1.5),
        boxShadow: [BoxShadow(color: (isOverdue ? _neonPink : _neonCyan).withOpacity(0.15), blurRadius: 20, spreadRadius: 2)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isOverdue ? '⚠️ OVERDUE STUDY LOAN' : 'ACTIVE STUDY LOAN',
                style: TextStyle(color: isOverdue ? _neonPink : _neonCyan, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isOverdue ? _neonPink : _neonCyan).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isOverdue ? '+2% OVERDUE PENALTY' : '$daysLeft DAYS LEFT',
                  style: TextStyle(color: isOverdue ? _neonPink : _neonCyan, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('KES ${totalDue.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Purpose: $purpose', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Text('Principal Borrowed: KES ${amount.toStringAsFixed(0)}', style: const TextStyle(color: _textSecondary, fontSize: 11)),
          if (parentRequested) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _neonBlue.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Icon(Icons.family_restroom, color: _neonBlue, size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text('Parent assistance request active on Parent Dashboard.', style: TextStyle(color: Colors.white, fontSize: 11))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),

          // Two Repayment Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _walletBalance >= totalDue ? _neonCyan : Colors.white12,
                    foregroundColor: _walletBalance >= totalDue ? Colors.black : Colors.white54,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.payment, size: 16),
                  label: Text('Pay Myself (KES ${_walletBalance.toStringAsFixed(0)})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  onPressed: (_walletBalance >= totalDue && !_isLoading) ? _repayLoanStudent : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.escalator_warning, size: 16),
                  label: const Text('Request Parent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  onPressed: _isLoading ? null : _requestParentToPay,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, String value, {bool isHighlight = false, bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? Colors.white : (isHighlight ? _neonOrange : _textSecondary),
            fontSize: isTotal ? 14 : 12,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isTotal ? _neonCyan : (isHighlight ? _neonOrange : Colors.white),
            fontSize: isTotal ? 16 : 12,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline, color: _neonCyan, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12))),
      ],
    );
  }
}
