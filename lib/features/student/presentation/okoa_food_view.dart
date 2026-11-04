import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/api_config.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonPink = Color(0xFFF92B60);
const Color _textSecondary = Color(0xFF8B9BB4);

class OkoaFoodView extends StatefulWidget {
  const OkoaFoodView({super.key});

  @override
  State<OkoaFoodView> createState() => _OkoaFoodViewState();
}

class _OkoaFoodViewState extends State<OkoaFoodView> {
  double _selectedVoucher = 200.0;
  bool _isLoading = false;
  double _currentDebt = 0.0;
  double _walletBalance = 0.0;
  String _currentUid = '';
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _fetchDebt();
  }

  Future<void> _fetchDebt() async {
    if (_currentUid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_currentUid).get();
      if (doc.exists && mounted) {
        final data = doc.data() ?? {};
        setState(() {
          _currentDebt = (data['okoa_debt'] as num?)?.toDouble() ?? 0.0;
          _walletBalance = (data['walletBalance'] as num?)?.toDouble() ?? 0.0;
        });
      }

      // Fetch recent records
      final records = await FirebaseFirestore.instance
          .collection('okoa_records')
          .where('student_uid', isEqualTo: _currentUid)
          .limit(5)
          .get();

      if (mounted) {
        setState(() {
          _history = records.docs.map((d) {
            final m = d.data();
            m['id'] = d.id;
            return m;
          }).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _requestOkoaMeal() async {
    if (_currentUid.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final resp = await http.post(
        Uri.parse(ApiConfig.v6OkoaMealRequest),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'student_uid': _currentUid,
          'amount': _selectedVoucher,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(resp.body);
      if (resp.statusCode == 200) {
        if (!mounted) return;
        _fetchDebt();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: _neonCyan),
                SizedBox(width: 8),
                Text('Meal Voucher Active!', style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: Text(
              data['message'] ?? 'KES ${_selectedVoucher.toStringAsFixed(0)} credited to your food allowance wallet.',
              style: const TextStyle(color: _textSecondary, fontSize: 13),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
                onPressed: () {
                  Navigator.pop(ctx);
                },
                child: const Text('Go Eat'),
              ),
            ],
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Could not activate Okoa Meal'), backgroundColor: _neonPink),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e'), backgroundColor: _neonPink),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _settleDebtFromWallet() async {
    if (_currentUid.isEmpty || _currentDebt <= 0) return;
    if (_walletBalance < _currentDebt) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient wallet balance (KES ${_walletBalance.toStringAsFixed(2)}) to clear KES ${_currentDebt.toStringAsFixed(2)}. Top up to auto-clear.'),
          backgroundColor: _neonPink,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final resp = await http.post(
        Uri.parse(ApiConfig.v6OkoaDebtSettle),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'student_uid': _currentUid}),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(resp.body);
      if (resp.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Debt settled in full!'), backgroundColor: _neonCyan),
        );
        _fetchDebt();
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
        title: const Text('Okoa Food — Safety Net', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: _cardColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _neonCyan),
            onPressed: _fetchDebt,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Live Debt / Credit Status Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _currentDebt > 0
                      ? [const Color(0xFF2C0B0E), const Color(0xFF4A1015)]
                      : [const Color(0xFF0F2027), const Color(0xFF203A43)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _currentDebt > 0 ? _neonPink.withOpacity(0.5) : _neonCyan.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_currentDebt > 0 ? _neonPink : _neonCyan).withOpacity(0.12),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _currentDebt > 0 ? 'Active Okoa Food Debt' : 'Okoa Safety Net Balance',
                        style: TextStyle(
                          color: _currentDebt > 0 ? _neonPink : Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (_currentDebt > 0 ? _neonPink : _neonCyan).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _currentDebt > 0 ? 'NEEDS REPAYMENT' : 'CREDIT READY',
                          style: TextStyle(
                            color: _currentDebt > 0 ? _neonPink : _neonCyan,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Formatted Display: e.g. -KES 200.00
                  Text(
                    _currentDebt > 0 ? '-KES ${_currentDebt.toStringAsFixed(2)}' : 'KES 0.00',
                    style: TextStyle(
                      color: _currentDebt > 0 ? _neonPink : Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _currentDebt > 0
                        ? 'You have an outstanding emergency meal debt of KES ${_currentDebt.toStringAsFixed(0)}. This will be auto-deducted the moment you top up your wallet.'
                        : 'Emergency meal credit available. Interest-free guarantee so no student ever studies on an empty stomach.',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  if (_currentDebt > 0) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _walletBalance >= _currentDebt ? _neonCyan : Colors.white12,
                              foregroundColor: _walletBalance >= _currentDebt ? Colors.black : Colors.white54,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: Text(
                              _walletBalance >= _currentDebt
                                  ? 'Settle from Wallet (KES ${_walletBalance.toStringAsFixed(0)} Avail)'
                                  : 'Top Up Wallet to Clear',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            onPressed: (_walletBalance >= _currentDebt && !_isLoading)
                                ? _settleDebtFromWallet
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Select Voucher Amount (if no debt)
            if (_currentDebt <= 0) ...[
              const Text('Select Emergency Meal Voucher:', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [150.0, 200.0, 300.0].map((amt) {
                  final isSel = (_selectedVoucher == amt);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () => setState(() => _selectedVoucher = amt),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: isSel ? _neonCyan : _cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isSel ? _neonCyan : Colors.white12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'KES ${amt.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: isSel ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                amt == 150 ? 'Snack/Tea' : (amt == 200 ? 'Standard Meal' : 'Full Combo'),
                                style: TextStyle(
                                  color: isSel ? Colors.black87 : _textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _neonCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isLoading ? null : _requestOkoaMeal,
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                    : Text(
                        'Activate KES ${_selectedVoucher.toStringAsFixed(0)} Emergency Meal Voucher',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
              ),
              const SizedBox(height: 20),
            ],

            // Zero-Hunger Guarantee Pillars
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DISHI Zero-Hunger Policy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  SizedBox(height: 12),
                  _PolicyBullet(icon: Icons.check_circle_outline, text: '0% Interest — You only repay the exact voucher amount.'),
                  SizedBox(height: 10),
                  _PolicyBullet(icon: Icons.sync_rounded, text: 'Auto-Deduction — Settle automatically the moment funds enter your wallet.'),
                  SizedBox(height: 10),
                  _PolicyBullet(icon: Icons.restaurant_rounded, text: 'Purpose-Locked — Valid across all approved campus cafeteria vendors.'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // History Records if available
            if (_history.isNotEmpty) ...[
              const Text('Recent Okoa Activity', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              ..._history.map((h) {
                final isSettled = h['status'] == 'settled';
                final amt = (h['amount'] ?? h['settled_amount'] ?? 0).toString();
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(isSettled ? Icons.check_circle : Icons.fastfood, color: isSettled ? _neonCyan : _neonPink, size: 18),
                          const SizedBox(width: 10),
                          Text(isSettled ? 'Debt Settled' : 'Meal Voucher Issued', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Text('${isSettled ? "+" : "-"}KES $amt', style: TextStyle(color: isSettled ? _neonCyan : _neonPink, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _PolicyBullet extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PolicyBullet({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _neonCyan, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: _textSecondary, fontSize: 12))),
      ],
    );
  }
}
