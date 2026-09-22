import 'package:flutter/material.dart';
import '../../../core/models/user_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'coins_display.dart';
import 'dart:math';

class VibeCheckGame extends StatefulWidget {
  final UserModel userModel;

  const VibeCheckGame({super.key, required this.userModel});

  @override
  State<VibeCheckGame> createState() => _VibeCheckGameState();
}

class FoodCombo {
  final String icon1;
  final String icon2;
  final String name;

  FoodCombo(this.icon1, this.icon2, this.name);
}

class _VibeCheckGameState extends State<VibeCheckGame> {
  final Color _bgColor = const Color(0xFF0C101B);
  final Color _neonCyan = const Color(0xFF05D5AA);
  final Color _neonPink = const Color(0xFFF92B60);
  final Color _cardColor = const Color(0xFF131A2A);

  List<FoodCombo> combos = [];
  int currentIndex = 0;
  int score = 0; // Coins earned
  bool isGameOver = false;

  double dragOffset = 0;
  double dragAngle = 0;

  @override
  void initState() {
    super.initState();
    _generateCombos();
  }

  void _generateCombos() {
    final List<FoodCombo> combos = [
      FoodCombo('🍔', '📖', 'Classic Combo'),
      FoodCombo('🍕', '🥬', 'Avocado Pizza'),
      FoodCombo('🍎', '🍽️', 'Apple Taco'),
      FoodCombo('🍔', '🍩', 'Donut Burger'),
      FoodCombo('📖', '🍿', 'Salty Mix'),
    ];
    combos.shuffle();
    setState(() {
      this.combos = combos;
      currentIndex = 0;
      score = 0;
      isGameOver = false;
      dragOffset = 0;
      dragAngle = 0;
    });
  }

  void _handleSwipe(bool isFire) {
    if (isGameOver) return;

    setState(() {
      score += 10; // Earn 10 coins per swipe
      dragOffset = 0;
      dragAngle = 0;
      if (currentIndex < combos.length - 1) {
        currentIndex++;
      } else {
        isGameOver = true;
        _submitScore();
      }
    });
  }

  Future<void> _submitScore() async {
    try {
      if (score > 0) {
        await http.post(
          Uri.parse('https://swapeatbackend.vercel.app/api/v1/games/score'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.userModel.uid}'},
          body: json.encode({'game_id': 'vibe_check', 'score': score * 100}), // Scaled for backend coins
        ).timeout(const Duration(seconds: 15));
      }
    } catch (e) {
      print("Error submitting vibe check score: \$e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Vibe Check', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
        actions: [CoinsDisplay(uid: widget.userModel.uid)],
      ),
      body: isGameOver ? _buildGameOver() : _buildGameArea(),
    );
  }

  Widget _buildGameArea() {
    if (combos.isEmpty) return const SizedBox();
    
    final currentCombo = combos[currentIndex];
    
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Rate the Food Combo!\nSwipe Right for 🔥, Left for 🗑️', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16)),
        ),
        
        Expanded(
          child: Center(
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  dragOffset += details.delta.dx;
                  dragAngle = dragOffset / 300;
                });
              },
              onPanEnd: (details) {
                if (dragOffset > 100) {
                  _handleSwipe(true); // Fire
                } else if (dragOffset < -100) {
                  _handleSwipe(false); // Trash
                } else {
                  // Snap back
                  setState(() {
                    dragOffset = 0;
                    dragAngle = 0;
                  });
                }
              },
              child: Transform.translate(
                offset: Offset(dragOffset, 0),
                child: Transform.rotate(
                  angle: dragAngle,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: MediaQuery.of(context).size.height * 0.5,
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: dragOffset > 0 ? Colors.orangeAccent.withOpacity(min(dragOffset/200, 1.0)) : 
                               (dragOffset < 0 ? Colors.grey.withOpacity(min(-dragOffset/200, 1.0)) : _neonCyan.withOpacity(0.3)),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _neonCyan.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(currentCombo.icon1, style: TextStyle(fontSize: 80)),
                            const Text('+', style: TextStyle(color: Colors.white, fontSize: 40)),
                            Text(currentCombo.icon2, style: TextStyle(fontSize: 80)),
                          ],
                        ),
                        const SizedBox(height: 30),
                        Text(currentCombo.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        Text('${currentIndex + 1} / ${combos.length}', style: const TextStyle(color: Colors.white38, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Buttons
        Padding(
          padding: const EdgeInsets.only(bottom: 40.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(
                heroTag: 'btnTrash',
                backgroundColor: Colors.grey.shade800,
                onPressed: () => _handleSwipe(false),
                child: const Text('🗑️', style: TextStyle(fontSize: 30)),
              ),
              FloatingActionButton(
                heroTag: 'btnFire',
                backgroundColor: Colors.orangeAccent,
                onPressed: () => _handleSwipe(true),
                child: const Icon(Icons.local_fire_department, color: Colors.white, size: 30),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGameOver() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 100)),
          const SizedBox(height: 20),
          const Text('Vibe Check Complete!', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('You earned $score Coins!', style: TextStyle(color: _neonCyan, fontSize: 24)),
          const SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _neonCyan,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('BACK TO HUB', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
