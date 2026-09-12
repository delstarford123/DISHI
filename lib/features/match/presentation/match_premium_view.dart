import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonPurple = Color(0xFF9C27B0);
const Color _textSecondary = Color(0xFF8B9BB4);

class MatchPremiumView extends StatefulWidget {
  final Map<String, dynamic>? userModel;
  
  const MatchPremiumView({super.key, this.userModel});

  @override
  State<MatchPremiumView> createState() => _MatchPremiumViewState();
}

class _MatchPremiumViewState extends State<MatchPremiumView> {
  bool _isBoosting = false;

  Future<void> _boostProfile() async {
    setState(() => _isBoosting = true);
    final String uid = widget.userModel?['uid'] ?? 'guest';

    try {
      if (uid != 'guest') {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'isBoosted': true,
          'boostedAt': FieldValue.serverTimestamp(),
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile Boosted! 🚀 -50 KSH deducted.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBoosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('DISHI Match Premium', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(Icons.diamond, color: _neonPink, size: 80),
          const SizedBox(height: 16),
          const Text('Unlock Premium Features', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          _buildFeatureRow(Icons.visibility, 'See who liked you instantly'),
          _buildFeatureRow(Icons.mic, 'Send Voice Notes in Chat'),
          _buildFeatureRow(Icons.fast_forward, 'Unlimited Swipes & Matches'),
          _buildFeatureRow(Icons.rocket_launch, 'One Free Profile Boost per week'),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: _neonPink, width: 2)),
            child: const Column(
              children: [
                Text('KES 200 / Month', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Billed directly to your DISHI Wallet', style: TextStyle(color: _textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonPink, padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: () {},
            child: const Text('UPGRADE TO PREMIUM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 40),
          const Divider(color: _surfaceLight),
          const SizedBox(height: 24),
          const Text('A la Carte Features', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Profile Boost', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Top of stack for 30 mins', style: TextStyle(color: _textSecondary, fontSize: 12)),
                  ],
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: _isBoosting ? null : _boostProfile,
                  child: _isBoosting 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                      : const Text('50 KSH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: _neonPink),
          const SizedBox(width: 16),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }
}
