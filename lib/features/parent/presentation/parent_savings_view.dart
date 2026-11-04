import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/api_config.dart';
import '../../../core/utils/deposit_helper.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonBlue = Color(0xFF00B2FE);
const Color _textSecondary = Color(0xFF8B9BB4);

class ParentSavingsView extends StatefulWidget {
  const ParentSavingsView({super.key});

  @override
  State<ParentSavingsView> createState() => _ParentSavingsViewState();
}

class _ParentSavingsViewState extends State<ParentSavingsView> {
  String _currentUid = '';
  String _parentPhone = '';
  double _vaultBalance = 0.0;
  double _walletBalance = 0.0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _linkedStudents = [];
  List<Map<String, dynamic>> _studentVaults = [];
  List<Map<String, dynamic>> _pendingLoans = [];

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _loadParentData();
  }

  Future<void> _loadParentData() async {
    if (_currentUid.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final pDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUid).get();
      if (pDoc.exists && mounted) {
        final data = pDoc.data() ?? {};
        _vaultBalance = (data['vaultBalance'] as num?)?.toDouble() ?? (data['savingsBalance'] as num?)?.toDouble() ?? 0.0;
        _walletBalance = (data['walletBalance'] as num?)?.toDouble() ?? 0.0;
        _parentPhone = data['phoneNumber'] ?? data['phone'] ?? '';
      }

      // Find linked students
      final studentsQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('parentUid', isEqualTo: _currentUid)
          .get();

      final students = studentsQuery.docs.map((d) {
        final m = d.data();
        m['uid'] = d.id;
        return m;
      }).toList();

      List<Map<String, dynamic>> allVaults = [];
      List<Map<String, dynamic>> loans = [];

      for (var s in students) {
        final sUid = s['uid'];
        // Query student category vaults
        final vSnap = await FirebaseFirestore.instance
            .collection('user_savings_vaults')
            .where('user_id', isEqualTo: sUid)
            .get();

        for (var vd in vSnap.docs) {
          final vm = vd.data();
          vm['id'] = vd.id;
          vm['student_name'] = s['displayName'] ?? s['name'] ?? 'Student';
          allVaults.add(vm);
        }

        // Query pending loan requests
        final loanSnap = await FirebaseFirestore.instance
            .collection('student_loans')
            .where('student_uid', isEqualTo: sUid)
            .where('status', whereIn: ['active', 'overdue'])
            .where('parent_settlement_requested', isEqualTo: true)
            .get();

        for (var ld in loanSnap.docs) {
          final lm = ld.data();
          lm['id'] = ld.id;
          loans.add(lm);
        }
      }

      if (mounted) {
        setState(() {
          _linkedStudents = students;
          _studentVaults = allVaults;
          _pendingLoans = loans;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDepositDialog() {
    final amtController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Fund Family Reserve Vault', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Deposit funds via M-PESA STK Push directly into your Family Reserve Vault.', style: TextStyle(color: _textSecondary, fontSize: 12)),
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
            onPressed: () {
              final amt = double.tryParse(amtController.text.trim()) ?? 0.0;
              if (amt <= 0) return;
              Navigator.pop(ctx);
              DepositHelper.initiateStkPush(
                phoneNumber: _parentPhone,
                amount: amt,
                accountReference: 'FAMILY_VAULT',
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('M-PESA STK Push initiated for KES ${amt.toStringAsFixed(0)}'), backgroundColor: _neonCyan),
              );
            },
            child: const Text('Send STK Push'),
          ),
        ],
      ),
    );
  }

  void _showGiftStudentVaultDialog(Map<String, dynamic> vault) {
    final amtController = TextEditingController(text: '1000');
    final sName = vault['student_name'] ?? 'Student';
    final vTitle = vault['title'] ?? 'Vault';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Contribute to $sName\'s $vTitle', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available Family Vault: KES ${_vaultBalance.toStringAsFixed(2)}', style: const TextStyle(color: _neonCyan, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: amtController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Gift Amount (KES)',
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
                // Deduct from parent vault, credit student vault
                await FirebaseFirestore.instance.collection('users').doc(_currentUid).update({
                  'vaultBalance': FieldValue.increment(-amt),
                  'savingsBalance': FieldValue.increment(-amt),
                });

                await FirebaseFirestore.instance.collection('user_savings_vaults').doc(vault['id']).update({
                  'current_balance': FieldValue.increment(amt),
                });

                final sUid = vault['user_id'];
                if (sUid != null) {
                  await FirebaseFirestore.instance.collection('users').doc(sUid).update({
                    'vaultBalance': FieldValue.increment(amt),
                  });
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gifted KES ${amt.toStringAsFixed(0)} to $sName\'s $vTitle!'), backgroundColor: _neonCyan),
                  );
                  _loadParentData();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _neonPink));
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Confirm Gift'),
          ),
        ],
      ),
    );
  }

  Future<void> _settleStudentLoan(Map<String, dynamic> loan) async {
    final loanId = loan['id'];
    setState(() => _isLoading = true);

    try {
      final resp = await http.post(
        Uri.parse(ApiConfig.v6LoansRepayParent),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'loan_id': loanId,
          'parent_uid': _currentUid,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(resp.body);
      if (resp.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Student loan cleared!'), backgroundColor: _neonCyan),
        );
        _loadParentData();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Settlement failed'), backgroundColor: _neonPink),
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
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Parent Savings Vault & Support', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: _cardColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: _neonCyan), onPressed: _loadParentData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _neonCyan))
          : RefreshIndicator(
              onRefresh: _loadParentData,
              color: _neonCyan,
              backgroundColor: _cardColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Family Reserve Hero Card
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_neonPink, Color(0xFF8C1B4A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [BoxShadow(color: _neonPink.withOpacity(0.2), blurRadius: 20, spreadRadius: 2)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Family Reserve Vault', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                                child: Text('${_linkedStudents.length} Students Protected', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'KES ${_vaultBalance.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _neonCyan,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.add_circle, size: 18),
                                  label: const Text('Fund via M-PESA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  onPressed: _showDepositDialog,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Pending Student Loan Requests
                    if (_pendingLoans.isNotEmpty) ...[
                      const Text('🚨 Urgent Student Loan Assistance Requests', style: TextStyle(color: _neonPink, fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 10),
                      ..._pendingLoans.map((loan) {
                        final amt = (loan['amount'] ?? 0).toString();
                        final total = (loan['current_total_due'] ?? loan['total_due'] ?? amt).toString();
                        final sName = loan['student_name'] ?? 'Your student';
                        final purpose = loan['purpose'] ?? 'Study & Food Support';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _cardColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: _neonPink.withOpacity(0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: _neonPink, size: 24),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('$sName: KES $amt Loan', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                        Text('Purpose: $purpose', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Text('Due: KES $total', style: const TextStyle(color: _neonPink, fontWeight: FontWeight.w900, fontSize: 14)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _neonCyan,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => _settleStudentLoan(loan),
                                child: Text('Settle KES $total for $sName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                    ],

                    // Linked Students' Category Savings Vaults
                    const Text('Student Savings Goals', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),

                    if (_studentVaults.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
                        child: const Center(
                          child: Text(
                            'Your linked students have not created custom savings goals yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _textSecondary, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ..._studentVaults.map((v) {
                        final sName = v['student_name'] ?? 'Student';
                        final title = v['title'] ?? 'Savings Goal';
                        final cat = v['category'] ?? 'General';
                        final cBal = (v['current_balance'] as num?)?.toDouble() ?? 0.0;
                        final tAmt = (v['target_amount'] as num?)?.toDouble() ?? 1000.0;
                        final progress = ((cBal / (tAmt > 0 ? tAmt : 1.0)) * 100.0).clamp(0.0, 100.0);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _cardColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('$sName: $title', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                      Text(cat, style: const TextStyle(color: _neonCyan, fontSize: 11)),
                                    ],
                                  ),
                                  Text('KES ${cBal.toStringAsFixed(0)} / ${tAmt.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: progress / 100.0,
                                  backgroundColor: _surfaceLight,
                                  valueColor: const AlwaysStoppedAnimation<Color>(_neonCyan),
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _neonBlue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.card_giftcard, size: 14),
                                    label: const Text('Contribute / Gift', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                    onPressed: () => _showGiftStudentVaultDialog(v),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }
}
