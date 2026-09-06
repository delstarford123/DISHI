import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/theme/glass_card.dart';

class MatchTruthOrDrinkView extends StatefulWidget {
  final Map<String, dynamic>? userModel;
  final String? opponentUid;
  final String? gameSessionId;
  
  const MatchTruthOrDrinkView({super.key, this.userModel, this.opponentUid, this.gameSessionId});

  @override
  State<MatchTruthOrDrinkView> createState() => _MatchTruthOrDrinkViewState();
}

class _MatchTruthOrDrinkViewState extends State<MatchTruthOrDrinkView> with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _frontRotation;
  late Animation<double> _backRotation;
  bool _isCardFlipped = false;
  
  String _selectedCategory = 'Spicy';
  final List<String> _categories = ['Spicy', 'Deep', 'Funny', 'Campus Life'];
  
  final Map<String, List<String>> _questions = {
    'Spicy': ['What is your biggest turn on?', 'Have you ever sent a risky text to the wrong person?', 'What is your wildest fantasy?'],
    'Deep': ['What is your biggest fear?', 'Who do you miss the most right now?', 'What is the biggest lie you have ever told?'],
    'Funny': ['What is the most embarrassing thing you have done while drunk?', 'What is your worst habit?'],
    'Campus Life': ['Have you ever skipped a final exam?', 'Which professor do you hate the most?', 'Have you ever sneaked someone into the dorms?']
  };

  String _currentQuestion = 'Tap the card to draw...';
  int _myDrinks = 0;
  int _opponentDrinks = 0;
  bool _isMyTurn = true;

  String get currentUid => FirebaseAuth.instance.currentUser?.uid ?? 'guest';

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _frontRotation = Tween<double>(begin: 0.0, end: -math.pi / 2).animate(CurvedAnimation(parent: _flipController, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)));
    _backRotation = Tween<double>(begin: math.pi / 2, end: 0.0).animate(CurvedAnimation(parent: _flipController, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));

    if (widget.gameSessionId != null) {
      _listenToGameSession();
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }
  
  void _listenToGameSession() {
    FirebaseFirestore.instance.collection('game_sessions').doc(widget.gameSessionId).snapshots().listen((doc) {
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _currentQuestion = data['currentQuestion'] ?? 'Tap to draw...';
          _isMyTurn = data['currentTurnUid'] == currentUid;
          if (data['player1Uid'] == currentUid) {
            _myDrinks = data['player1Drinks'] ?? 0;
            _opponentDrinks = data['player2Drinks'] ?? 0;
          } else {
            _myDrinks = data['player2Drinks'] ?? 0;
            _opponentDrinks = data['player1Drinks'] ?? 0;
          }
          if (data['isFlipped'] == true && !_isCardFlipped) {
            _isCardFlipped = true;
            _flipController.forward();
          }
        });
      }
    });
  }

  void _drawCard() {
    if (widget.gameSessionId != null && !_isMyTurn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('It is not your turn!')));
      return;
    }

    final qList = _questions[_selectedCategory]!;
    final nextQ = qList[math.Random().nextInt(qList.length)];
    
    if (widget.gameSessionId != null) {
      FirebaseFirestore.instance.collection('game_sessions').doc(widget.gameSessionId).update({
        'currentQuestion': nextQ,
        'isFlipped': true,
      });
    } else {
      // Solo Practice Mode
      setState(() {
        _currentQuestion = nextQ;
        _isCardFlipped = true;
      });
      _flipController.forward();
    }
  }

  void _takeDrink() {
    if (!_isCardFlipped) return;
    
    // Play drink animation
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) {
        Future.delayed(const Duration(seconds: 1), () => Navigator.pop(context));
        return const Center(child: Text('🍻 GLUG GLUG!', style: TextStyle(color: Colors.orangeAccent, fontSize: 40, fontWeight: FontWeight.bold)));
      }
    );

    if (widget.gameSessionId != null) {
      final isP1 = widget.gameSessionId!.startsWith(currentUid); // simplified check
      FirebaseFirestore.instance.collection('game_sessions').doc(widget.gameSessionId).update({
        isP1 ? 'player1Drinks' : 'player2Drinks': FieldValue.increment(1),
        'currentTurnUid': widget.opponentUid, // swap turn
        'isFlipped': false,
        'currentQuestion': 'Tap to draw...',
      });
    } else {
      setState(() {
        _myDrinks++;
        _isCardFlipped = false;
        _currentQuestion = 'Tap the card to draw...';
      });
      _flipController.reverse();
    }
  }

  void _answerTruth() {
    if (!_isCardFlipped) return;
    
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Spill your truth...', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(filled: true, fillColor: Colors.black26),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            onPressed: () {
              Navigator.pop(context);
              
              if (widget.gameSessionId != null) {
                // Send answer to opponent (mocked via chat)
                FirebaseFirestore.instance.collection('game_sessions').doc(widget.gameSessionId).update({
                  'currentTurnUid': widget.opponentUid, // swap turn
                  'isFlipped': false,
                  'currentQuestion': 'Tap to draw...',
                  'lastAnswer': controller.text,
                });
              } else {
                setState(() {
                  _isCardFlipped = false;
                  _currentQuestion = 'Tap the card to draw...';
                });
                _flipController.reverse();
              }
            },
            child: const Text('Send Answer', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  void _inviteMatch() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invitation sent to your matches list!')));
    // Real implementation would send a specific message type in chat.
  }

  void _addCommunityQuestion() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Submit a Question', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Your spicy question...', hintStyle: TextStyle(color: Colors.white38), filled: true, fillColor: Colors.black26),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Question submitted to community pool!')));
            },
            child: const Text('Submit', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  void _quitGame() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: const Text('Game Over 🏁', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Post-Game Summary', style: TextStyle(color: Colors.orangeAccent, fontSize: 18)),
            const SizedBox(height: 16),
            Text('You drank: $_myDrinks times', style: const TextStyle(color: Colors.white)),
            if (widget.opponentUid != null) Text('Opponent drank: $_opponentDrinks times', style: const TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          ElevatedButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent), child: const Text('Exit Game', style: TextStyle(color: Colors.black)))
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Truth or Drink 🎲', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (widget.opponentUid == null) IconButton(icon: const Icon(Icons.person_add, color: Colors.orangeAccent), onPressed: _inviteMatch, tooltip: 'Invite a Match'),
          IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.white54), onPressed: _addCommunityQuestion, tooltip: 'Submit Question'),
        ],
      ),
      body: Column(
        children: [
          // Scoreboard & Turn Indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildScoreBadge('You', _myDrinks, true),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: _isMyTurn ? Colors.orangeAccent.withOpacity(0.2) : Colors.white10, borderRadius: BorderRadius.circular(20)),
                  child: Text(_isMyTurn ? 'YOUR TURN' : 'OPPONENT TURN', style: TextStyle(color: _isMyTurn ? Colors.orangeAccent : Colors.white54, fontWeight: FontWeight.bold)),
                ),
                if (widget.opponentUid != null) _buildScoreBadge('Them', _opponentDrinks, false),
              ],
            ),
          ),
          
          // Category Selector
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _categories.length,
              itemBuilder: (context, i) {
                final c = _categories[i];
                final isSel = c == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c, style: TextStyle(color: isSel ? Colors.black : Colors.white)),
                    selected: isSel,
                    selectedColor: Colors.orangeAccent,
                    backgroundColor: Colors.black26,
                    onSelected: (val) => setState(() => _selectedCategory = c),
                  ),
                );
              },
            ),
          ),
          
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: _isCardFlipped ? null : _drawCard,
                child: AnimatedBuilder(
                  animation: _flipController,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_flipController.value <= 0.5)
                          Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(_frontRotation.value),
                            child: _buildCardBack(),
                          )
                        else
                          Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(_backRotation.value),
                            child: _buildCardFront(),
                          ),
                      ],
                    );
                  }
                ),
              ),
            ),
          ),
          
          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(side: BorderSide(color: _isCardFlipped && _isMyTurn ? Colors.redAccent : Colors.grey)),
                    onPressed: _isCardFlipped && _isMyTurn ? _takeDrink : null,
                    icon: const Icon(Icons.local_bar, color: Colors.redAccent),
                    label: const Text('Drink', style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: _isCardFlipped && _isMyTurn ? Colors.orangeAccent : Colors.grey.withOpacity(0.5)),
                    onPressed: _isCardFlipped && _isMyTurn ? _answerTruth : null,
                    icon: const Icon(Icons.check_circle, color: Colors.black),
                    label: const Text('Truth', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          
          TextButton(onPressed: _quitGame, child: const Text('End Game', style: TextStyle(color: Colors.white54))),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildScoreBadge(String name, int drinks, bool isMe) {
    return Column(
      children: [
        Text(name, style: TextStyle(color: isMe ? Colors.white : Colors.white70, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.local_bar, color: Colors.orangeAccent, size: 14),
              const SizedBox(width: 4),
              Text('$drinks', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildCardBack() {
    return Container(
      width: 280,
      height: 400,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFE65100), Color(0xFFBF360C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 20, spreadRadius: 5, offset: Offset(0, 10))],
        border: Border.all(color: Colors.orangeAccent, width: 2),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.liquor, color: Colors.white, size: 80),
            SizedBox(height: 16),
            Text('Truth or Drink', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'serif')),
            SizedBox(height: 40),
            Text('TAP TO DRAW', style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 2)),
          ],
        ),
      ),
    );
  }

  Widget _buildCardFront() {
    return Container(
      width: 280,
      height: 400,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 20, spreadRadius: 5, offset: Offset(0, 10))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_selectedCategory.toUpperCase(), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const Icon(Icons.local_fire_department, color: Colors.redAccent),
              ],
            ),
            const Expanded(child: SizedBox()),
            Text(_currentQuestion, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87, fontSize: 22, fontWeight: FontWeight.w600, height: 1.4)),
            const Expanded(child: SizedBox()),
            const Text('Will you answer or drink?', style: TextStyle(color: Colors.black54, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }
}
