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

  final List<Map<String, dynamic>> _tiers = [
    {'amount': 100, 'weeks': 1, 'base_fee_pct': 0.0, 'purpose': 'Meal Token / Urgent Snack', 'fee': 0.0},
    {'amount': 200, 'weeks': 2, 'base_fee_pct': 1.5, 'purpose': 'Food & Exam Printing / Handouts', 'fee': 3.0},
    {'amount': 300, 'weeks': 3, 'base_fee_pct': 3.0, 'purpose': 'Course Textbooks & Lab Manuals', 'fee': 9.0},
    {'amount': 400, 'weeks': 4, 'base_fee_pct': 4.5, 'purpose': 'Study Modules & Revision Packs', 'fee': 18.0},
    {'amount': 500, 'weeks': 5, 'base_fee_pct': 6.0, 'purpose': 'Essential Food Basket & Academic Kit', 'fee': 30.0},
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
        _walletBalance = (userDoc.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;
      }

      final resp = await http.get(
        Uri.parse('${ApiConfig.v6LoansActive}/$_currentUid'),
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200 && mounted) {
        final resData = json.decode(resp.body);
        setState(() {
          _hasActiveLoan = resData['has_active_loan'] == true;
          _activeLoan = resData['loan'] != null ? Map<String, dynamic>.from(resData['loan']) : null;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _applyForLoan() async {
    if (_currentUid.isEmpty || _hasActiveLoan) return;
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
                    // Active Loan Card or Available Limit Banner
                    if (_hasActiveLoan && _activeLoan != null) ...[
                      _buildActiveLoanCard(_activeLoan!),
                      const SizedBox(height: 20),
                    ] else ...[
                      // Available Limit Hero Card
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0D241C), Color(0xFF143B2E), Color(0xFF194D3B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _neonCyan.withOpacity(0.4), width: 1.5),
                          boxShadow: [BoxShadow(color: _neonCyan.withOpacity(0.12), blurRadius: 18, spreadRadius: 2)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Emergency Study & Food Credit', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: _neonCyan.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                                  child: const Text('ELIGIBLE', style: TextStyle(color: _neonCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text('Up to KES 500', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            const Text(
                              'Instant funds deposited directly to your wallet for meal tokens, revision books, printing, or lab supplies.',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Select Loan Tier (KES 100 to 500)
                      const Text('Choose Loan Amount:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 10),

                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _tiers.map((tier) {
                            final int amt = tier['amount'];
                            final isSel = (amt == _selectedAmount);
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: InkWell(
                                onTap: () => setState(() => _selectedAmount = amt),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: 110,
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: isSel ? _neonCyan : _cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isSel ? _neonCyan : Colors.white12, width: 1.5),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        'KES $amt',
                                        style: TextStyle(color: isSel ? Colors.black : Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${tier['weeks']} Wk Term',
                                        style: TextStyle(color: isSel ? Colors.black87 : _textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        tier['base_fee_pct'] == 0.0 ? '0% Fee' : '+${tier['base_fee_pct']}%',
                                        style: TextStyle(color: isSel ? Colors.black87 : _neonOrange, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
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
                            _breakdownRow('Base Interest Fee', selectedTier['base_fee_pct'] == 0.0 ? 'KES 0.00 (0%)' : 'KES ${(selectedTier['fee'] as double).toStringAsFixed(2)} (${selectedTier['base_fee_pct']}%)'),
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

                      // Apply Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _neonCyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _isLoading ? null : _applyForLoan,
                        child: Text(
                          'Get KES $_selectedAmount Disbursed Instantly',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                          Text('Campus Financial Support Guarantee', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          SizedBox(height: 10),
                          _BulletPoint(text: 'Dual Repayment: Settle the loan yourself or click "Request Parent" to let your linked parent pay for you.'),
                          SizedBox(height: 8),
                          _BulletPoint(text: 'Transparent Fee: KES 100 has 0% interest for 1 week. Graduated 1.5% fee per tier up to KES 500 for 5 weeks.'),
                          SizedBox(height: 8),
                          _BulletPoint(text: 'Overdue Policy: An additional 2% fee applies only if the loan is not cleared after the agreed repayment term.'),
                          SizedBox(height: 8),
                          _BulletPoint(text: 'Strictly 1 active loan per student to prevent student debt distress.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
        Text(label, style: TextStyle(color: isTotal ? Colors.white : (isHighlight ? _neonOrange : _textSecondary), fontSize: isTotal ? 14 : 12, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(color: isTotal ? _neonCyan : (isHighlight ? _neonOrange : Colors.white), fontSize: isTotal ? 16 : 12, fontWeight: isTotal ? FontWeight.w900 : FontWeight.bold)),
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
