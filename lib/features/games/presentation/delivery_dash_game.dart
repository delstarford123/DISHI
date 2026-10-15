import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/game_reward_service.dart';
import 'coins_display.dart';

class RoadEntity {
  double x;
  final String icon;
  final bool isCollectible;
  final int points;
  final double size;

  RoadEntity({
    required this.x,
    required this.icon,
    required this.isCollectible,
    required this.points,
    this.size = 42.0,
  });
}

class DeliveryDashGame extends StatefulWidget {
  final UserModel userModel;

  const DeliveryDashGame({super.key, required this.userModel});

  @override
  State<DeliveryDashGame> createState() => _DeliveryDashGameState();
}

class _DeliveryDashGameState extends State<DeliveryDashGame> {
  final Color _bgColor = const Color(0xFF0C101B);
  final Color _neonCyan = const Color(0xFF05D5AA);
  final Color _neonPink = const Color(0xFFF92B60);

  bool _isPlaying = false;
  bool _isGameOver = false;
  int _distance = 0;
  int _coinsCollected = 0;
  int _totalScore = 0;

  Timer? _gameTimer;
  Timer? _spawnTimer;

  // Player physics
  double _playerY = 0.0; // 0 = ground, negative = up in air
  double _velocityY = 0.0;
  final double _gravity = 1.1;
  final double _jumpForce = -17.0;
  int _jumpsRemaining = 2; // Double jump enabled!

  double _gameSpeed = 6.0;
  double _roadOffset = 0.0;
  final List<RoadEntity> _entities = [];

  final List<String> _obstacleTypes = ['🚧', '🚗', '🐕', '📦', '🕳️'];
  final List<Map<String, dynamic>> _collectibleTypes = [
    {'icon': '🪙', 'points': 10},
    {'icon': '🍕', 'points': 25},
    {'icon': '🥤', 'points': 15},
  ];

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
      _distance = 0;
      _coinsCollected = 0;
      _totalScore = 0;
      _playerY = 0.0;
      _velocityY = 0.0;
      _jumpsRemaining = 2;
      _gameSpeed = 6.0;
      _entities.clear();
    });

    _gameTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      _updateGame();
    });

    _spawnTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      if (_isPlaying) _spawnRoadEntity();
    });
  }

  void _spawnRoadEntity() {
    final rand = Random();
    final screenWidth = MediaQuery.of(context).size.width;

    // 40% chance collectible, 60% obstacle
    final isCollectible = rand.nextDouble() < 0.45;

    if (isCollectible) {
      final col = _collectibleTypes[rand.nextInt(_collectibleTypes.length)];
      _entities.add(RoadEntity(
        x: screenWidth,
        icon: col['icon'],
        isCollectible: true,
        points: col['points'],
      ));
    } else {
      final icon = _obstacleTypes[rand.nextInt(_obstacleTypes.length)];
      _entities.add(RoadEntity(
        x: screenWidth,
        icon: icon,
        isCollectible: false,
        points: 0,
      ));
    }
  }

  void _updateGame() {
    if (!_isPlaying) return;

    setState(() {
      _distance += 1;
      _roadOffset = (_roadOffset + _gameSpeed) % 40;

      // Accelerate slightly over time
      if (_distance % 300 == 0 && _gameSpeed < 14.0) {
        _gameSpeed += 0.5;
      }

      // Physics
      _velocityY += _gravity;
      _playerY += _velocityY;

      if (_playerY >= 0) {
        _playerY = 0;
        _velocityY = 0;
        _jumpsRemaining = 2; // Reset double jump
      }

      _totalScore = _distance + (_coinsCollected * 20);

      // Entities movement & collision
      final List<RoadEntity> toRemove = [];
      const double playerX = 60.0;
      const double playerHeight = 50.0;

      // Player bounding rect
      final Rect playerRect = Rect.fromLTWH(
        playerX,
        _playerY,
        45,
        playerHeight,
      );

      for (var e in _entities) {
        e.x -= _gameSpeed;

        if (e.x < -60) {
          toRemove.add(e);
          continue;
        }

        // Entity Rect (on ground)
        final Rect entityRect = Rect.fromLTWH(e.x, 0, e.size - 8, e.size);

        if (playerRect.overlaps(entityRect)) {
          if (e.isCollectible) {
            // Collect food / coin
            _coinsCollected++;
            HapticFeedback.lightImpact();
            toRemove.add(e);
          } else {
            // Collision with obstacle
            HapticFeedback.heavyImpact();
            _triggerGameOver();
            return;
          }
        }
      }

      for (var r in toRemove) {
        _entities.remove(r);
      }
    });
  }

  void _jump() {
    if (!_isPlaying || _jumpsRemaining <= 0) return;

    setState(() {
      _velocityY = _jumpForce;
      _jumpsRemaining--;
    });
    HapticFeedback.mediumImpact();
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
      gameId: 'delivery_dash',
      score: _totalScore,
    );

    if (!mounted) return;

    GameRewardService.showArcadeGameOverDialog(
      context: context,
      userModel: widget.userModel,
      gameTitle: 'DELIVERY DASH',
      score: _totalScore,
      scoreLabel: 'TOTAL DISTANCE + COINS',
      coinsEarned: res.coinsEarned,
      onPlayAgain: _startGame,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double groundHeight = size.height * 0.35;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Delivery Dash', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [CoinsDisplay(uid: widget.userModel.uid)],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _isPlaying ? _jump : null,
        child: Stack(
          children: [
            // Cyber City Skyline & Starfield
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF080D1A), Color(0xFF131A2A), Color(0xFF0C101B)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // Distant Campus Rooftops silhouette
            Positioned(
              left: 0,
              right: 0,
              bottom: groundHeight,
              child: Container(
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.cyanAccent.withOpacity(0.04)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(8, (i) => Icon(Icons.apartment, size: 40 + (i % 3) * 15, color: Colors.white10)),
                ),
              ),
            ),

            // Ground / Campus Asphalt Road
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: groundHeight,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF151922),
                  border: Border(
                    top: BorderSide(color: Color(0xFF05D5AA), width: 3),
                  ),
                ),
                child: Stack(
                  children: [
                    // Moving Road Dashes
                    Positioned(
                      top: 40,
                      left: -_roadOffset,
                      right: 0,
                      child: Row(
                        children: List.generate(
                          (size.width / 40).ceil() + 2,
                          (i) => Container(
                            margin: const EdgeInsets.only(right: 20),
                            width: 25,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Road Entities (Obstacles and Collectibles)
            ..._entities.map((e) {
              return Positioned(
                left: e.x,
                bottom: groundHeight - 10,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      e.icon,
                      style: TextStyle(
                        fontSize: e.size,
                        shadows: e.isCollectible
                            ? [
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.8),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                )
                              ]
                            : null,
                      ),
                    ),
                  ],
                ),
              );
            }),

            // Player Rider on Scooter
            Positioned(
              left: 60,
              bottom: groundHeight - 10 - _playerY,
              child: Transform.rotate(
                angle: _playerY < 0 ? -0.15 : 0.0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Scooter icon
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_playerY < 0)
                          // Boost flame
                          Positioned(
                            bottom: 2,
                            left: -12,
                            child: Icon(Icons.local_fire_department, color: _neonPink, size: 24),
                          ),
                        const Text('🛵', style: TextStyle(fontSize: 52)),
                      ],
                    ),
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
                        color: const Color(0xFF131A2A).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _neonCyan.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.speed, color: Colors.cyanAccent, size: 20),
                          const SizedBox(width: 6),
                          Text('${_distance}m', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131A2A).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                          const SizedBox(width: 6),
                          Text('$_coinsCollected', style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
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
                      const Text('🛵 DELIVERY DASH 📦', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 14),
                      const Text(
                        'Tap the screen to JUMP!\nDouble tap for DOUBLE JUMP!\n\nCollect pizza & coins 🪙 for extra rewards!\nDodge potholes, cars & street obstacles 🚧!',
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
                        child: const Text('START DASHING', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
