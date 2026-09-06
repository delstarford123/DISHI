import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class FlashcardsView extends StatefulWidget {
  const FlashcardsView({super.key});

  @override
  State<FlashcardsView> createState() => _FlashcardsViewState();
}

class _FlashcardsViewState extends State<FlashcardsView> with SingleTickerProviderStateMixin {
  final String _studentId = FirebaseAuth.instance.currentUser?.uid ?? "demo_student";
  List<dynamic> _cards = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isReversed = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
    _fetchCards();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchCards() async {
    setState(() { _isLoading = true; });
    try {
      final response = await http.get(
        Uri.parse('https://swapeatbackend.vercel.app/api/v3/academic/flashcards?student_id=$_studentId'),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _cards = data['flashcards'] ?? [];
          
          // Filter to only show cards that are due for review
          // For demonstration, if no cards are due or list is empty, we will add a fallback dummy card
          if (_cards.isEmpty) {
            _cards = [
              {
                'id': 'dummy1',
                'question': 'What is the time complexity of searching in a balanced BST?',
                'answer': 'O(log n)'
              },
              {
                'id': 'dummy2',
                'question': 'What does HTTP stand for?',
                'answer': 'HyperText Transfer Protocol'
              }
            ];
          }
        });
      } else {
        throw Exception('Failed to load flashcards');
      }
    } catch (e) {
      // Fallback data if network fails
      setState(() {
        _cards = [
          {
            'id': 'dummy1',
            'question': 'What is the time complexity of searching in a balanced BST?',
            'answer': 'O(log n)'
          }
        ];
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading cards: $e')));
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  void _flipCard() {
    if (_isReversed) {
      _animationController.reverse();
    } else {
      _animationController.forward();
    }
    setState(() {
      _isReversed = !_isReversed;
    });
  }

  Future<void> _submitReview(int quality) async {
    final currentCard = _cards[_currentIndex];
    
    // Optimistically move to next card
    setState(() {
      _isReversed = false;
      _animationController.reset();
      if (_currentIndex < _cards.length - 1) {
        _currentIndex++;
      } else {
        // Done with deck
        _cards = [];
      }
    });

    try {
      final response = await http.post(
        Uri.parse('https://swapeatbackend.vercel.app/api/v3/academic/flashcards/review'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': _studentId,
          'card_id': currentCard['id'],
          'quality': quality,
        })
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to update flashcard');
      }
    } catch (e) {
      print("Review submission failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('SM-2 Flashcards', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: _neonPink))
        : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Deck: All', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('${_cards.length - _currentIndex} to review', style: const TextStyle(color: _neonPink, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 32),
            Expanded(
              child: _cards.isEmpty
                  ? const Center(child: Text("You're all caught up for today!", style: TextStyle(color: Colors.white, fontSize: 18)))
                  : GestureDetector(
                      onTap: _flipCard,
                      child: AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          final angle = _animation.value * pi;
                          final isFront = angle < (pi / 2);
                          
                          return Transform(
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateY(angle),
                            alignment: Alignment.center,
                            child: isFront 
                                ? _buildCardFace(_cards[_currentIndex]['question'] ?? '', false) 
                                : Transform(
                                    transform: Matrix4.identity()..rotateY(pi), // Flip text back to readable
                                    alignment: Alignment.center,
                                    child: _buildCardFace(_cards[_currentIndex]['answer'] ?? '', true)
                                  ),
                          );
                        }
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            Text(_isReversed ? 'How well did you know this?' : 'Tap card to reveal answer', style: const TextStyle(color: _textSecondary)),
            const SizedBox(height: 32),
            AnimatedOpacity(
              opacity: _isReversed ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Row(
                children: [
                  Expanded(child: _buildResponseButton('Again', _neonPink, () => _submitReview(0))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildResponseButton('Hard', Colors.orange, () => _submitReview(1))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildResponseButton('Good', Colors.blue, () => _submitReview(3))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildResponseButton('Easy', _neonCyan, () => _submitReview(5))),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCardFace(String text, bool isAnswer) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isAnswer ? _neonCyan.withOpacity(0.5) : Colors.purpleAccent.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(color: isAnswer ? _neonCyan.withOpacity(0.1) : Colors.purpleAccent.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)
        ]
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildResponseButton(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: _isReversed ? onPressed : null, // Disable if not reversed
      child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}
