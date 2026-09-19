import 'package:flutter/material.dart';
import '../../../core/models/user_model.dart';
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
      'id': 'free_delivery',
      'title': 'Free Peer Delivery',
      'desc': 'Get your next campus delivery entirely free!',
      'icon': Icons.two_wheeler,
      'cost': 500,
      'color': Colors.orange,
    },
    {
      'id': 'discount_10',
      'title': '10% Vendor Discount',
      'desc': 'Unlock a 10% promo code for any food vendor.',
      'icon': Icons.local_offer,
      'cost': 1000,
      'color': Colors.greenAccent,
    },
    {
      'id': 'vip_badge',
      'title': 'VIP Campus Badge',
      'desc': 'A shiny premium badge next to your name on the platform.',
      'icon': Icons.workspace_premium,
      'cost': 2500,
      'color': Colors.amber,
    },
  ];

  Future<void> _purchaseItem(String itemId, int cost, int currentCoins) async {
    if (currentCoins < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough Dishi Coins!'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://swapeatbackend.vercel.app/api/v1/games/redeem'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.userModel.uid}'},
        body: json.encode({'item_id': itemId}),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _cardColor,
            title: const Text('Success! 🎉', style: TextStyle(color: Colors.white)),
            content: Text('You successfully redeemed: \$itemId!', style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: Color(0xFF05D5AA))),
              )
            ],
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Purchase failed'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Try again later.'), backgroundColor: Colors.redAccent),
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
                                onPressed: (_isProcessing || !canAfford) ? null : () => _purchaseItem(item['id'] as String, item['cost'] as int, currentCoins),
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
