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
      'id': 'game_pass_bronze',
      'title': 'Casual Game Unlock Pass',
      'desc': 'Unlock any 1 Casual arcade game in the DISHI Games Hub permanently!',
      'icon': Icons.sports_esports,
      'cost': 400,
      'color': Colors.amberAccent,
      'badge': 'CASUAL PASS 🎮',
    },
    {
      'id': 'game_pass_silver',
      'title': 'Social & Matching Game Pass',
      'desc': 'Unlock any 1 Social or Trivia game in the Games Hub permanently.',
      'icon': Icons.favorite,
      'cost': 800,
      'color': Colors.cyanAccent,
      'badge': 'PRO PASS ⚡',
    },
    {
      'id': 'game_pass_gold',
      'title': 'Tycoon & Strategy Game Pass',
      'desc': 'Unlock top-tier simulation games (Dorm Tycoon or Scavenger Hunt).',
      'icon': Icons.store,
      'cost': 1500,
      'color': Colors.purpleAccent,
      'badge': 'MASTER PASS 🏆',
    },
    {
      'id': 'vip_badge',
      'title': 'VIP Gold Arcade Badge',
      'desc': 'Exclusive gold VIP crest shown on your campus profile and games leaderboard.',
      'icon': Icons.workspace_premium,
      'cost': 2500,
      'color': Colors.amber,
      'badge': 'STATUS 👑',
    },
  ];

  Future<void> _purchaseItem(String itemId, String itemTitle, int cost, int currentCoins) async {
    if (currentCoins < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough Arcade Coins! Play games to earn more.'), backgroundColor: Colors.redAccent),
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

        await FirebaseFirestore.instance.runTransaction((tx) async {
          final snap = await tx.get(userRef);
          final coins = (snap.data()?['dishi_coins'] ?? 0) as int;
          if (coins < cost) throw Exception('Insufficient Arcade Coins');

          final Map<String, dynamic> userUpdates = {
            'dishi_coins': coins - cost,
          };

          if (itemId == 'vip_badge') {
            userUpdates['premium_badge'] = true;
            userUpdates['isVipBadge'] = true;
          } else if (itemId == 'game_pass_bronze') {
            final List<dynamic> cur = List.from(snap.data()?['unlocked_games'] ?? ['delivery_dash', 'daily_spin']);
            if (!cur.contains('hungry_fresher')) cur.add('hungry_fresher');
            userUpdates['unlocked_games'] = cur;
          } else if (itemId == 'game_pass_silver') {
            final List<dynamic> cur = List.from(snap.data()?['unlocked_games'] ?? ['delivery_dash', 'daily_spin']);
            if (!cur.contains('bite_ninja')) cur.add('bite_ninja');
            userUpdates['unlocked_games'] = cur;
          } else if (itemId == 'game_pass_gold') {
            final List<dynamic> cur = List.from(snap.data()?['unlocked_games'] ?? ['delivery_dash', 'daily_spin']);
            if (!cur.contains('dorm_tycoon')) cur.add('dorm_tycoon');
            userUpdates['unlocked_games'] = cur;
          }

          tx.update(userRef, userUpdates);

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
              Text('Unlocked! 🎉', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  'Perk active! Return to Games Hub to play your unlocked games.',
                  style: TextStyle(color: _neonCyan, fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _neonCyan),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // back to Games Hub
              },
              child: const Text('Go to Games Hub', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
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
        title: const Text('Arcade Game Store', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
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

              // Policy Disclaimer Banner
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.withOpacity(0.35)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'DISHI Arcade Coins are strictly virtual in-app tokens used exclusively to unlock games and arcade perks. They cannot be converted to real cash or used for meals.',
                        style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

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
