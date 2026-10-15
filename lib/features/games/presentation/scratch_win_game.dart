import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/game_reward_service.dart';
import 'coins_display.dart';

class ScratchWinGame extends StatefulWidget {
  final UserModel userModel;

  const ScratchWinGame({super.key, required this.userModel});

  @override
  State<ScratchWinGame> createState() => _ScratchWinGameState();
}

class _ScratchWinGameState extends State<ScratchWinGame> {
  final Color _bgColor = const Color(0xFF0C101B);
  final Color _cardColor = const Color(0xFF131A2A);
  final Color _neonCyan = const Color(0xFF05D5AA);

  final List<Map<String, dynamic>> _symbols = [
    {'icon': '💎', 'coins': 1000, 'name': 'DIAMOND JACKPOT'},
    {'icon': '🍕', 'coins': 150, 'name': 'HOT PIZZA'},
    {'icon': '🍔', 'coins': 100, 'name': 'BIG BURGER'},
    {'icon': '🥑', 'coins': 75, 'name': 'FRESH AVOCADO'},
    {'icon': '🍎', 'coins': 50, 'name': 'CRUNCHY APPLE'},
    {'icon': '🥤', 'coins': 25, 'name': 'COLD SODA'},
  ];

  List<String> _grid = [];
  List<bool> _revealed = [];
  bool _isGameOver = false;
  int _revealedCount = 0;

  @override
  void initState() {
    super.initState();
    _newCard();
  }

  void _newCard() {
    final rand = Random();
    // 50% chance the card has a 3-of-a-kind winner
    final willWin = rand.nextDouble() < 0.55;

    List<String> items = [];

    if (willWin) {
      // Pick winning symbol
      final winSymbol = _symbols[rand.nextInt(_symbols.length)]['icon'] as String;
      items = [winSymbol, winSymbol, winSymbol];
      while (items.length < 9) {
        final other = _symbols[rand.nextInt(_symbols.length)]['icon'] as String;
        items.add(other);
      }
    } else {
      // Random symbols without guaranteed 3 of any
      while (items.length < 9) {
        final sym = _symbols[rand.nextInt(_symbols.length)]['icon'] as String;
        if (items.where((s) => s == sym).length < 2) {
          items.add(sym);
        } else {
          items.add(_symbols[rand.nextInt(_symbols.length)]['icon'] as String);
        }
      }
    }

    items.shuffle();

    setState(() {
      _grid = items;
      _revealed = List.filled(9, false);
      _revealedCount = 0;
      _isGameOver = false;
    });
  }

  void _scratchTile(int index) {
    if (_isGameOver || _revealed[index]) return;

    HapticFeedback.lightImpact();

    setState(() {
      _revealed[index] = true;
      _revealedCount++;
    });

    _checkWinState();
  }

  void _checkWinState() {
    // Check if 3 matching symbols are currently revealed
    final Map<String, int> counts = {};
    for (int i = 0; i < 9; i++) {
      if (_revealed[i]) {
        counts[_grid[i]] = (counts[_grid[i]] ?? 0) + 1;
      }
    }

    for (var entry in counts.entries) {
      if (entry.value >= 3) {
        _handleWin(entry.key);
        return;
      }
    }

    // If all 9 revealed with no 3-of-a-kind
    if (_revealedCount == 9) {
      setState(() {
        _isGameOver = true;
      });
      _handleNoWin();
    }
  }

  Future<void> _handleWin(String symbol) async {
    final match = _symbols.firstWhere((s) => s['icon'] == symbol);
    final int prizeCoins = match['coins'] as int;

    HapticFeedback.heavyImpact();

    setState(() {
      _isGameOver = true;
      // Reveal entire ticket
      _revealed = List.filled(9, true);
    });

    final res = await GameRewardService.submitScore(
      uid: widget.userModel.uid,
      gameId: 'scratch_win',
      score: prizeCoins * 100,
      overrideCoins: prizeCoins,
    );

    if (!mounted) return;

    GameRewardService.showArcadeGameOverDialog(
      context: context,
      userModel: widget.userModel,
      gameTitle: 'SCRATCH & WIN',
      score: prizeCoins,
      scoreLabel: 'PRIZE MATCH',
      coinsEarned: res.coinsEarned,
      isVictory: true,
      onPlayAgain: _newCard,
    );
  }

  Future<void> _handleNoWin() async {
    HapticFeedback.mediumImpact();
    // Submit 1 coin for attempting
    final res = await GameRewardService.submitScore(
      uid: widget.userModel.uid,
      gameId: 'scratch_win',
      score: 10,
      overrideCoins: 1,
    );

    if (!mounted) return;

    GameRewardService.showArcadeGameOverDialog(
      context: context,
      userModel: widget.userModel,
      gameTitle: 'SCRATCH & WIN',
      score: 0,
      scoreLabel: 'NO MATCH THIS TIME',
      coinsEarned: res.coinsEarned,
      onPlayAgain: _newCard,
    );
  }

  void _scratchAll() {
    for (int i = 0; i < 9; i++) {
      _scratchTile(i);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Scratch & Win', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [CoinsDisplay(uid: widget.userModel.uid)],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Lottery Card Outer Frame
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E283D), Color(0xFF111728)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.amber, width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.amber.withOpacity(0.18), blurRadius: 28),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('GOLDEN DISHI LOTTO', style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber),
                          ),
                          child: const Text('MATCH 3 TO WIN', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 3x3 Scratch Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 9,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.0,
                      ),
                      itemBuilder: (context, index) {
                        final isRevealed = _revealed[index];

                        return InkWell(
                          onTap: () => _scratchTile(index),
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              gradient: isRevealed
                                  ? const LinearGradient(
                                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : const LinearGradient(
                                      colors: [Color(0xFFFFD54F), Color(0xFFFFA000)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isRevealed ? _neonCyan.withOpacity(0.5) : Colors.white70,
                                width: isRevealed ? 2 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isRevealed ? _neonCyan : Colors.amber).withOpacity(0.2),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Center(
                              child: isRevealed
                                  ? Text(
                                      _grid[index],
                                      style: const TextStyle(fontSize: 40),
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.touch_app, color: Colors.brown[900], size: 24),
                                        const SizedBox(height: 2),
                                        Text(
                                          'SCRATCH',
                                          style: TextStyle(
                                            color: Colors.brown[900],
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _scratchAll,
                            child: const Text('REVEAL ALL'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _newCard,
                            child: const Text('NEW TICKET 🎟️', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              // Prize Legend
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('PRIZE PAYOUT LEGEND', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: _symbols.map((s) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(s['icon'] as String, style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 6),
                              Text('x3 = ${s['coins']} 🪙', style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
