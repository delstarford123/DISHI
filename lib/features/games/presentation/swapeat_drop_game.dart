import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/models/user_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SwapEatDropGame extends StatefulWidget {
  final UserModel userModel;

  const SwapEatDropGame({super.key, required this.userModel});

  @override
  State<SwapEatDropGame> createState() => _SwapEatDropGameState();
}

class FallingObject {
  double x;
  double y;
  final bool isBad;
  final String emoji;

  FallingObject({required this.x, required this.y, required this.isBad, required this.emoji});
}

class _SwapEatDropGameState extends State<SwapEatDropGame> {
  double basketX = 0.5; // 0.0 to 1.0
  List<FallingObject> objects = [];
  bool isPlaying = false;
  bool isGameOver = false;
  int score = 0;
  int lives = 3;
  Timer? gameTimer;
  Timer? spawnTimer;

  final Color _bgColor = const Color(0xFF0C101B);
  final Color _neonCyan = const Color(0xFF05D5AA);
  final Color _neonPink = const Color(0xFFF92B60);

  final List<String> goodFoods = ['🍔', '🍟', '🍕', '🍎', '🌮'];
  final List<String> badItems = ['📚', '☠️', '🗑️'];

  void startGame() {
    setState(() {
      isPlaying = true;
      isGameOver = false;
      score = 0;
      lives = 3;
      basketX = 0.5;
      objects.clear();
    });

    gameTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      updateGame();
    });

    spawnTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (isPlaying) {
        spawnObject();
      }
    });
  }

  void spawnObject() {
    final rand = Random();
    final isBad = rand.nextDouble() > 0.7; // 30% chance to be bad
    final list = isBad ? badItems : goodFoods;
    final emoji = list[rand.nextInt(list.length)];
    
    setState(() {
      objects.add(FallingObject(
        x: rand.nextDouble() * 0.8 + 0.1, // keep within screen bounds
        y: -0.1,
        isBad: isBad,
        emoji: emoji,
      ));
    });
  }

  void updateGame() {
    if (!isPlaying) return;
    
    setState(() {
      List<FallingObject> toRemove = [];
      for (var obj in objects) {
        // Increase speed slightly over time or based on score (currently constant speed)
        obj.y += 0.015 + (score * 0.0001); 

        // Check collision (basket is around y = 0.85 to 0.9)
        if (obj.y > 0.85 && obj.y < 0.95) {
          // Basket width is about 0.2 (0.1 each side)
          if ((obj.x - basketX).abs() < 0.15) {
            if (obj.isBad) {
              score -= 10;
              if (score < 0) score = 0;
              lives -= 1;
              if (lives <= 0) {
                gameOver();
              }
            } else {
              score += 10;
            }
            toRemove.add(obj);
          }
        }
        
        // Missed object
        if (obj.y > 1.0) {
          if (!obj.isBad) {
            // Missed good food? Maybe lose a life if we want to make it hard
            // For now, no penalty for missing
          }
          toRemove.add(obj);
        }
      }

      for (var r in toRemove) {
        objects.remove(r);
      }
    });
  }

  void gameOver() {
    gameTimer?.cancel();
    spawnTimer?.cancel();
    setState(() {
      isPlaying = false;
      isGameOver = true;
    });
    _submitScore();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: const Center(child: Text('YOU LOSE', style: TextStyle(color: Colors.redAccent, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2.0))),
        content: Text('You scored: $score', style: const TextStyle(color: Colors.white70, fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Quit', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonCyan),
            onPressed: () {
              Navigator.of(context).pop();
              startGame();
            },
            child: const Text('Play Again', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitScore() async {
    try {
      await http.post(
        Uri.parse('https://swapeatbackend.vercel.app/api/v1/games/score'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.userModel.uid}'},
        body: json.encode({'game_id': 'swapeat_drop', 'score': score}),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      print("Error submitting score: \$e");
    }
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    spawnTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('DISHI Drop', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Background/Play Area
          GestureDetector(
            onPanUpdate: (details) {
              if (!isPlaying) return;
              setState(() {
                // Approximate mapping of delta to percentage
                basketX += details.delta.dx / MediaQuery.of(context).size.width;
                if (basketX < 0.1) basketX = 0.1;
                if (basketX > 0.9) basketX = 0.9;
              });
            },
            child: Container(
              color: Colors.transparent,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          
          // Falling Objects
          ...objects.map((obj) {
            return Align(
              alignment: Alignment(obj.x * 2 - 1, obj.y * 2 - 1),
              child: Text(obj.emoji, style: const TextStyle(fontSize: 40)),
            );
          }),

          // Basket
          if (isPlaying || isGameOver)
            Align(
              alignment: Alignment(basketX * 2 - 1, 0.9), // y is around 0.9
              child: Container(
                width: 80,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: const Center(child: Text('🛒', style: TextStyle(fontSize: 24))),
              ),
            ),

          // HUD
          if (isPlaying || isGameOver)
            Positioned(
              top: 10,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Score: $score', style: TextStyle(color: _neonCyan, fontSize: 24, fontWeight: FontWeight.bold)),
                  Row(
                    children: List.generate(3, (index) {
                      return Icon(
                        index < lives ? Icons.favorite : Icons.favorite_border,
                        color: _neonPink,
                        size: 28,
                      );
                    }),
                  )
                ],
              ),
            ),

          // Start Screen
          if (!isPlaying && !isGameOver)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Catch the food 🍔\nDodge the books 📚', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 18)),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonCyan,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: startGame,
                    child: const Text('START GAME', style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
        ],
      ),
    );
  }
}
