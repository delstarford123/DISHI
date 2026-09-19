import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/models/user_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BiteNinjaGame extends StatefulWidget {
  final UserModel userModel;

  const BiteNinjaGame({super.key, required this.userModel});

  @override
  State<BiteNinjaGame> createState() => _BiteNinjaGameState();
}

class FlyingObject {
  double x;
  double y;
  double vx;
  double vy;
  final bool isBomb;
  final String emoji;
  bool isSliced = false;

  FlyingObject({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.isBomb,
    required this.emoji,
  });
}

class _BiteNinjaGameState extends State<BiteNinjaGame> {
  List<FlyingObject> objects = [];
  List<Offset> slicePath = [];
  
  bool isPlaying = false;
  bool isGameOver = false;
  int score = 0;
  int lives = 7;
  Timer? gameTimer;
  Timer? spawnTimer;

  final Color _bgColor = const Color(0xFF0C101B);
  final Color _neonCyan = const Color(0xFF05D5AA);
  final Color _neonPink = const Color(0xFFF92B60);

  final List<String> foods = ['🍎', '🍉', '🍕', '🍔', '🥑', '🌮'];
  final List<String> bombs = ['💣'];

  void startGame() {
    setState(() {
      isPlaying = true;
      isGameOver = false;
      score = 0;
      lives = 7;
      objects.clear();
      slicePath.clear();
    });

    gameTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      updateGame();
    });

    spawnTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      if (isPlaying) spawnObject();
    });
  }

  void spawnObject() {
    final rand = Random();
    int count = rand.nextInt(3) + 1; // spawn 1 to 3 objects at a time
    
    setState(() {
      for (int i = 0; i < count; i++) {
        final isBomb = rand.nextDouble() > 0.85; // 15% chance for bomb
        final list = isBomb ? bombs : foods;
        final emoji = list[rand.nextInt(list.length)];
        
        // Start near bottom
        double startX = rand.nextDouble() * 0.8 + 0.1;
        double startY = 1.1;
        
        // Velocity (vx towards center, vy upwards)
        double vx = (0.5 - startX) * (rand.nextDouble() * 0.05 + 0.02);
        double vy = -(rand.nextDouble() * 0.03 + 0.035); // Initial upward velocity
        
        objects.add(FlyingObject(
          x: startX,
          y: startY,
          vx: vx,
          vy: vy,
          isBomb: isBomb,
          emoji: emoji,
        ));
      }
    });
  }

  void updateGame() {
    if (!isPlaying) return;

    setState(() {
      List<FlyingObject> toRemove = [];
      for (var obj in objects) {
        // Gravity
        obj.vy += 0.0015; 
        
        obj.x += obj.vx;
        obj.y += obj.vy;

        // Check if fell off screen
        if (obj.y > 1.2) {
          if (!obj.isBomb && !obj.isSliced) {
            lives -= 1;
            if (lives <= 0) {
              gameOver();
            }
          }
          toRemove.add(obj);
        }
      }

      for (var r in toRemove) {
        objects.remove(r);
      }
      
      // Fade slice path
      if (slicePath.isNotEmpty) {
        if (slicePath.length > 10) {
          slicePath.removeAt(0);
        } else {
          // Slowly decay if user stops dragging
          slicePath.removeAt(0);
        }
      }
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!isPlaying) return;
    
    final RenderBox box = context.findRenderObject() as RenderBox;
    final size = box.size;
    final pos = details.localPosition;
    
    // Normalized position
    final nx = pos.dx / size.width;
    final ny = pos.dy / size.height;
    
    setState(() {
      slicePath.add(pos);
      
      // Check collision with objects
      for (var obj in objects) {
        if (obj.isSliced) continue;
        
        // Simple distance check (radius ~ 0.08)
        final dx = obj.x - nx;
        final dy = obj.y - ny;
        if (dx * dx + dy * dy < 0.01) {
          obj.isSliced = true;
          if (obj.isBomb) {
            gameOver();
          } else {
            score += 15;
          }
        }
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      slicePath.clear();
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
        body: json.encode({'game_id': 'bite_ninja', 'score': score}),
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
        title: const Text('Bite Ninja', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GestureDetector(
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: CustomPaint(
              size: Size.infinite,
              painter: SlicePainter(path: slicePath, color: _neonCyan),
              child: Container(color: Colors.transparent),
            ),
          ),
          
          // Flying Objects
          ...objects.map((obj) {
            if (obj.isSliced) {
              // Show sliced effect
              return Align(
                alignment: Alignment(obj.x * 2 - 1, obj.y * 2 - 1),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(obj.emoji, style: const TextStyle(fontSize: 25)),
                    const SizedBox(width: 5),
                    Text(obj.emoji, style: const TextStyle(fontSize: 25)),
                  ],
                ),
              );
            }
            return Align(
              alignment: Alignment(obj.x * 2 - 1, obj.y * 2 - 1),
              child: Text(obj.emoji, style: const TextStyle(fontSize: 45)),
            );
          }),

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
                    children: List.generate(7, (index) {
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
                  const Text('Slice the food!\nAvoid the bombs 💣', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 18)),
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

class SlicePainter extends CustomPainter {
  final List<Offset> path;
  final Color color;

  SlicePainter({required this.path, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (path.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
      
    // Outer glow
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 14.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final p = Path();
    p.moveTo(path.first.dx, path.first.dy);
    for (int i = 1; i < path.length; i++) {
      p.lineTo(path[i].dx, path[i].dy);
    }
    
    canvas.drawPath(p, glowPaint);
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(covariant SlicePainter oldDelegate) {
    return true;
  }
}
