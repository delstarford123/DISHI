import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/game_reward_service.dart';
import 'coins_display.dart';

class FlyingObject {
  double x;
  double y;
  double vx;
  double vy;
  final bool isBomb;
  final bool isGolden;
  final String icon;
  final Color splashColor;
  bool isSliced = false;
  double splitOffset = 0.0;
  double rotation = 0.0;
  double rotationSpeed = 0.0;

  FlyingObject({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.isBomb,
    required this.isGolden,
    required this.icon,
    required this.splashColor,
    required this.rotationSpeed,
  });
}

class JuiceParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double opacity;

  JuiceParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    this.opacity = 1.0,
  });
}

class FloatingText {
  final String text;
  final double x;
  double y;
  final Color color;
  double opacity;

  FloatingText({
    required this.text,
    required this.x,
    required this.y,
    required this.color,
    this.opacity = 1.0,
  });
}

class BiteNinjaGame extends StatefulWidget {
  final UserModel userModel;

  const BiteNinjaGame({super.key, required this.userModel});

  @override
  State<BiteNinjaGame> createState() => _BiteNinjaGameState();
}

class _BiteNinjaGameState extends State<BiteNinjaGame> with SingleTickerProviderStateMixin {
  final List<FlyingObject> _objects = [];
  final List<JuiceParticle> _particles = [];
  final List<FloatingText> _floatingTexts = [];
  final List<Offset> _slicePath = [];

  bool _isPlaying = false;
  bool _isGameOver = false;
  int _score = 0;
  int _lives = 5;
  int _currentSwipeSlices = 0;
  Timer? _gameTimer;
  Timer? _spawnTimer;

  final Color _bgColor = const Color(0xFF0C101B);
  final Color _neonCyan = const Color(0xFF05D5AA);
  final Color _neonPink = const Color(0xFFF92B60);

  final List<Map<String, dynamic>> _foodTypes = [
    {'icon': '🍉', 'color': Colors.redAccent, 'points': 15},
    {'icon': '🍕', 'color': Colors.orangeAccent, 'points': 20},
    {'icon': '🍔', 'color': Colors.amber, 'points': 25},
    {'icon': '🍎', 'color': Colors.red, 'points': 15},
    {'icon': '🍍', 'color': Colors.yellow, 'points': 20},
    {'icon': '🥑', 'color': Colors.greenAccent, 'points': 20},
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
      _score = 0;
      _lives = 5;
      _objects.clear();
      _particles.clear();
      _floatingTexts.clear();
      _slicePath.clear();
      _currentSwipeSlices = 0;
    });

    _gameTimer = Timer.periodic(const Duration(milliseconds: 25), (timer) {
      _updateGame();
    });

    _spawnTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (_isPlaying) _spawnWave();
    });
  }

  void _spawnWave() {
    final rand = Random();
    int count = rand.nextInt(3) + 1; // 1 to 3 items

    for (int i = 0; i < count; i++) {
      final isBomb = rand.nextDouble() > 0.82; // ~18% chance for bomb
      final isGolden = !isBomb && rand.nextDouble() > 0.88; // rare golden item

      final foodData = _foodTypes[rand.nextInt(_foodTypes.length)];
      final String icon = isBomb ? '💣' : (isGolden ? '👑' : foodData['icon']);
      final Color color = isBomb
          ? Colors.redAccent
          : (isGolden ? Colors.amber : foodData['color']);

      final double startX = rand.nextDouble() * 0.7 + 0.15;
      final double startY = 1.1;

      // Arc towards center
      final double vx = (0.5 - startX) * (rand.nextDouble() * 0.04 + 0.02);
      final double vy = -(rand.nextDouble() * 0.025 + 0.038);

      _objects.add(FlyingObject(
        x: startX,
        y: startY,
        vx: vx,
        vy: vy,
        isBomb: isBomb,
        isGolden: isGolden,
        icon: icon,
        splashColor: color,
        rotationSpeed: (rand.nextDouble() - 0.5) * 0.15,
      ));
    }
  }

  void _updateGame() {
    if (!_isPlaying) return;

    setState(() {
      final List<FlyingObject> toRemove = [];

      // Update objects
      for (var obj in _objects) {
        if (obj.isSliced) {
          obj.splitOffset += 0.02;
          obj.y += 0.015;
          obj.rotation += obj.rotationSpeed * 1.5;
          if (obj.y > 1.2) {
            toRemove.add(obj);
          }
          continue;
        }

        // Gravity
        obj.vy += 0.0013;
        obj.x += obj.vx;
        obj.y += obj.vy;
        obj.rotation += obj.rotationSpeed;

        // Check if item dropped off screen
        if (obj.y > 1.2) {
          if (!obj.isBomb && !obj.isSliced) {
            _lives--;
            HapticFeedback.mediumImpact();
            if (_lives <= 0) {
              _triggerGameOver();
              return;
            }
          }
          toRemove.add(obj);
        }
      }

      for (var r in toRemove) {
        _objects.remove(r);
      }

      // Update juice particles
      for (int i = _particles.length - 1; i >= 0; i--) {
        final p = _particles[i];
        p.x += p.vx;
        p.y += p.vy;
        p.vy += 0.0015; // gravity on juice
        p.opacity -= 0.03;
        if (p.opacity <= 0 || p.y > 1.2) {
          _particles.removeAt(i);
        }
      }

      // Update floating texts
      for (int i = _floatingTexts.length - 1; i >= 0; i--) {
        final ft = _floatingTexts[i];
        ft.y -= 0.004;
        ft.opacity -= 0.03;
        if (ft.opacity <= 0) {
          _floatingTexts.removeAt(i);
        }
      }

      // Fade swipe trail
      if (_slicePath.isNotEmpty) {
        _slicePath.removeAt(0);
      }
    });
  }

  void _onPanStart(DragStartDetails details) {
    _currentSwipeSlices = 0;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isPlaying) return;

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final size = box.size;
    final pos = details.localPosition;
    final nx = pos.dx / size.width;
    final ny = pos.dy / size.height;

    setState(() {
      _slicePath.add(pos);
      if (_slicePath.length > 12) _slicePath.removeAt(0);

      // Check collision
      for (var obj in _objects) {
        if (obj.isSliced) continue;

        final dx = obj.x - nx;
        final dy = obj.y - ny;
        if (dx * dx + dy * dy < 0.007) {
          // Object hit!
          obj.isSliced = true;

          if (obj.isBomb) {
            HapticFeedback.heavyImpact();
            _createExplosion(obj.x, obj.y);
            _triggerGameOver();
            return;
          }

          _currentSwipeSlices++;
          HapticFeedback.lightImpact();

          // Points
          int basePoints = obj.isGolden ? 50 : 20;
          int awarded = basePoints;

          if (_currentSwipeSlices >= 3) {
            awarded *= 3;
            _addFloatingText('COMBO x3! 🔥', obj.x, obj.y, Colors.amber);
            HapticFeedback.heavyImpact();
          } else if (_currentSwipeSlices == 2) {
            awarded *= 2;
            _addFloatingText('COMBO x2! ✨', obj.x, obj.y, _neonCyan);
            HapticFeedback.mediumImpact();
          } else {
            _addFloatingText('+$awarded', obj.x, obj.y, obj.splashColor);
          }

          _score += awarded;
          _spawnJuiceSplatter(obj.x, obj.y, obj.splashColor);
        }
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _currentSwipeSlices = 0;
  }

  void _spawnJuiceSplatter(double x, double y, Color color) {
    final rand = Random();
    for (int i = 0; i < 16; i++) {
      final angle = rand.nextDouble() * 2 * pi;
      final speed = rand.nextDouble() * 0.02 + 0.005;
      _particles.add(JuiceParticle(
        x: x,
        y: y,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        size: rand.nextDouble() * 6 + 4,
        color: color,
      ));
    }
  }

  void _createExplosion(double x, double y) {
    final rand = Random();
    for (int i = 0; i < 30; i++) {
      final angle = rand.nextDouble() * 2 * pi;
      final speed = rand.nextDouble() * 0.03 + 0.01;
      _particles.add(JuiceParticle(
        x: x,
        y: y,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        size: rand.nextDouble() * 8 + 6,
        color: i % 2 == 0 ? Colors.redAccent : Colors.orangeAccent,
      ));
    }
  }

  void _addFloatingText(String text, double x, double y, Color color) {
    _floatingTexts.add(FloatingText(
      text: text,
      x: x,
      y: y,
      color: color,
    ));
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
      gameId: 'bite_ninja',
      score: _score,
    );

    if (!mounted) return;

    GameRewardService.showArcadeGameOverDialog(
      context: context,
      userModel: widget.userModel,
      gameTitle: 'BITE NINJA',
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
        title: const Text('Bite Ninja', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [CoinsDisplay(uid: widget.userModel.uid)],
      ),
      body: Stack(
        children: [
          // Background Dojo ambiance
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    const Color(0xFF131A2A),
                    _bgColor,
                  ],
                ),
              ),
            ),
          ),

          // Interactive Slicing Surface
          GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: CustomPaint(
              size: Size.infinite,
              painter: _NinjaCanvasPainter(
                slicePath: _slicePath,
                particles: _particles,
                bladeColor: _neonCyan,
              ),
              child: Container(color: Colors.transparent),
            ),
          ),

          // Flying Food Objects & Split Halves
          ..._objects.map((obj) {
            final double screenX = obj.x * size.width;
            final double screenY = obj.y * size.height;

            if (obj.isSliced) {
              return Positioned(
                left: screenX - 35,
                top: screenY - 35,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Left half sliding left
                    Transform.translate(
                      offset: Offset(-obj.splitOffset * size.width, 0),
                      child: Transform.rotate(
                        angle: -obj.rotation,
                        child: ClipRect(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            widthFactor: 0.5,
                            child: Text(obj.icon, style: const TextStyle(fontSize: 48)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Right half sliding right
                    Transform.translate(
                      offset: Offset(obj.splitOffset * size.width, 0),
                      child: Transform.rotate(
                        angle: obj.rotation,
                        child: ClipRect(
                          child: Align(
                            alignment: Alignment.centerRight,
                            widthFactor: 0.5,
                            child: Text(obj.icon, style: const TextStyle(fontSize: 48)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Positioned(
              left: screenX - 25,
              top: screenY - 25,
              child: Transform.rotate(
                angle: obj.rotation,
                child: Text(obj.icon, style: const TextStyle(fontSize: 50)),
              ),
            );
          }),

          // Floating Text (Combos and Scores)
          ..._floatingTexts.map((ft) {
            return Positioned(
              left: ft.x * size.width - 40,
              top: ft.y * size.height - 20,
              child: Opacity(
                opacity: ft.opacity.clamp(0.0, 1.0),
                child: Text(
                  ft.text,
                  style: TextStyle(
                    color: ft.color,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(color: ft.color.withOpacity(0.8), blurRadius: 16),
                    ],
                  ),
                ),
              ),
            );
          }),

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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131A2A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _neonCyan.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bolt, color: Colors.amber, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          '$_score',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: List.generate(5, (index) {
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
                    const Text('⚔️ BITE NINJA 🍉', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    const Text(
                      'Swipe your finger across flying snacks to slice them!\n\nSlice 2 or more at once for MEGA COMBOS! 🔥\nAvoid the ticking bombs 💣!',
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
                        elevation: 8,
                      ),
                      onPressed: _startGame,
                      child: const Text('START SLICING', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NinjaCanvasPainter extends CustomPainter {
  final List<Offset> slicePath;
  final List<JuiceParticle> particles;
  final Color bladeColor;

  _NinjaCanvasPainter({
    required this.slicePath,
    required this.particles,
    required this.bladeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Juice Particles
    for (var p in particles) {
      final paint = Paint()
        ..color = p.color.withOpacity(p.opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(p.x * size.width, p.y * size.height), p.size, paint);
    }

    // 2. Draw Slicing Blade Trail
    if (slicePath.length > 1) {
      final glowPaint = Paint()
        ..color = bladeColor.withOpacity(0.3)
        ..strokeWidth = 14.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final corePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(slicePath.first.dx, slicePath.first.dy);
      for (int i = 1; i < slicePath.length; i++) {
        path.lineTo(slicePath[i].dx, slicePath[i].dy);
      }

      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NinjaCanvasPainter oldDelegate) => true;
}
