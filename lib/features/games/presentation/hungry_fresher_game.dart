import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/game_reward_service.dart';
import 'coins_display.dart';

enum SnakeDirection { up, down, left, right }

class HungryFresherGame extends StatefulWidget {
  final UserModel userModel;

  const HungryFresherGame({super.key, required this.userModel});

  @override
  State<HungryFresherGame> createState() => _HungryFresherGameState();
}

class _HungryFresherGameState extends State<HungryFresherGame> {
  static const int columns = 16;
  static const int rows = 22;

  final Color _bgColor = const Color(0xFF0C101B);
  final Color _neonCyan = const Color(0xFF05D5AA);
  final Color _neonPink = const Color(0xFFF92B60);

  List<int> _snake = [45, 61, 77];
  int _foodIndex = 0;
  String _foodIcon = '🍔';
  bool _isGoldenFood = false;
  int _foodsEaten = 0;

  SnakeDirection _direction = SnakeDirection.down;
  bool _isPlaying = false;
  bool _isGameOver = false;
  int _score = 0;
  Timer? _timer;

  final List<String> _regularFoodIcons = ['🍔', '🍕', '🍎', '🥪', '🥟', '🍟'];

  @override
  void initState() {
    super.initState();
    _spawnFood();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _isGameOver = false;
      _score = 0;
      _foodsEaten = 0;
      _snake = [45, 61, 77];
      _direction = SnakeDirection.down;
      _spawnFood();
    });

    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    // Speed increases slightly as snake gets longer
    int ms = (150 - (_snake.length * 2)).clamp(75, 150);
    _timer = Timer.periodic(Duration(milliseconds: ms), (timer) {
      _tick();
    });
  }

  void _spawnFood() {
    final rand = Random();
    int nextPos = rand.nextInt(columns * rows);
    while (_snake.contains(nextPos)) {
      nextPos = rand.nextInt(columns * rows);
    }
    _foodIndex = nextPos;
    _isGoldenFood = (_foodsEaten > 0 && _foodsEaten % 5 == 0);
    _foodIcon = _isGoldenFood ? '👑' : _regularFoodIcons[rand.nextInt(_regularFoodIcons.length)];
  }

  void _changeDirection(SnakeDirection newDir) {
    if (!_isPlaying) return;

    if ((_direction == SnakeDirection.up && newDir == SnakeDirection.down) ||
        (_direction == SnakeDirection.down && newDir == SnakeDirection.up) ||
        (_direction == SnakeDirection.left && newDir == SnakeDirection.right) ||
        (_direction == SnakeDirection.right && newDir == SnakeDirection.left)) {
      return; // Cannot double back into self
    }

    _direction = newDir;
    HapticFeedback.selectionClick();
  }

  void _tick() {
    if (!_isPlaying) return;

    setState(() {
      int head = _snake.last;
      int newHead = 0;

      switch (_direction) {
        case SnakeDirection.down:
          if (head >= (rows - 1) * columns) {
            newHead = head - ((rows - 1) * columns);
          } else {
            newHead = head + columns;
          }
          break;
        case SnakeDirection.up:
          if (head < columns) {
            newHead = head + ((rows - 1) * columns);
          } else {
            newHead = head - columns;
          }
          break;
        case SnakeDirection.left:
          if (head % columns == 0) {
            newHead = head + columns - 1;
          } else {
            newHead = head - 1;
          }
          break;
        case SnakeDirection.right:
          if ((head + 1) % columns == 0) {
            newHead = head - columns + 1;
          } else {
            newHead = head + 1;
          }
          break;
      }

      // Check self collision
      if (_snake.contains(newHead)) {
        HapticFeedback.heavyImpact();
        _triggerGameOver();
        return;
      }

      _snake.add(newHead);

      // Check food consumption
      if (newHead == _foodIndex) {
        _foodsEaten++;
        int earned = _isGoldenFood ? 50 : 15;
        _score += earned;
        HapticFeedback.mediumImpact();
        _spawnFood();
        _startTimer(); // Adjust speed
      } else {
        _snake.removeAt(0);
      }
    });
  }

  Future<void> _triggerGameOver() async {
    _timer?.cancel();

    setState(() {
      _isPlaying = false;
      _isGameOver = true;
    });

    final res = await GameRewardService.submitScore(
      uid: widget.userModel.uid,
      gameId: 'hungry_fresher',
      score: _score,
    );

    if (!mounted) return;

    GameRewardService.showArcadeGameOverDialog(
      context: context,
      userModel: widget.userModel,
      gameTitle: 'HUNGRY FRESHER',
      score: _score,
      coinsEarned: res.coinsEarned,
      onPlayAgain: _startGame,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Hungry Fresher', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [CoinsDisplay(uid: widget.userModel.uid)],
      ),
      body: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.delta.dy > 5) _changeDirection(SnakeDirection.down);
          if (details.delta.dy < -5) _changeDirection(SnakeDirection.up);
        },
        onHorizontalDragUpdate: (details) {
          if (details.delta.dx > 5) _changeDirection(SnakeDirection.right);
          if (details.delta.dx < -5) _changeDirection(SnakeDirection.left);
        },
        child: Column(
          children: [
            // Score HUD
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131A2A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _neonCyan.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bolt, color: Colors.amber, size: 20),
                        const SizedBox(width: 6),
                        Text('$_score pts', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131A2A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orangeAccent.withOpacity(0.4)),
                    ),
                    child: Text('Length: ${_snake.length}', style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            // Snake Grid Arena
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: columns / rows,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101724),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _neonCyan.withOpacity(0.3), width: 2),
                      boxShadow: [
                        BoxShadow(color: _neonCyan.withOpacity(0.1), blurRadius: 20),
                      ],
                    ),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: columns * rows,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                      ),
                      itemBuilder: (context, index) {
                        final isHead = _snake.isNotEmpty && _snake.last == index;
                        final isBody = _snake.contains(index) && !isHead;
                        final isFood = index == _foodIndex;

                        if (isHead) {
                          return Container(
                            margin: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(5),
                              boxShadow: [
                                BoxShadow(color: _neonCyan, blurRadius: 10, spreadRadius: 1),
                              ],
                            ),
                          );
                        } else if (isBody) {
                          return Container(
                            margin: const EdgeInsets.all(1.5),
                            decoration: BoxDecoration(
                              color: _neonCyan,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        } else if (isFood) {
                          return Center(
                            child: Text(
                              _foodIcon,
                              style: TextStyle(fontSize: _isGoldenFood ? 18 : 16),
                            ),
                          );
                        }

                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
              ),
            ),

            // Tactile D-PAD Controls for easy thumb control
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dpadButton(Icons.keyboard_arrow_up, SnakeDirection.up),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _dpadButton(Icons.keyboard_arrow_left, SnakeDirection.left),
                      const SizedBox(width: 44),
                      _dpadButton(Icons.keyboard_arrow_right, SnakeDirection.right),
                    ],
                  ),
                  _dpadButton(Icons.keyboard_arrow_down, SnakeDirection.down),
                ],
              ),
            ),

            if (!_isPlaying && !_isGameOver)
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: _startGame,
                  child: const Text('START GAME', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dpadButton(IconData icon, SnakeDirection dir) {
    return InkWell(
      onTap: () => _changeDirection(dir),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF131A2A),
          shape: BoxShape.circle,
          border: Border.all(color: _neonCyan.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: _neonCyan.withOpacity(0.1), blurRadius: 8),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
