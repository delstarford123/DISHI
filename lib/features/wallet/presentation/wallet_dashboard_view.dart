import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/services/secure_http_client.dart';
import '../../../core/services/api_config.dart';

class WalletDashboardView extends StatefulWidget {
  const WalletDashboardView({super.key});

  @override
  State<WalletDashboardView> createState() => _WalletDashboardViewState();
}

class _WalletDashboardViewState extends State<WalletDashboardView> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isWithdrawing = false;

  Future<void> _withdrawToMpesa(double balance) async {
    if (balance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance to withdraw')),
      );
      return;
    }

    setState(() => _isWithdrawing = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not authenticated");

      final response = await SecureHttpClient.post(
        ApiConfig.buildUrl('/api/v1/mpesa/b2c'),
        body: {
          'user_id': user.uid,
          'amount': balance,
        }
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Withdrawal initiated successfully!')),
          );
        }
      } else {
        throw Exception("Failed to process withdrawal");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Withdrawal failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isWithdrawing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Not logged in")));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('My Wallet', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: MPesaTheme.primaryGreen));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final double balance = (userData['walletBalance'] ?? 0.0).toDouble();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Balance Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [MPesaTheme.primaryGreen, Color(0xFF0D9488)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: MPesaTheme.primaryGreen.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Balance',
                        style: TextStyle(color: Colors.white70, fontSize: 16, fontFamily: 'Outfit'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'KES ${balance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit'
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Withdraw Button
                ElevatedButton.icon(
                  onPressed: _isWithdrawing ? null : () => _withdrawToMpesa(balance),
                  icon: _isWithdrawing 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.account_balance_wallet),
                  label: Text(
                    _isWithdrawing ? 'Processing...' : 'Withdraw to M-PESA',
                    style: const TextStyle(fontSize: 16, fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MPesaTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
