import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/game_reward_service.dart';
import 'coins_display.dart';

class MemoryCard {
  final int id;
  final String icon;
  final String name;
  bool isFlipped;
  bool isMatched;

  MemoryCard({
    required this.id,
    required this.icon,
    required this.name,
    this.isFlipped = false,
    this.isMatched = false,
  });
}

class MemoryMatchGame extends StatefulWidget {
  final UserModel userModel;

  const MemoryMatchGame({super.key, required this.userModel});

  @override
  State<MemoryMatchGame> createState() => _MemoryMatchGameState();
}

class _MemoryMatchGameState extends State<MemoryMatchGame> {
  final Color _bgColor = const Color(0xFF0C101B);
  final Color _cardColor = const Color(0xFF131A2A);
  final Color _neonCyan = const Color(0xFF05D5AA);
  final Color _neonPink = const Color(0xFFF92B60);

  final List<Map<String, String>> _cardTypes = [
    {'icon': '🍕', 'name': 'Pizza'},
    {'icon': '🍔', 'name': 'Burger'},
    {'icon': '🍟', 'name': 'Fries'},
    {'icon': '🌮', 'name': 'Taco'},
    {'icon': '🥑', 'name': 'Avocado'},
    {'icon': '🍎', 'name': 'Apple'},
    {'icon': '🥪', 'name': 'Sandwich'},
    {'icon': '🥤', 'name': 'Soda'},
  ];

  List<MemoryCard> _cards = [];
  int? _firstSelectedIndex;
  bool _isProcessing = false;
  int _score = 0;
  int _matchesFound = 0;
  int _timeLeft = 60;
  int _streak = 0;
  Timer? _countdownTimer;

  bool _isPlaying = false;
  bool _isGameOver = false;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    List<MemoryCard> pool = [];
    int idCounter = 0;
    for (var ct in _cardTypes) {
      pool.add(MemoryCard(id: idCounter++, icon: ct['icon']!, name: ct['name']!));
      pool.add(MemoryCard(id: idCounter++, icon: ct['icon']!, name: ct['name']!));
    }
    pool.shuffle();

    setState(() {
      _cards = pool;
      _firstSelectedIndex = null;
      _isProcessing = false;
      _score = 0;
      _matchesFound = 0;
      _streak = 0;
      _timeLeft = 60;
      _isPlaying = true;
      _isGameOver = false;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        timer.cancel();
        _triggerGameOver(timeout: true);
      }
    });
  }

  void _onCardTapped(int index) {
    if (!_isPlaying || _isProcessing || _cards[index].isFlipped || _cards[index].isMatched) {
      return;
    }

    HapticFeedback.lightImpact();

    setState(() {
      _cards[index].isFlipped = true;
    });

    if (_firstSelectedIndex == null) {
      _firstSelectedIndex = index;
    } else {
      _isProcessing = true;
      final int firstIdx = _firstSelectedIndex!;

      if (_cards[firstIdx].icon == _cards[index].icon) {
        // Matched!
        _streak++;
        int earned = 20 + (_streak * 5);
        _score += earned;
        _matchesFound++;
        HapticFeedback.mediumImpact();

        setState(() {
          _cards[firstIdx].isMatched = true;
          _cards[index].isMatched = true;
          _firstSelectedIndex = null;
          _isProcessing = false;
        });

        if (_matchesFound == _cardTypes.length) {
          // All matched! Bonus time points
          _score += (_timeLeft * 5);
          _countdownTimer?.cancel();
          _triggerGameOver(timeout: false);
        }
      } else {
        // Mismatch
        _streak = 0;
        Future.delayed(const Duration(milliseconds: 700), () {
          if (!mounted) return;
          setState(() {
            _cards[firstIdx].isFlipped = false;
            _cards[index].isFlipped = false;
            _firstSelectedIndex = null;
            _isProcessing = false;
          });
        });
      }
    }
  }

  Future<void> _triggerGameOver({required bool timeout}) async {
    _countdownTimer?.cancel();

    setState(() {
      _isPlaying = false;
      _isGameOver = true;
    });

    final res = await GameRewardService.submitScore(
      uid: widget.userModel.uid,
      gameId: 'memory_match',
      score: _score,
    );

    if (!mounted) return;

    GameRewardService.showArcadeGameOverDialog(
      context: context,
      userModel: widget.userModel,
      gameTitle: 'MEMORY MATCH',
      score: _score,
      coinsEarned: res.coinsEarned,
      isVictory: !timeout,
      onPlayAgain: _startGame,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Memory Match', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [CoinsDisplay(uid: widget.userModel.uid)],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // HUD
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _cardColor,
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _timeLeft < 15 ? _neonPink : Colors.orangeAccent),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer, color: _timeLeft < 15 ? _neonPink : Colors.orangeAccent, size: 20),
                        const SizedBox(width: 6),
                        Text('${_timeLeft}s', style: TextStyle(color: _timeLeft < 15 ? _neonPink : Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 4x4 Grid of Cards
              if (_isPlaying || _isGameOver)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _cards.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.9,
                  ),
                  itemBuilder: (context, index) {
                    final card = _cards[index];
                    final isRevealed = card.isFlipped || card.isMatched;

                    return InkWell(
                      onTap: () => _onCardTapped(index),
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        decoration: BoxDecoration(
                          gradient: isRevealed
                              ? LinearGradient(
                                  colors: card.isMatched
                                      ? [const Color(0xFF05D5AA).withOpacity(0.3), const Color(0xFF036952)]
                                      : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : const LinearGradient(
                                  colors: [Color(0xFF1B2336), Color(0xFF111728)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: card.isMatched
                                ? _neonCyan
                                : (isRevealed ? Colors.white38 : _neonCyan.withOpacity(0.3)),
                            width: card.isMatched ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (card.isMatched ? _neonCyan : Colors.black).withOpacity(0.2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Center(
                          child: isRevealed
                              ? Text(card.icon, style: const TextStyle(fontSize: 34))
                              : Icon(Icons.question_mark_rounded, color: _neonCyan.withOpacity(0.5), size: 28),
                        ),
                      ),
                    );
                  },
                )
              else
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _neonCyan.withOpacity(0.3)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🧠 CAMPUS MEMORY MATCH 🥪', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 12),
                        const Text(
                          'Flip and match pairs of campus food in under 60 seconds!\n\nStreak combos give massive score multipliers!\nLeftover time turns into bonus Dishi Coins!',
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
                          child: const Text('START GAME', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
