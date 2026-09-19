import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/models/user_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'coins_display.dart';

class DeliveryDashGame extends StatefulWidget {
  final UserModel userModel;

  const DeliveryDashGame({super.key, required this.userModel});

  @override
  State<DeliveryDashGame> createState() => _DeliveryDashGameState();
}

class Obstacle {
  double x;
  final String emoji;
  final double size;

  Obstacle(this.x, this.emoji, this.size);
}

class _DeliveryDashGameState extends State<DeliveryDashGame> {
  final Color _bgColor = const Color(0xFF0C101B);
  final Color _neonCyan = const Color(0xFF05D5AA);

  bool isPlaying = false;
  bool isGameOver = false;
  int score = 0;
  Timer? gameTimer;
  Timer? spawnTimer;

  // Player physics
  double playerY = 0; // 0 is ground, negative is up
  double velocityY = 0;
  final double gravity = 0.8;
  final double jumpStrength = -15.0;
  bool isJumping = false;

  List<Obstacle> obstacles = [];
  double gameSpeed = 5.0;

  final List<String> obstacleEmojis = ['🚧', '🕳️', '🚗', '🛑'];

  void startGame() {
    setState(() {
      isPlaying = true;
      isGameOver = false;
      score = 0;
      playerY = 0;
      velocityY = 0;
      isJumping = false;
      gameSpeed = 5.0;
      obstacles.clear();
    });

    gameTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      updateGame();
    });

    spawnTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (isPlaying) spawnObstacle();
    });
  }

  void spawnObstacle() {
    final rand = Random();
    final emoji = obstacleEmojis[rand.nextInt(obstacleEmojis.length)];
    setState(() {
      obstacles.add(Obstacle(MediaQuery.of(context).size.width, emoji, 40));
    });
  }

  void updateGame() {
    if (!isPlaying) return;

    setState(() {
      // Update score and speed
      score += 1;
      if (score % 500 == 0) gameSpeed += 1.0; // speed up over time

      // Player Physics
      velocityY += gravity;
      playerY += velocityY;

      if (playerY >= 0) {
        playerY = 0;
        velocityY = 0;
        isJumping = false;
      }

      // Obstacle Movement & Collision
      List<Obstacle> toRemove = [];
      for (var obs in obstacles) {
        obs.x -= gameSpeed;

        if (obs.x < -obs.size) {
          toRemove.add(obs);
        }

        // Simple Collision Detection
        // Player X is fixed at approx 50
        double playerX = 50.0;
        double playerSize = 50.0;
        
        // Rects for collision
        Rect playerRect = Rect.fromLTWH(playerX, playerY, playerSize - 10, playerSize - 10);
        // Ground is at Y = 0 (relative to ground line). We need to offset it.
        // Actually playerY is offset from ground. 
        Rect obsRect = Rect.fromLTWH(obs.x, 0, obs.size - 10, obs.size - 10);

        if (playerRect.overlaps(obsRect)) {
          gameOver();
        }
      }

      for (var r in toRemove) {
        obstacles.remove(r);
      }
    });
  }

  void jump() {
    if (!isPlaying || isJumping) return;
    setState(() {
      velocityY = jumpStrength;
      isJumping = true;
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
        content: Text('Distance: $score m', style: const TextStyle(color: Colors.white70, fontSize: 18)),
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
      int coinsEarned = (score / 100).floor(); // 1 coin per 100 meters
      if (coinsEarned > 0) {
        await http.post(
          Uri.parse('https://swapeatbackend.vercel.app/api/v1/games/score'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.userModel.uid}'},
          body: json.encode({'game_id': 'delivery_dash', 'score': coinsEarned}),
        ).timeout(const Duration(seconds: 15));
      }
    } catch (e) {
      print("Error submitting delivery score: \$e");
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
        title: const Text('Delivery Dash', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
        actions: [CoinsDisplay(uid: widget.userModel.uid)],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: jump,
        child: Stack(
          children: [
            // Background Elements (Sky)
            Positioned(
              top: 50, right: 100,
              child: const Text('☁️', style: TextStyle(fontSize: 40)),
            ),
            Positioned(
              top: 80, left: 50,
              child: const Text('☁️', style: TextStyle(fontSize: 30)),
            ),
            
            // Ground Line
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.3,
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: _neonCyan, width: 4)),
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            
            // Player
            if (isPlaying || isGameOver)
              Positioned(
                left: 50,
                bottom: MediaQuery.of(context).size.height * 0.3 - playerY,
                child: const Text('🛵', style: TextStyle(fontSize: 50)),
              ),
            
            // Obstacles
            ...obstacles.map((obs) => Positioned(
                  left: obs.x,
                  bottom: MediaQuery.of(context).size.height * 0.3,
                  child: Text(obs.emoji, style: TextStyle(fontSize: obs.size)),
                )),

            // HUD
            if (isPlaying || isGameOver)
              Positioned(
                top: 20,
                right: 20,
                child: Text('${score}m', style: TextStyle(color: _neonCyan, fontSize: 24, fontWeight: FontWeight.bold)),
              ),

            // Start Screen
            if (!isPlaying && !isGameOver)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Tap to jump!\nDeliver the food safely 🍔', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 18)),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _neonCyan,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: startGame,
                      child: const Text('START DASH', style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              )
          ],
        ),
      ),
    );
  }
}
