import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/game_reward_service.dart';
import 'coins_display.dart';

class FallingSnack {
  double x;
  double y;
  final String icon;
  final bool isHazard;
  final bool isGolden;
  final int points;
  final double speed;

  FallingSnack({
    required this.x,
    required this.y,
    required this.icon,
    required this.isHazard,
    required this.isGolden,
    required this.points,
    required this.speed,
  });
}

class SwapEatDropGame extends StatefulWidget {
  final UserModel userModel;

  const SwapEatDropGame({super.key, required this.userModel});

  @override
  State<SwapEatDropGame> createState() => _SwapEatDropGameState();
}

class _SwapEatDropGameState extends State<SwapEatDropGame> {
  final Color _bgColor = const Color(0xFF0C101B);
  final Color _neonCyan = const Color(0xFF05D5AA);
  final Color _neonPink = const Color(0xFFF92B60);

  double _basketX = 0.5; // 0.0 to 1.0 (screen width ratio)
  final List<FallingSnack> _snacks = [];

  bool _isPlaying = false;
  bool _isGameOver = false;
  int _score = 0;
  int _lives = 4;
  int _streak = 0;

  Timer? _gameTimer;
  Timer? _spawnTimer;

  final List<Map<String, dynamic>> _goodSnacks = [
    {'icon': '🍔', 'points': 15},
    {'icon': '🍕', 'points': 20},
    {'icon': '🍟', 'points': 10},
    {'icon': '🌮', 'points': 25},
    {'icon': '🥤', 'points': 10},
    {'icon': '🥑', 'points': 20},
  ];

  final List<String> _hazardItems = ['💣', '🐛', '🕳️'];

  @override
  void dispose() {
    _gameTimer?.cancel();
    _spawnTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _isGameOver = false;
      _score = 0;
      _lives = 4;
      _streak = 0;
      _basketX = 0.5;
      _snacks.clear();
    });

    _gameTimer = Timer.periodic(const Duration(milliseconds: 25), (timer) {
      _updateGame();
    });

    _spawnTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (_isPlaying) _spawnSnack();
    });
  }

  void _spawnSnack() {
    final rand = Random();
    final isHazard = rand.nextDouble() < 0.22; // 22% hazard
    final isGolden = !isHazard && rand.nextDouble() < 0.15; // 15% golden snack

    String icon = '🍔';
    int points = 15;

    if (isHazard) {
      icon = _hazardItems[rand.nextInt(_hazardItems.length)];
      points = 0;
    } else if (isGolden) {
      icon = '👑';
      points = 50;
    } else {
      final s = _goodSnacks[rand.nextInt(_goodSnacks.length)];
      icon = s['icon'];
      points = s['points'];
    }

    final double speed = rand.nextDouble() * 0.006 + 0.012 + (_score * 0.00002);

    setState(() {
      _snacks.add(FallingSnack(
        x: rand.nextDouble() * 0.8 + 0.1,
        y: -0.08,
        icon: icon,
        isHazard: isHazard,
        isGolden: isGolden,
        points: points,
        speed: speed,
      ));
    });
  }

  void _updateGame() {
    if (!_isPlaying) return;

    setState(() {
      final List<FallingSnack> toRemove = [];

      for (var s in _snacks) {
        s.y += s.speed;

        // Catch check at bottom (y between 0.82 and 0.90)
        if (s.y >= 0.82 && s.y <= 0.90) {
          if ((s.x - _basketX).abs() < 0.14) {
            // Caught in basket!
            if (s.isHazard) {
              _lives--;
              _streak = 0;
              HapticFeedback.heavyImpact();
              if (_lives <= 0) {
                _triggerGameOver();
                return;
              }
            } else {
              _streak++;
              int bonus = _streak >= 5 ? 2 : 1;
              _score += s.points * bonus;
              HapticFeedback.lightImpact();
            }
            toRemove.add(s);
            continue;
          }
        }

        // Drop below screen
        if (s.y > 1.05) {
          if (!s.isHazard) {
            _streak = 0; // Missed good food breaks streak
          }
          toRemove.add(s);
        }
      }

      for (var r in toRemove) {
        _snacks.remove(r);
      }
    });
  }

  Future<void> _triggerGameOver() async {
    _gameTimer?.cancel();
    _spawnTimer?.cancel();

    setState(() {
      _isPlaying = false;
      _isGameOver = true;
    });

    final res = await GameRewardService.submitScore(
      uid: widget.userModel.uid,
      gameId: 'swapeat_drop',
      score: _score,
    );

    if (!mounted) return;

    GameRewardService.showArcadeGameOverDialog(
      context: context,
      userModel: widget.userModel,
      gameTitle: 'DISHI DROP',
      score: _score,
      coinsEarned: res.coinsEarned,
      onPlayAgain: _startGame,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('DISHI Drop', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [CoinsDisplay(uid: widget.userModel.uid)],
      ),
      body: GestureDetector(
        onHorizontalDragUpdate: (details) {
          if (!_isPlaying) return;
          setState(() {
            _basketX = (details.localPosition.dx / size.width).clamp(0.1, 0.9);
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // Ambient neon cafeteria backdrop
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF091322), Color(0xFF131A2A), Color(0xFF0C101B)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // Falling Snacks
            ..._snacks.map((s) {
              return Positioned(
                left: s.x * size.width - 24,
                top: s.y * size.height,
                child: Container(
                  decoration: s.isGolden
                      ? BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.amber.withOpacity(0.8), blurRadius: 18, spreadRadius: 4),
                          ],
                        )
                      : null,
                  child: Text(s.icon, style: const TextStyle(fontSize: 44)),
                ),
              );
            }),

            // Player Catch Basket
            Positioned(
              left: _basketX * size.width - 55,
              top: size.height * 0.82,
              child: Container(
                width: 110,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_neonCyan, const Color(0xFF028A6E)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: _neonCyan.withOpacity(0.4), blurRadius: 18, spreadRadius: 2),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_basket, color: Colors.black, size: 28),
                    SizedBox(width: 6),
                    Text('CATCH', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13)),
                  ],
                ),
              ),
            ),

            // HUD
            if (_isPlaying)
              Positioned(
                top: 16,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131A2A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _neonCyan.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 6),
                          Text('$_score', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          if (_streak >= 5) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: _neonPink, borderRadius: BorderRadius.circular(8)),
                              child: const Text('2X 🔥', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Row(
                      children: List.generate(4, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Icon(
                            Icons.favorite,
                            color: index < _lives ? _neonPink : Colors.white24,
                            size: 26,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),

            // Start Screen Overlay
            if (!_isPlaying && !_isGameOver)
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131A2A),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _neonCyan.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(color: _neonCyan.withOpacity(0.15), blurRadius: 24),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🧺 DISHI DROP 🍔', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 14),
                      const Text(
                        'Drag the basket left and right to catch delicious snacks!\n\nCatch 5 in a row for 2X COMBO! 🔥\nGolden crowns 👑 yield 50 points!\nWatch out for bombs 💣 & bugs 🐛!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _neonCyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        onPressed: _startGame,
                        child: const Text('START CATCHING', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
