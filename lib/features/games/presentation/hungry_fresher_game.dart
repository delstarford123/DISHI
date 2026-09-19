import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/models/user_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sensors_plus/sensors_plus.dart';

enum Direction { up, down, left, right }

class HungryFresherGame extends StatefulWidget {
  final UserModel userModel;

  const HungryFresherGame({super.key, required this.userModel});

  @override
  State<HungryFresherGame> createState() => _HungryFresherGameState();
}

class _HungryFresherGameState extends State<HungryFresherGame> {
  final int squaresPerRow = 20;
  final int squaresPerCol = 30;
  
  List<int> snakePosition = [45, 65, 85, 105, 125];
  int foodPosition = 0;
  Direction direction = Direction.down;
  bool isPlaying = false;
  bool isGameOver = false;
  int score = 0;
  Timer? gameTimer;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;

  final Color _bgColor = const Color(0xFF0C101B);
  final Color _neonCyan = const Color(0xFF05D5AA);
  final Color _neonPink = const Color(0xFFF92B60);

  @override
  void initState() {
    super.initState();
    _generateNewFood();
  }

  void startGame() {
    setState(() {
      isPlaying = true;
      isGameOver = false;
      score = 0;
      snakePosition = [45, 65, 85, 105, 125];
      direction = Direction.down;
    });

    _accelSubscription?.cancel();
    _accelSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      if (!isPlaying) return;
      
      const double threshold = 3.0; // Sensitivity
      if (event.x > threshold && direction != Direction.right) {
        direction = Direction.left;
      } else if (event.x < -threshold && direction != Direction.left) {
        direction = Direction.right;
      } else if (event.y > threshold && direction != Direction.up) {
        direction = Direction.down;
      } else if (event.y < -threshold && direction != Direction.down) {
        direction = Direction.up;
      }
    });
    
    gameTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      updateSnake();
      if (_checkGameOver()) {
        timer.cancel();
        _showGameOverDialog();
      }
    });
  }

  void updateSnake() {
    setState(() {
      switch (direction) {
        case Direction.down:
          if (snakePosition.last > (squaresPerRow * squaresPerCol) - squaresPerRow - 1) {
            snakePosition.add(snakePosition.last + squaresPerRow - (squaresPerRow * squaresPerCol));
          } else {
            snakePosition.add(snakePosition.last + squaresPerRow);
          }
          break;
        case Direction.up:
          if (snakePosition.last < squaresPerRow) {
            snakePosition.add(snakePosition.last - squaresPerRow + (squaresPerRow * squaresPerCol));
          } else {
            snakePosition.add(snakePosition.last - squaresPerRow);
          }
          break;
        case Direction.left:
          if (snakePosition.last % squaresPerRow == 0) {
            snakePosition.add(snakePosition.last - 1 + squaresPerRow);
          } else {
            snakePosition.add(snakePosition.last - 1);
          }
          break;
        case Direction.right:
          if ((snakePosition.last + 1) % squaresPerRow == 0) {
            snakePosition.add(snakePosition.last + 1 - squaresPerRow);
          } else {
            snakePosition.add(snakePosition.last + 1);
          }
          break;
      }

      if (snakePosition.last == foodPosition) {
        score += 10;
        _generateNewFood();
      } else {
        snakePosition.removeAt(0);
      }
    });
  }

  void _generateNewFood() {
    foodPosition = Random().nextInt(squaresPerRow * squaresPerCol);
    while (snakePosition.contains(foodPosition)) {
      foodPosition = Random().nextInt(squaresPerRow * squaresPerCol);
    }
  }

  bool _checkGameOver() {
    for (int i = 0; i < snakePosition.length - 1; i++) {
      if (snakePosition.last == snakePosition[i]) {
        return true;
      }
    }
    return false;
  }

  Future<void> _submitScore() async {
    try {
      final response = await http.post(
        Uri.parse('https://swapeatbackend.vercel.app/api/v1/games/score'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.userModel.uid}'},
        body: json.encode({'game_id': 'hungry_fresher', 'score': score}),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Score submitted securely!')));
        }
      }
    } catch (e) {
      print("Error submitting score: \$e");
    }
  }

  void _showGameOverDialog() {
    _accelSubscription?.cancel();
    setState(() {
      isPlaying = false;
      isGameOver = true;
    });
    
    _submitScore();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
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
        );
      },
    );
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    _accelSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Hungry Fresher', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text('Score: $score', style: TextStyle(color: _neonCyan, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (details) {
                if (direction != Direction.up && details.delta.dy > 0) {
                  direction = Direction.down;
                } else if (direction != Direction.down && details.delta.dy < 0) {
                  direction = Direction.up;
                }
              },
              onHorizontalDragUpdate: (details) {
                if (direction != Direction.left && details.delta.dx > 0) {
                  direction = Direction.right;
                } else if (direction != Direction.right && details.delta.dx < 0) {
                  direction = Direction.left;
                }
              },
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: squaresPerRow * squaresPerCol,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: squaresPerRow,
                ),
                itemBuilder: (context, index) {
                  if (snakePosition.contains(index)) {
                    return Container(
                      padding: const EdgeInsets.all(2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          color: index == snakePosition.last ? Colors.white : _neonCyan,
                        ),
                      ),
                    );
                  }
                  if (index == foodPosition) {
                    return Container(
                      padding: const EdgeInsets.all(2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          color: _neonPink,
                          child: const Center(child: Text('🍔', style: TextStyle(fontSize: 10))),
                        ),
                      ),
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.02)),
                    ),
                  );
                },
              ),
            ),
          ),
          if (!isPlaying && !isGameOver)
            Padding(
              padding: const EdgeInsets.only(bottom: 50.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _neonCyan,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: startGame,
                child: const Text('START GAME', style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}
