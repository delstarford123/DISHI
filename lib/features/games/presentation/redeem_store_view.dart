import 'package:flutter/material.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/api_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RedeemStoreView extends StatefulWidget {
  final UserModel userModel;

  const RedeemStoreView({super.key, required this.userModel});

  @override
  State<RedeemStoreView> createState() => _RedeemStoreViewState();
}

class _RedeemStoreViewState extends State<RedeemStoreView> {
  final Color _bgColor = const Color(0xFF0C101B);
  final Color _cardColor = const Color(0xFF131A2A);
  final Color _neonCyan = const Color(0xFF05D5AA);

  bool _isProcessing = false;

  final List<Map<String, dynamic>> storeItems = [
    {
      'id': 'cash_50',
      'title': 'KES 50 DISHI Wallet Cash',
      'desc': 'Convert 1,000 coins directly into KES 50 usable anywhere on DISHI!',
      'icon': Icons.account_balance_wallet,
      'cost': 1000,
      'color': Colors.greenAccent,
      'badge': 'MOST POPULAR 🔥',
    },
    {
      'id': 'cash_100',
      'title': 'KES 100 DISHI Wallet Cash',
      'desc': 'Convert 2,000 coins into KES 100 real wallet balance for meals or delivery.',
      'icon': Icons.monetization_on,
      'cost': 2000,
      'color': Colors.amberAccent,
      'badge': 'BEST VALUE 💎',
    },
    {
      'id': 'free_delivery',
      'title': 'Free Peer Delivery Pass',
      'desc': 'Waives delivery fee completely on your next campus order.',
      'icon': Icons.two_wheeler,
      'cost': 500,
      'color': Colors.orangeAccent,
      'badge': 'INSTANT',
    },
    {
      'id': 'discount_10',
      'title': '10% Meal Discount Voucher',
      'desc': 'Save 10% on your next vendor order at any campus cafeteria.',
      'icon': Icons.local_offer,
      'cost': 750,
      'color': Colors.cyanAccent,
      'badge': 'CAMPUS EATS',
    },
    {
      'id': 'vip_badge',
      'title': 'VIP Gold Platform Badge',
      'desc': 'Exclusive gold VIP crest shown on your campus profile and leaderboard.',
      'icon': Icons.workspace_premium,
      'cost': 2500,
      'color': Colors.purpleAccent,
      'badge': 'STATUS 👑',
    },
  ];

  Future<void> _purchaseItem(String itemId, String itemTitle, int cost, int currentCoins) async {
    if (currentCoins < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough Dishi Coins! Play games to earn more.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      bool redeemedSuccessfully = false;

      // 1. Try Backend Endpoint
      try {
        final response = await http.post(
          Uri.parse(ApiConfig.gamesRedeem),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.userModel.uid}'},
          body: json.encode({'item_id': itemId}),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          redeemedSuccessfully = true;
        }
      } catch (_) {
        // Fallback to client-side transaction
      }

      // 2. Direct atomic Firestore transaction fallback
      if (!redeemedSuccessfully) {
        final userRef = FirebaseFirestore.instance.collection('users').doc(widget.userModel.uid);
        final statsRef = FirebaseFirestore.instance.collection('user_game_stats').doc(widget.userModel.uid);

        await FirebaseFirestore.instance.runTransaction((tx) async {
          final snap = await tx.get(userRef);
          final coins = (snap.data()?['dishi_coins'] ?? 0) as int;
          if (coins < cost) throw Exception('Insufficient Dishi Coins');

          final Map<String, dynamic> userUpdates = {
            'dishi_coins': coins - cost,
          };

          if (itemId == 'cash_50') {
            userUpdates['walletBalance'] = FieldValue.increment(50.0);
          } else if (itemId == 'cash_100') {
            userUpdates['walletBalance'] = FieldValue.increment(100.0);
          } else if (itemId == 'vip_badge') {
            userUpdates['premium_badge'] = true;
            userUpdates['isVipBadge'] = true;
          }

          tx.update(userRef, userUpdates);

          if (itemId == 'free_delivery') {
            tx.set(statsRef, {'free_deliveries': FieldValue.increment(1)}, SetOptions(merge: true));
          } else if (itemId == 'discount_10') {
            tx.set(statsRef, {'discount_vouchers': FieldValue.increment(1)}, SetOptions(merge: true));
          }

          final txDoc = FirebaseFirestore.instance.collection('transactions').doc();
          tx.set(txDoc, {
            'studentId': widget.userModel.uid,
            'type': 'game_coin_redemption',
            'rewardId': itemId,
            'rewardTitle': itemTitle,
            'coinsDeducted': cost,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'completed',
          });
        });
        redeemedSuccessfully = true;
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _cardColor,
          title: const Row(
            children: [
              Icon(Icons.stars, color: Colors.amber, size: 28),
              SizedBox(width: 8),
              Text('Redeemed! 🎉', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You successfully redeemed:\n$itemTitle', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _neonCyan.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Text(
                  itemId.startsWith('cash_')
                      ? 'Funds credited directly to your DISHI Wallet balance!'
                      : 'Reward active on your account! Check your dashboard/vouchers.',
                  style: TextStyle(color: _neonCyan, fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _neonCyan),
              onPressed: () => Navigator.pop(context),
              child: const Text('Awesome!', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Redemption error: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Redeem Store', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.userModel.uid).snapshots(),
        builder: (context, snapshot) {
          int currentCoins = 0;
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            currentCoins = (data?['dishi_coins'] ?? 0) as int;
          }

          return Column(
            children: [
              // Header Balance
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _neonCyan.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Available Coins', style: TextStyle(color: Colors.white70, fontSize: 18)),
                    Row(
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.amber, size: 28),
                        const SizedBox(width: 8),
                        Text(
                          '$currentCoins',
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Store Items
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: storeItems.length,
                  itemBuilder: (context, index) {
                    final item = storeItems[index];
                    final canAfford = currentCoins >= (item['cost'] as int);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (item['color'] as Color).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 30),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['title'] as String, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(item['desc'] as String, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${item['cost']} 🪙', style: TextStyle(color: canAfford ? _neonCyan : Colors.redAccent, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canAfford ? _neonCyan : Colors.grey.withOpacity(0.3),
                                  foregroundColor: canAfford ? Colors.black : Colors.white54,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                onPressed: (_isProcessing || !canAfford) ? null : () => _purchaseItem(item['id'] as String, item['title'] as String, item['cost'] as int, currentCoins),
                                child: _isProcessing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('BUY'),
                              )
                            ],
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
