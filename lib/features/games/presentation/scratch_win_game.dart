import 'package:flutter/material.dart';
import '../../../core/models/user_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'coins_display.dart';
import 'dart:math';

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
  final Color _neonPink = const Color(0xFFF92B60);

  final List<String> possiblePrizes = ['🪙', '🪙', '🪙', '🍒', '🍒', '🍉', '🍉', '💎'];
  List<String> board = [];
  List<bool> revealed = [];
  bool isGameOver = false;
  int revealedCount = 0;
  String? winMessage;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  void _initGame() {
    final rand = Random();
    board = [];
    
    // We want 9 tiles. 
    // To ensure they can win sometimes, we randomly build the board.
    for (int i = 0; i < 9; i++) {
      board.add(possiblePrizes[rand.nextInt(possiblePrizes.length)]);
    }

    setState(() {
      revealed = List.filled(9, false);
      revealedCount = 0;
      isGameOver = false;
      winMessage = null;
    });
  }

  void _revealTile(int index) {
    if (isGameOver || revealed[index]) return;

    setState(() {
      revealed[index] = true;
      revealedCount++;
    });

    _checkWin();
  }

  void _checkWin() {
    if (revealedCount < 9) {
      // Check if they already hit 3 of a kind among revealed ones
      Map<String, int> counts = {};
      for (int i = 0; i < 9; i++) {
        if (revealed[i]) {
          counts[board[i]] = (counts[board[i]] ?? 0) + 1;
        }
      }

      for (var entry in counts.entries) {
        if (entry.value >= 3) {
          _triggerWin(entry.key);
          return;
        }
      }
    } else {
      // Game over, all revealed, no win
      setState(() {
        isGameOver = true;
        winMessage = "Better luck next time!";
      });
    }
  }

  void _triggerWin(String symbol) {
    setState(() {
      isGameOver = true;
      // Reveal the rest
      revealed = List.filled(9, true);
      
      int coins = 0;
      if (symbol == '🪙') coins = 50;
      else if (symbol == '🍒') coins = 100;
      else if (symbol == '🍉') coins = 250;
      else if (symbol == '💎') coins = 1000;

      winMessage = "JACKPOT! You won $coins Coins!";
      _submitScore(coins);
    });
  }

  Future<void> _submitScore(int coins) async {
    try {
      await http.post(
        Uri.parse('https://swapeatbackend.vercel.app/api/v1/games/score'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.userModel.uid}'},
        body: json.encode({'game_id': 'scratch_win', 'score': coins * 100}), // Scale up
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      print("Error submitting scratch score: \$e");
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
        actions: [CoinsDisplay(uid: widget.userModel.uid)],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Match 3 symbols to win a prize!', style: TextStyle(color: Colors.white70, fontSize: 18)),
              const SizedBox(height: 10),
              const Text('💎 = 1000  |  🍉 = 250  |  🍒 = 100  |  🪙 = 50', style: TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 40),
              
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: 9,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => _revealTile(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        color: revealed[index] ? Colors.white : _cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: revealed[index] ? Colors.white : _neonCyan.withOpacity(0.3),
                          width: revealed[index] ? 0 : 2,
                        ),
                        boxShadow: revealed[index] ? [
                          BoxShadow(color: _neonCyan.withOpacity(0.5), blurRadius: 10)
                        ] : [],
                      ),
                      child: Center(
                        child: revealed[index]
                            ? Text(board[index], style: const TextStyle(fontSize: 40))
                            : Icon(Icons.star, color: _neonCyan.withOpacity(0.5), size: 30),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              if (winMessage != null) ...[
                Text(
                  winMessage!.contains('JACKPOT') ? 'YOU WIN' : 'YOU LOSE',
                  style: TextStyle(
                    color: winMessage!.contains('JACKPOT') ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  winMessage!,
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonCyan,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: _initGame,
                  child: const Text('PLAY AGAIN', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
