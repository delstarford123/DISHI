import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/user_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'coins_display.dart';

class DormTycoonGame extends StatefulWidget {
  final UserModel userModel;

  const DormTycoonGame({super.key, required this.userModel});

  @override
  State<DormTycoonGame> createState() => _DormTycoonGameState();
}

class UpgradeItem {
  final String name;
  final String emoji;
  final int cps; // Cash per second
  int cost;
  int count = 0;

  UpgradeItem(this.name, this.emoji, this.cps, this.cost);
}

class _DormTycoonGameState extends State<DormTycoonGame> {
  final Color _bgColor = const Color(0xFF0C101B);
  final Color _neonCyan = const Color(0xFF05D5AA);
  final Color _cardColor = const Color(0xFF131A2A);

  double tycoonCash = 0;
  double cps = 0; // Cash per second
  Timer? loopTimer;

  List<UpgradeItem> upgrades = [];

  @override
  void initState() {
    super.initState();
    upgrades = [
      UpgradeItem("Kettle", "☕", 1, 50),
      UpgradeItem("Mini Fridge", "🧊", 5, 250),
      UpgradeItem("Better Wi-Fi", "📶", 15, 1000),
      UpgradeItem("Snack Cart", "🛒", 50, 5000),
    ];

    loopTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (cps > 0) {
        setState(() {
          tycoonCash += cps;
        });
      }
    });
  }

  void _hustle() {
    setState(() {
      tycoonCash += 1;
    });
  }

  void _buyUpgrade(UpgradeItem item) {
    if (tycoonCash >= item.cost) {
      setState(() {
        tycoonCash -= item.cost;
        item.count++;
        cps += item.cps;
        item.cost = (item.cost * 1.5).round(); // Increase cost for next one
      });
    }
  }

  Future<void> _saveAndExit() async {
    loopTimer?.cancel();
    try {
      // We convert Tycoon cash to Dishi coins (e.g. 100 Tycoon cash = 1 Dishi Coin)
      int earnedCoins = (tycoonCash / 100).floor();
      if (earnedCoins > 0) {
        await http.post(
          Uri.parse('https://swapeatbackend.vercel.app/api/v1/games/score'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.userModel.uid}'},
          body: json.encode({'game_id': 'dorm_tycoon', 'score': earnedCoins}),
        ).timeout(const Duration(seconds: 15));
      }
    } catch (e) {
      print("Error saving tycoon score: \$e");
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    loopTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Dorm Tycoon', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
        actions: [CoinsDisplay(uid: widget.userModel.uid)],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _saveAndExit,
        ),
      ),
      body: Column(
        children: [
          // Dashboard
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_cardColor, _bgColor],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border(bottom: BorderSide(color: _neonCyan.withOpacity(0.3))),
            ),
            child: Column(
              children: [
                const Text('Tycoon Cash', style: TextStyle(color: Colors.white54, fontSize: 16)),
                const SizedBox(height: 8),
                Text(
                  '\$${tycoonCash.floor()}',
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 48, fontWeight: FontWeight.bold),
                ),
                Text(
                  '+$cps / sec',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),

          // Hustle Button
          GestureDetector(
            onTap: _hustle,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: _cardColor,
                shape: BoxShape.circle,
                border: Border.all(color: _neonCyan, width: 4),
                boxShadow: [
                  BoxShadow(color: _neonCyan.withOpacity(0.3), blurRadius: 30, spreadRadius: 5),
                ],
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🤑', style: TextStyle(fontSize: 40)),
                    SizedBox(height: 8),
                    Text('HUSTLE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Upgrades', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),

          // Upgrades List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: upgrades.length,
              itemBuilder: (context, index) {
                final item = upgrades[index];
                bool canAfford = tycoonCash >= item.cost;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      Text(item.emoji, style: const TextStyle(fontSize: 30)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('+${item.cps} CPS • Owned: ${item.count}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canAfford ? _neonCyan : Colors.grey[800],
                          foregroundColor: canAfford ? Colors.black : Colors.white54,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: canAfford ? () => _buyUpgrade(item) : null,
                        child: Text('\$${item.cost}'),
                      )
                    ],
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
