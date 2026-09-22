import 'dart:convert';
import 'coins_display.dart';
import 'package:flutter/material.dart';
import '../../../core/models/user_model.dart';
import 'package:http/http.dart' as http;

class ScavengerHuntGame extends StatefulWidget {
  final UserModel userModel;

  const ScavengerHuntGame({super.key, required this.userModel});

  @override
  State<ScavengerHuntGame> createState() => _ScavengerHuntGameState();
}

class Riddle {
  final String text;
  final List<String> acceptableAnswers;
  final String icon;

  Riddle(this.text, this.acceptableAnswers, this.icon);
}

class _ScavengerHuntGameState extends State<ScavengerHuntGame> {
  final Color _bgColor = const Color(0xFF0C101B);
  final Color _neonCyan = const Color(0xFF05D5AA);
  final Color _cardColor = const Color(0xFF131A2A);

  List<Riddle> riddles = [];
  int currentIndex = 0;
  int score = 0;
  bool isGameOver = false;
  
  final TextEditingController _answerController = TextEditingController();
  String _feedback = '';

  @override
  void initState() {
    super.initState();
    riddles = [
      Riddle('I hold all the books but I cannot read.', ['library', 'bookshelf'], '📚'),
      Riddle('You go here when you want a hot coffee.', ['cafe', 'coffee shop', 'starbucks'], '☕'),
      Riddle('Where students live on campus.', ['dorm', 'dormitory', 'hostel'], '🛏️'),
      Riddle('A large place for sports and graduation.', ['stadium', 'gym', 'arena'], '🏟️'),
      Riddle('You swipe me to eat food.', ['app', 'phone', 'swapeat', 'dishi'], '📱'),
    ];
  }

  void _checkAnswer() {
    String answer = _answerController.text.trim().toLowerCase();
    if (answer.isEmpty) return;

    if (riddles[currentIndex].acceptableAnswers.contains(answer)) {
      setState(() {
        score += 50;
        _feedback = "Correct! You found it! 🎉";
        _answerController.clear();
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _feedback = '';
            if (currentIndex < riddles.length - 1) {
              currentIndex++;
            } else {
              _showGameOver();
            }
          });
        }
      });
    } else {
      setState(() {
        _feedback = "Not quite... try looking somewhere else! 🕵️";
      });
    }
  }

  void _showGameOver() {
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
        body: json.encode({'game_id': 'scavenger_hunt', 'score': score}),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      print("Error submitting scavenger hunt score: \$e");
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Campus Scavenger Hunt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
        actions: [CoinsDisplay(uid: widget.userModel.uid)],
      ),
      body: isGameOver ? _buildGameOver() : _buildHunt(),
    );
  }

  Widget _buildHunt() {
    final riddle = riddles[currentIndex];
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Location ${currentIndex + 1} of ${riddles.length}',
            style: const TextStyle(color: Colors.white54, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Text(riddle.icon, style: TextStyle(fontSize: 80)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _neonCyan.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(color: _neonCyan.withOpacity(0.1), blurRadius: 20),
              ],
            ),
            child: Text(
              riddle.text,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: _answerController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Type the location name...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: Icon(Icons.search, color: _neonCyan),
                onPressed: _checkAnswer,
              ),
            ),
            onSubmitted: (_) => _checkAnswer(),
          ),
          const SizedBox(height: 20),
          Text(
            _feedback,
            style: TextStyle(
              color: _feedback.contains('Correct') ? _neonCyan : Colors.redAccent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildGameOver() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.explore, color: Colors.greenAccent, size: 100),
          const SizedBox(height: 20),
          const Text(
            'Hunt Completed!',
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'You earned $score Coins!',
            style: TextStyle(color: _neonCyan, fontSize: 20),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _neonCyan,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('BACK TO HUB', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
