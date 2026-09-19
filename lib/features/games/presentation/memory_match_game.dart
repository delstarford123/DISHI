import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/models/user_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'coins_display.dart';

class MemoryMatchGame extends StatefulWidget {
  final UserModel userModel;

  const MemoryMatchGame({super.key, required this.userModel});

  @override
  State<MemoryMatchGame> createState() => _MemoryMatchGameState();
}

class MemoryCard {
  final String emoji;
  bool isFlipped;
  bool isMatched;

  MemoryCard(this.emoji, {this.isFlipped = false, this.isMatched = false});
}

class _MemoryMatchGameState extends State<MemoryMatchGame> {
  final Color _bgColor = const Color(0xFF0C101B);
  final Color _neonCyan = const Color(0xFF05D5AA);
  final Color _cardColor = const Color(0xFF131A2A);

  List<MemoryCard> cards = [];
  int? firstSelectedIndex;
  bool isProcessing = false;
  int score = 0;
  int matchesFound = 0;
  bool isGameOver = false;
  
  Timer? _timer;
  int timeLeft = 60;

  final List<String> _emojiPool = [
    '🍔', '🍟', '🍕', '🍎', '🌮', '🍩', '🥑', '🍿',
    '🌭', '🥗', '🥪', '🥩', '🥘', '🍣'
  ];

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  void _initGame() {
    _timer?.cancel();
    List<String> deck = [];
    for (var emoji in _emojiPool) {
      deck.add(emoji);
      deck.add(emoji); // Add pairs
    }
    deck.shuffle(Random()); // Ensure totally random shuffle every time

    setState(() {
      cards = deck.map((e) => MemoryCard(e)).toList();
      score = 0;
      matchesFound = 0;
      isGameOver = false;
      firstSelectedIndex = null;
      isProcessing = false;
      timeLeft = 60;
    });

    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timeLeft > 0 && !isGameOver) {
        setState(() {
          timeLeft--;
        });
      } else {
        _timer?.cancel();
        if (!isGameOver) {
          _showGameOver(timeout: true);
        }
      }
    });
  }

  void _onCardTap(int index) {
    if (isProcessing || cards[index].isFlipped || cards[index].isMatched) return;

    setState(() {
      cards[index].isFlipped = true;
    });

    if (firstSelectedIndex == null) {
      firstSelectedIndex = index;
    } else {
      _checkForMatch(firstSelectedIndex!, index);
    }
  }

  void _checkForMatch(int index1, int index2) async {
    setState(() {
      isProcessing = true;
    });

    if (cards[index1].emoji == cards[index2].emoji) {
      // Match found
      setState(() {
        cards[index1].isMatched = true;
        cards[index2].isMatched = true;
        score += 20;
        matchesFound++;
        firstSelectedIndex = null;
        isProcessing = false;
        if (matchesFound == _emojiPool.length) {
          _timer?.cancel();
          // Add remaining time as bonus score
          score += (timeLeft * 5);
          _showGameOver(timeout: false);
        }
      });
    } else {
      // No match
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() {
        cards[index1].isFlipped = false;
        cards[index2].isFlipped = false;
        firstSelectedIndex = null;
        isProcessing = false;
      });
    }
  }

  void _showGameOver({required bool timeout}) {
    setState(() {
      isGameOver = true;
    });
    _submitScore();
  }

  Future<void> _submitScore() async {
    try {
      await http.post(
        Uri.parse('https://swapeatbackend.vercel.app/api/v1/games/score'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.userModel.uid}'},
        body: json.encode({'game_id': 'memory_match', 'score': score}),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      print("Error submitting memory score: \$e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Memory Match', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
        actions: [
          CoinsDisplay(uid: widget.userModel.uid),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(child: Text('Score: $score', style: TextStyle(color: _neonCyan, fontSize: 18, fontWeight: FontWeight.bold))),
          )
        ],
      ),
      body: isGameOver ? _buildGameOver() : _buildGrid(),
    );
  }

  Widget _buildGrid() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Find all pairs!',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: timeLeft <= 10 ? Colors.redAccent.withOpacity(0.2) : _neonCyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: timeLeft <= 10 ? Colors.redAccent : _neonCyan),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer, color: timeLeft <= 10 ? Colors.redAccent : _neonCyan, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '00:${timeLeft.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: timeLeft <= 10 ? Colors.redAccent : Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: cards.length,
              itemBuilder: (context, index) {
                final card = cards[index];
                final isFaceUp = card.isFlipped || card.isMatched;

                return GestureDetector(
                  onTap: () => _onCardTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: isFaceUp ? Colors.white : _cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: card.isMatched ? _neonCyan : Colors.white.withOpacity(0.1),
                        width: card.isMatched ? 3 : 1,
                      ),
                      boxShadow: card.isMatched
                          ? [BoxShadow(color: _neonCyan.withOpacity(0.5), blurRadius: 10)]
                          : [],
                    ),
                    child: Center(
                      child: isFaceUp
                          ? Text(card.emoji, style: const TextStyle(fontSize: 40))
                          : Icon(Icons.help_outline, color: _neonCyan.withOpacity(0.5), size: 30),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOver() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star, color: Colors.yellowAccent, size: 100),
          const SizedBox(height: 20),
          Text(
            timeLeft > 0 ? 'YOU WIN' : 'YOU LOSE',
            style: TextStyle(
              color: timeLeft > 0 ? Colors.greenAccent : Colors.redAccent,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            timeLeft > 0 ? 'All Paired Up!' : 'Time\'s Up!',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'Final Score: $score',
            style: TextStyle(color: _neonCyan, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cardColor,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('QUIT', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _neonCyan,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: _initGame,
                child: const Text('PLAY AGAIN', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
