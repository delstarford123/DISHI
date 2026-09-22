import 'package:flutter/material.dart';
import '../../../core/models/user_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'coins_display.dart';

class TasteMatchGame extends StatefulWidget {
  final UserModel userModel;

  const TasteMatchGame({super.key, required this.userModel});

  @override
  State<TasteMatchGame> createState() => _TasteMatchGameState();
}

class FoodCombo {
  final String title;
  final String icon;
  final String description;

  FoodCombo(this.title, this.icon, this.description);
}

class _TasteMatchGameState extends State<TasteMatchGame> {
  final Color _bgColor = const Color(0xFF0C101B);
  final Color _neonCyan = const Color(0xFF05D5AA);
  final Color _neonPink = const Color(0xFFF92B60);
  final Color _cardColor = const Color(0xFF131A2A);

  List<FoodCombo> deck = [];
  int currentIndex = 0;
  int score = 0; // Just for fun, maybe count swipes
  bool isGameOver = false;
  
  Map<String, String> preferences = {}; // Store likes/dislikes

  @override
  void initState() {
    super.initState();
    _loadDeck();
  }

  void _loadDeck() {
    deck = [
      FoodCombo('Spicy Pizza', '🍕', 'Hot and cheesy!'),
      FoodCombo('Burger & Fries', '🍔', 'The classic.'),
      FoodCombo('Avocado Toast', '🥬', 'Healthy start.'),
      FoodCombo('Sweet Donut', '🍩', 'Sugar rush!'),
      FoodCombo('Taco Tuesday', '🍽️', 'Crunchy goodness.'),
      FoodCombo('Fruit Bowl', '🍎', 'Fresh and juicy.'),
    ];
    deck.shuffle();
  }

  void _handleSwipe(bool liked) {
    if (currentIndex < deck.length) {
      preferences[deck[currentIndex].title] = liked ? 'loved' : 'hated';
      setState(() {
        score += 10;
        currentIndex++;
        if (currentIndex >= deck.length) {
          _showGameOver();
        }
      });
    }
  }

  void _showGameOver() {
    setState(() {
      isGameOver = true;
    });
    _submitProfile();
  }

  Future<void> _submitProfile() async {
    // In a real app, this sends the taste profile to the backend to match students.
    // For now, we just submit a score to give them Dishi coins for playing.
    try {
      await http.post(
        Uri.parse('https://swapeatbackend.vercel.app/api/v1/games/score'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.userModel.uid}'},
        body: json.encode({'game_id': 'taste_match', 'score': score}),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      print("Error submitting taste match: \$e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Taste Match', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
        actions: [CoinsDisplay(uid: widget.userModel.uid)],
      ),
      body: isGameOver ? _buildGameOver() : _buildDeck(),
    );
  }

  Widget _buildDeck() {
    if (currentIndex >= deck.length) return const SizedBox();

    final currentCard = deck[currentIndex];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.0),
          child: Text(
            'Swipe Right if you LOVE it.\nSwipe Left if you HATE it.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
        const SizedBox(height: 40),
        Center(
          child: Dismissible(
            key: ValueKey(currentCard.title),
            onDismissed: (direction) {
              _handleSwipe(direction == DismissDirection.startToEnd);
            },
            background: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 40.0),
              decoration: BoxDecoration(
                color: _neonPink.withOpacity(0.8),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('❌', style: TextStyle(fontSize: 48)),
                  Text('HATE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                ],
              ),
            ),
            secondaryBackground: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 40.0),
              decoration: BoxDecoration(
                color: _neonCyan.withOpacity(0.8),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('❤️', style: TextStyle(fontSize: 48)),
                  Text('LOVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                ],
              ),
            ),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: 400,
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(color: _neonCyan.withOpacity(0.2), blurRadius: 30, spreadRadius: -5),
                ],
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(currentCard.icon, style: TextStyle(fontSize: 100)),
                  const SizedBox(height: 20),
                  Text(
                    currentCard.title,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      currentCard.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            FloatingActionButton(
              heroTag: 'hate',
              backgroundColor: _cardColor,
              onPressed: () => _handleSwipe(false),
              child: Text('❌', style: TextStyle(fontSize: 30)),
            ),
            FloatingActionButton(
              heroTag: 'love',
              backgroundColor: _cardColor,
              onPressed: () => _handleSwipe(true),
              child: Text('❤️', style: TextStyle(fontSize: 30)),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildGameOver() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('✅', style: const TextStyle(fontSize: 80)),
          const SizedBox(height: 20),
          const Text(
            'Taste Profile Built!',
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'We saved your weird food preferences. Check your Match Hub later to see if anyone else likes Ketchup on Eggs.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
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
