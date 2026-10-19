import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/game_reward_service.dart';
import 'coins_display.dart';

class DashVehicle {
  final String id;
  final String name;
  final String emoji;
  final String badge;
  final String perkDesc;
  final double speedMultiplier;
  final double jumpForce;
  final int maxJumps;
  final bool hasShield;
  final double coinMultiplier;
  final Color themeColor;

  const DashVehicle({
    required this.id,
    required this.name,
    required this.emoji,
    required this.badge,
    required this.perkDesc,
    this.speedMultiplier = 1.0,
    this.jumpForce = -17.0,
    this.maxJumps = 2,
    this.hasShield = false,
    this.coinMultiplier = 1.0,
    required this.themeColor,
  });
}

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

  static const List<DashVehicle> availableVehicles = [
    DashVehicle(
      id: 'scooter',
      name: 'Boda Scooter',
      emoji: '🛵',
      badge: 'Classic Agile',
      perkDesc: 'Balanced speed & snappy double jump.',
      speedMultiplier: 1.0,
      jumpForce: -17.0,
      maxJumps: 2,
      themeColor: Color(0xFF05D5AA),
    ),
    DashVehicle(
      id: 'sports_bike',
      name: 'Sports Motorbike',
      emoji: '🏍️',
      badge: 'Triple Jump',
      perkDesc: 'High-agility engine with 3x air jumps!',
      speedMultiplier: 1.05,
      jumpForce: -17.5,
      maxJumps: 3,
      themeColor: Colors.purpleAccent,
    ),
    DashVehicle(
      id: 'car',
      name: 'Express Sedan Car',
      emoji: '🚗',
      badge: '+20% Speed',
      perkDesc: 'Aerodynamic speedster covering road 20% faster.',
      speedMultiplier: 1.20,
      jumpForce: -17.0,
      maxJumps: 2,
      themeColor: Colors.redAccent,
    ),
    DashVehicle(
      id: 'van',
      name: 'Delivery Van',
      emoji: '🚐',
      badge: 'Coin Magnet',
      perkDesc: 'Wide cargo van with 1.5x coin magnet reach.',
      speedMultiplier: 0.98,
      jumpForce: -16.5,
      maxJumps: 2,
      coinMultiplier: 1.5,
      themeColor: Colors.amber,
    ),
    DashVehicle(
      id: 'bus',
      name: 'Campus Shuttle Bus',
      emoji: '🚌',
      badge: 'Double Coins',
      perkDesc: 'Campus Matatu shuttle! 2x double coin multiplier.',
      speedMultiplier: 0.95,
      jumpForce: -16.0,
      maxJumps: 2,
      coinMultiplier: 2.0,
      themeColor: Colors.lightGreenAccent,
    ),
    DashVehicle(
      id: 'lorry',
      name: 'Heavy Freight Lorry',
      emoji: '🚛',
      badge: 'Steel Shield',
      perkDesc: 'Armored titan! Absorbs 1 crash without dying.',
      speedMultiplier: 0.92,
      jumpForce: -15.8,
      maxJumps: 2,
      hasShield: true,
      themeColor: Colors.cyanAccent,
    ),
    DashVehicle(
      id: 'pickup',
      name: 'Rugged Pickup Truck',
      emoji: '🛻',
      badge: 'Mega Jump',
      perkDesc: 'All-terrain suspension with mega jump airtime.',
      speedMultiplier: 1.05,
      jumpForce: -18.5,
      maxJumps: 2,
      themeColor: Colors.deepOrangeAccent,
    ),
  ];

  DashVehicle _selectedVehicle = availableVehicles[0];

  bool _isPlaying = false;
  bool _isGameOver = false;
  int _distance = 0;
  int _coinsCollected = 0;
  int _totalScore = 0;

  Timer? _gameTimer;

  // Player physics
  double _playerY = 0.0; // 0 = ground, negative = up in air
  double _velocityY = 0.0;
  final double _gravity = 1.1;
  double _jumpForce = -17.0;
  int _maxJumps = 2;
  int _jumpsRemaining = 2;

  // Perks state
  bool _shieldActive = false;
  String? _shieldBreakNotice;
  Timer? _shieldNoticeTimer;

  double _gameSpeed = 6.0;
  double _roadOffset = 0.0;
  final List<RoadEntity> _entities = [];

  // Spacing & Spawning controls
  double _distanceSinceLastEntity = 0.0;
  double _nextEntityGap = 280.0;
  bool _lastWasObstacle = false;

  final List<String> _obstacleTypes = ['🚧', '🚘', '🐕', '📦', '🕳️', '⚠️'];
  final List<Map<String, dynamic>> _collectibleTypes = [
    {'icon': '🪙', 'points': 10},
    {'icon': '🍕', 'points': 25},
    {'icon': '🥤', 'points': 15},
    {'icon': '🍔', 'points': 30},
  ];

  @override
  void dispose() {
    _gameTimer?.cancel();
    _shieldNoticeTimer?.cancel();
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
      _shieldActive = _selectedVehicle.hasShield;
      _shieldBreakNotice = null;
      _jumpForce = _selectedVehicle.jumpForce;
      _maxJumps = _selectedVehicle.maxJumps;
      _jumpsRemaining = _selectedVehicle.maxJumps;
      _gameSpeed = 6.0 * _selectedVehicle.speedMultiplier;
      _distanceSinceLastEntity = 0.0;
      _nextEntityGap = 300.0;
      _lastWasObstacle = false;
      _entities.clear();
    });

    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      _updateGame();
    });
  }

  void _spawnRoadEntity() {
    final rand = Random();
    final screenWidth = MediaQuery.of(context).size.width;

    // If the last spawned item was an obstacle, strongly favor a collectible (75%)
    // so obstacles are never tightly clustered or impossible to jump
    final bool shouldSpawnCollectible = _lastWasObstacle ? (rand.nextDouble() < 0.75) : (rand.nextDouble() < 0.45);

    if (shouldSpawnCollectible) {
      _lastWasObstacle = false;
      final col = _collectibleTypes[rand.nextInt(_collectibleTypes.length)];
      _entities.add(RoadEntity(
        x: screenWidth + 20,
        icon: col['icon'],
        isCollectible: true,
        points: col['points'],
      ));
      // Moderate gap after a collectible
      _nextEntityGap = 260.0 + rand.nextDouble() * 100.0;
    } else {
      _lastWasObstacle = true;
      final icon = _obstacleTypes[rand.nextInt(_obstacleTypes.length)];
      _entities.add(RoadEntity(
        x: screenWidth + 20,
        icon: icon,
        isCollectible: false,
        points: 0,
        size: 44.0,
      ));
      // Large gap after an obstacle: Guaranteed 380px to 520px!
      // This ensures the player always has ample air-time to jump and land safely!
      _nextEntityGap = 380.0 + rand.nextDouble() * 140.0;
    }
  }

  void _updateGame() {
    if (!_isPlaying) return;

    setState(() {
      _distance += 1;
      _roadOffset = (_roadOffset + _gameSpeed) % 40;

      // Accelerate smoothly over distance
      if (_distance % 350 == 0 && _gameSpeed < 14.0) {
        _gameSpeed += 0.4;
      }

      // Physics
      _velocityY += _gravity;
      _playerY += _velocityY;

      if (_playerY >= 0) {
        _playerY = 0;
        _velocityY = 0;
        _jumpsRemaining = _maxJumps; // Reset jumps upon landing
      }

      // Spacing & Spawning check based on actual distance traveled
      _distanceSinceLastEntity += _gameSpeed;
      if (_distanceSinceLastEntity >= _nextEntityGap) {
        _spawnRoadEntity();
        _distanceSinceLastEntity = 0.0;
      }

      _totalScore = _distance + (_coinsCollected * 20);

      // Entities movement & collision
      final List<RoadEntity> toRemove = [];
      const double playerX = 60.0;
      const double playerHeight = 48.0;

      // Delivery Van has magnet pickup reach bonus
      final double reachBonus = _selectedVehicle.id == 'van' ? 32.0 : 0.0;

      final Rect playerRect = Rect.fromLTWH(
        playerX - reachBonus,
        _playerY,
        48.0 + (reachBonus * 2),
        playerHeight,
      );

      final Rect solidPlayerRect = Rect.fromLTWH(
        playerX + 4,
        _playerY + 4,
        38.0,
        playerHeight - 8,
      );

      for (var e in _entities) {
        e.x -= _gameSpeed;

        if (e.x < -60) {
          toRemove.add(e);
          continue;
        }

        // Entity Rect (on ground)
        final Rect entityRect = Rect.fromLTWH(e.x + 4, 0, e.size - 10, e.size - 6);

        // Check collectible reach (generous)
        if (e.isCollectible && playerRect.overlaps(entityRect)) {
          final int reward = ((e.points * _selectedVehicle.coinMultiplier)).round();
          _coinsCollected += (reward ~/ 10).clamp(1, 10);
          _totalScore += reward;
          HapticFeedback.lightImpact();
          toRemove.add(e);
        } else if (!e.isCollectible && solidPlayerRect.overlaps(entityRect)) {
          // Collision with obstacle!
          if (_shieldActive) {
            // Freight Lorry Steel Shield absorbs collision!
            _shieldActive = false;
            toRemove.add(e);
            HapticFeedback.heavyImpact();
            _shieldBreakNotice = '🛡️ STEEL SHIELD ABSORBED CRASH!';
            _shieldNoticeTimer?.cancel();
            _shieldNoticeTimer = Timer(const Duration(seconds: 2), () {
              if (mounted) setState(() => _shieldBreakNotice = null);
            });
          } else {
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
        title: Text('Delivery Dash (${_selectedVehicle.name})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
            // Cyber City Skyline & Background
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
              child: ClipRect(
                child: Container(
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.cyanAccent.withValues(alpha: 0.04)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: OverflowBox(
                    maxWidth: double.infinity,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        (size.width / 45).ceil() + 2,
                        (i) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Icon(Icons.apartment, size: 36 + (i % 3) * 12, color: Colors.white10),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Ground / Campus Asphalt Road
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: groundHeight,
              child: ClipRect(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF151922),
                    border: Border(
                      top: BorderSide(color: _selectedVehicle.themeColor, width: 3),
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Moving Road Dashes
                      Positioned(
                        top: 40,
                        left: -_roadOffset,
                        child: OverflowBox(
                          maxWidth: double.infinity,
                          alignment: Alignment.topLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              (size.width / 40).ceil() + 4,
                              (i) => Container(
                                margin: const EdgeInsets.only(right: 20),
                                width: 25,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
                                  color: Colors.amber.withValues(alpha: 0.8),
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

            // Player Vehicle (Points FORWARD/Right using flipX)
            Positioned(
              left: 60,
              bottom: groundHeight - 10 - _playerY,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..rotateZ((_velocityY * 0.012).clamp(-0.25, 0.25)),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Steel Shield Aura (for Freight Lorry)
                    if (_shieldActive)
                      Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.cyanAccent, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.cyanAccent.withValues(alpha: 0.4),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),

                    // Fire Boost at REAR (positioned left because car is moving right)
                    if (_playerY < 0)
                      Positioned(
                        bottom: 6,
                        left: -18,
                        child: Icon(Icons.local_fire_department, color: _neonPink, size: 28),
                      ),

                    // Vehicle emoji flipped horizontally so front points RIGHT (forward direction of travel!)
                    Transform.flip(
                      flipX: true,
                      child: Text(
                        _selectedVehicle.emoji,
                        style: const TextStyle(fontSize: 54),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Shield Break Notice Banner
            if (_shieldBreakNotice != null)
              Positioned(
                top: 80,
                left: 20,
                right: 20,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.cyanAccent, width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.cyanAccent.withValues(alpha: 0.3), blurRadius: 12),
                      ],
                    ),
                    child: Text(
                      _shieldBreakNotice!,
                      style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ),

            // HUD
            if (_isPlaying)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Distance & Vehicle Info
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131A2A).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _selectedVehicle.themeColor.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Text(_selectedVehicle.emoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 6),
                          Text('${_distance}m', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),

                    // Shield status indicator if vehicle has shield perk
                    if (_selectedVehicle.hasShield)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _shieldActive ? Colors.cyanAccent.withValues(alpha: 0.18) : Colors.redAccent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _shieldActive ? Colors.cyanAccent : Colors.redAccent),
                        ),
                        child: Row(
                          children: [
                            Icon(_shieldActive ? Icons.shield : Icons.shield_outlined, size: 14, color: _shieldActive ? Colors.cyanAccent : Colors.redAccent),
                            const SizedBox(width: 4),
                            Text(
                              _shieldActive ? 'SHIELD 1x' : 'BROKEN',
                              style: TextStyle(
                                color: _shieldActive ? Colors.cyanAccent : Colors.redAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Coins
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131A2A).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
                          const SizedBox(width: 6),
                          Text('$_coinsCollected', style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Start Screen Overlay with Vehicle Chooser
            if (!_isPlaying && !_isGameOver)
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131A2A),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _selectedVehicle.themeColor.withValues(alpha: 0.4), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: _selectedVehicle.themeColor.withValues(alpha: 0.15), blurRadius: 24),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Transform.flip(
                              flipX: true,
                              child: Text(_selectedVehicle.emoji, style: const TextStyle(fontSize: 28)),
                            ),
                            const SizedBox(width: 8),
                            const Text('DELIVERY DASH', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tap screen to JUMP! Double tap for AIR JUMPS!\nCollect foods & coins • Dodge oncoming traffic',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 18),

                        // Vehicle Selector Header
                        Row(
                          children: [
                            const Icon(Icons.directions_car_filled, color: Colors.amber, size: 16),
                            const SizedBox(width: 6),
                            const Text(
                              'CHOOSE YOUR RIDE:',
                              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
                            ),
                            const Spacer(),
                            Text(
                              _selectedVehicle.name,
                              style: TextStyle(color: _selectedVehicle.themeColor, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Vehicle Carousel
                        SizedBox(
                          height: 120,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: availableVehicles.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final v = availableVehicles[index];
                              final isSelected = v.id == _selectedVehicle.id;

                              return InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedVehicle = v);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: 110,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? v.themeColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected ? v.themeColor : Colors.white12,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Transform.flip(
                                        flipX: true,
                                        child: Text(v.emoji, style: const TextStyle(fontSize: 32)),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        v.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.white70,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: v.themeColor.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          v.badge,
                                          style: TextStyle(color: v.themeColor, fontSize: 8.5, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 12),
                        // Selected vehicle perk summary
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedVehicle.themeColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _selectedVehicle.themeColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.bolt, color: _selectedVehicle.themeColor, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedVehicle.perkDesc,
                                  style: TextStyle(color: _selectedVehicle.themeColor, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedVehicle.themeColor,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            elevation: 0,
                          ),
                          onPressed: _startGame,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Transform.flip(
                                flipX: true,
                                child: Text(_selectedVehicle.emoji, style: const TextStyle(fontSize: 20)),
                              ),
                              const SizedBox(width: 8),
                              const Text('START DASHING', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
