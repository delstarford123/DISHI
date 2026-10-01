import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/models/user_model.dart';

class SwipeExchangeView extends StatefulWidget {
  final UserModel userModel;

  const SwipeExchangeView({super.key, required this.userModel});

  @override
  State<SwipeExchangeView> createState() => _SwipeExchangeViewState();
}

class _SwipeExchangeViewState extends State<SwipeExchangeView> {
  int _swipesToTrade = 1;
  final double _exchangeRate = 150.0;
  bool _isLoading = false;

  void _increment(int maxSwipes) {
    if (_swipesToTrade < maxSwipes) setState(() => _swipesToTrade++);
  }
  
  void _decrement() {
    if (_swipesToTrade > 1) setState(() => _swipesToTrade--);
  }

  Future<void> _tradeSwipes(int currentSwipes) async {
    if (_swipesToTrade > currentSwipes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough dining swipes!')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final totalValue = _swipesToTrade * _exchangeRate;
      final uid = widget.userModel.uid;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);
        final userSnapshot = await transaction.get(userDocRef);
        
        if (!userSnapshot.exists) {
          throw Exception("User does not exist!");
        }
        
        final data = userSnapshot.data() as Map<String, dynamic>;
        int dbSwipes = data['diningSwipes'] ?? 0;
        double currentWalletBalance = (data['walletBalance'] ?? 0.0).toDouble();
        
        if (dbSwipes < _swipesToTrade) {
          throw Exception("Not enough dining swipes to trade!");
        }
        
        // Deduct swipes, add balance
        transaction.update(userDocRef, {
          'diningSwipes': dbSwipes - _swipesToTrade,
          'walletBalance': currentWalletBalance + totalValue,
        });
        
        // Create a transaction record
        final txRef = FirebaseFirestore.instance.collection('wallet_transactions').doc();
        transaction.set(txRef, {
          'uid': uid,
          'type': 'swipe_exchange',
          'amount': totalValue,
          'swipes_traded': _swipesToTrade,
          'timestamp': FieldValue.serverTimestamp(),
          'description': 'Exchanged $_swipesToTrade dining swipes for KES $totalValue',
          'status': 'completed'
        });
      });

      if (mounted) {
        setState(() {
          _isLoading = false;
          _swipesToTrade = 1; // Reset selector
        });
        
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF131A2A),
            title: const Text('Trade Successful! 🎉', style: TextStyle(color: Colors.white)),
            content: Text(
              'You have successfully traded $_swipesToTrade meal swipes for KES $totalValue. The funds have been added to your DISHI Wallet.',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back
                },
                child: const Text('Awesome', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              )
            ],
          )
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalValue = _swipesToTrade * _exchangeRate;

    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Swipe Exchange'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.userModel.uid).snapshots(),
        builder: (context, snapshot) {
          int currentSwipes = 0;
          if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            currentSwipes = data['diningSwipes'] ?? 0;
          }

          // Ensure selector isn't higher than available swipes
          if (_swipesToTrade > currentSwipes && currentSwipes > 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() => _swipesToTrade = currentSwipes);
            });
          }

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.restaurant, color: Colors.orangeAccent, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Trade Dining Swipes',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Exchange your unused dining hall swipes for DISHI Wallet balance. Current rate: KES 150 per swipe.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Available Swipes: $currentSwipes',
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 48),
                
                // Selector
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131A2A),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text('How many swipes to trade?', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: _decrement,
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.orangeAccent, size: 40),
                          ),
                          const SizedBox(width: 32),
                          Text('$_swipesToTrade', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 32),
                          IconButton(
                            onPressed: () => _increment(currentSwipes),
                            icon: const Icon(Icons.add_circle_outline, color: Colors.orangeAccent, size: 40),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const Divider(color: Colors.white12),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('You will receive:', style: TextStyle(color: Colors.white54, fontSize: 16)),
                          Text('KES $totalValue', style: const TextStyle(color: MPesaTheme.primaryGreen, fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                ),
                
                const Spacer(),
                
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MPesaTheme.primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: (_isLoading || currentSwipes == 0) ? null : () => _tradeSwipes(currentSwipes),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.black)
                      : Text(currentSwipes == 0 ? 'No Swipes Available' : 'Trade Now', style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          );
        }
      ),
    );
  }
}
