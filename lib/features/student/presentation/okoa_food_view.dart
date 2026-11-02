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
  String _currentUid = '';

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
                  Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Okoa Meal — Safety Net', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: _cardColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_neonOrange.withAlpha(40), _surfaceLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _neonOrange.withAlpha(60)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.favorite_rounded, size: 54, color: _neonOrange),
                  const SizedBox(height: 12),
                  const Text(
                    'Zero Hunger Campus Guarantee',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'No student should sit through exams or lectures on an empty stomach. Okoa Meal provides an interest-free emergency meal voucher instantly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Active Debt Banner if already used
            if (_currentDebt > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _neonPink.withAlpha(30),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _neonPink.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: _neonPink, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Active Okoa Voucher', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(
                            'Outstanding: KES ${_currentDebt.toStringAsFixed(0)}. Auto-deducted on your next top-up.',
                            style: const TextStyle(color: _textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Select Voucher Amount
            const Text('Choose Emergency Voucher:', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
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
            const SizedBox(height: 24),

            // Policy Guarantee Highlights
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
              child: const Column(
                children: [
                  _PolicyBullet(icon: Icons.check_circle_outline, text: '0% Interest — pay back exact voucher amount'),
                  SizedBox(height: 10),
                  _PolicyBullet(icon: Icons.lock_outline, text: 'Purpose-locked strictly to verified campus cafeterias'),
                  SizedBox(height: 10),
                  _PolicyBullet(icon: Icons.sync, text: 'Auto-settled seamlessly on your next wallet funding'),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Action Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentDebt > 0 ? Colors.grey : _neonCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: (_currentDebt > 0 || _isLoading) ? null : _requestOkoaMeal,
              child: _isLoading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                  : Text(
                      _currentDebt > 0 ? 'Voucher Already Active' : 'Activate KES ${_selectedVoucher.toStringAsFixed(0)} Meal Voucher',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),
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
      children: [
        Icon(icon, color: _neonCyan, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13))),
      ],
    );
  }
}
