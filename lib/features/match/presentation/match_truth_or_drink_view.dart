import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  String _cardType = 'TRUTH'; // 'TRUTH' or 'DARE'
  
  final Map<String, List<String>> _questions = {
    'Spicy': [
      'What is your biggest romantic turn on?',
      'Have you ever sent a risky text to the wrong person?',
      'What is your wildest campus fantasy?',
      'Who was your first campus crush and do they know?',
      'What is the smoothest pickup line someone used on you?',
    ],
    'Deep': [
      'What is your biggest fear after graduating?',
      'Who do you miss the most right now?',
      'What is the biggest lie you have told your parents about campus life?',
      'What is one insecurity you wish you could overcome?',
      'Have you ever felt truly in love, and how did it end?',
    ],
    'Funny': [
      'What is the most embarrassing thing you have done while drunk?',
      'What is your weirdest campus habit?',
      'What is the most awkward date you have ever been on?',
      'What is the cheapest thing you did to save money in campus?',
    ],
    'Campus Life': [
      'Have you ever skipped an exam or submitted an empty paper?',
      'Which campus lecturer do you find the most intimidating?',
      'Have you ever sneaked someone into the hostels past curfew?',
      'What is the worst meal you ever ate at the university mess?',
    ]
  };

  final Map<String, List<String>> _dares = {
    'Spicy': [
      'Send a 5-second voice note saying something sweet in your best radio voice.',
      'Text your recent crush: "I had a dream about you last night" and show screenshot.',
      'Do your best catwalk across the room right now.',
      'Show the last 3 photos in your phone gallery without hiding anything.',
    ],
    'Deep': [
      'Call a close friend on speakerphone and tell them you appreciate them.',
      'Confess the one thing you regret doing in university so far.',
      'Tell your opponent the very first thing you noticed about their profile.',
      'Read aloud the last draft message you wrote but never sent.',
    ],
    'Funny': [
      'Speak in an exaggerated Kenyan accent for the next 2 rounds.',
      'Do 15 quick pushups or 20 jumping jacks right now.',
      'Sing the chorus of your favorite Kenyan song in an opera voice.',
      'Send a hilarious meme that describes your dating life right now.',
    ],
    'Campus Life': [
      'Imitate your strictest lecturer for 30 seconds.',
      'Show your current DISHI wallet or M-PESA balance to your opponent.',
      'Text your roommate asking them to bring you water right now.',
      'Name 3 campus hangout spots and rank them honestly.',
    ]
  };

  String _currentQuestion = 'Tap the card to draw...';
  int _myDrinks = 0;
  int _opponentDrinks = 0;
  int _myPoints = 0;
  int _opponentPoints = 0;
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
          _cardType = data['cardType'] ?? 'TRUTH';
          _isMyTurn = data['currentTurnUid'] == currentUid;
          if (data['player1Uid'] == currentUid) {
            _myDrinks = data['player1Drinks'] ?? 0;
            _opponentDrinks = data['player2Drinks'] ?? 0;
            _myPoints = data['player1Points'] ?? 0;
            _opponentPoints = data['player2Points'] ?? 0;
          } else {
            _myDrinks = data['player2Drinks'] ?? 0;
            _opponentDrinks = data['player1Drinks'] ?? 0;
            _myPoints = data['player2Points'] ?? 0;
            _opponentPoints = data['player1Points'] ?? 0;
          }
          if (data['isFlipped'] == true && !_isCardFlipped) {
            _isCardFlipped = true;
            _flipController.forward();
          } else if (data['isFlipped'] == false && _isCardFlipped) {
            _isCardFlipped = false;
            _flipController.reverse();
          }
        });
      }
    });
  }

  void _drawCard([String? forcedType]) {
    if (widget.gameSessionId != null && !_isMyTurn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('It is not your turn! Wait for your opponent.')));
      return;
    }

    final type = forcedType ?? (math.Random().nextBool() ? 'TRUTH' : 'DARE');
    final list = type == 'DARE' ? _dares[_selectedCategory]! : _questions[_selectedCategory]!;
    final nextText = list[math.Random().nextInt(list.length)];
    
    if (widget.gameSessionId != null) {
      FirebaseFirestore.instance.collection('game_sessions').doc(widget.gameSessionId).set({
        'currentQuestion': nextText,
        'cardType': type,
        'isFlipped': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      // Solo Practice Mode
      setState(() {
        _cardType = type;
        _currentQuestion = nextText;
        _isCardFlipped = true;
      });
      _flipController.forward();
    }
  }

  void _completeDare() {
    if (!_isCardFlipped) return;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted && Navigator.canPop(context)) Navigator.pop(context);
        });
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.greenAccent, size: 80),
              SizedBox(height: 16),
              Text('🔥 DARE COMPLETED!', style: TextStyle(color: Colors.greenAccent, fontSize: 32, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('+10 Points to you!', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
        );
      }
    );

    if (widget.gameSessionId != null) {
      FirebaseFirestore.instance.collection('game_sessions').doc(widget.gameSessionId).get().then((doc) {
        if (!doc.exists) return;
        final data = doc.data() as Map<String, dynamic>;
        final isP1 = data['player1Uid'] == currentUid;
        final nextTurn = isP1 ? data['player2Uid'] : data['player1Uid'];

        FirebaseFirestore.instance.collection('game_sessions').doc(widget.gameSessionId).update({
          isP1 ? 'player1Points' : 'player2Points': FieldValue.increment(10),
          'currentTurnUid': nextTurn,
          'isFlipped': false,
          'currentQuestion': 'Tap to draw...',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } else {
      setState(() {
        _myPoints += 10;
        _isCardFlipped = false;
        _currentQuestion = 'Tap the card to draw...';
      });
      _flipController.reverse();
    }
  }

  void _takeDrink() {
    if (!_isCardFlipped) return;
    
    // Play drink animation
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted && Navigator.canPop(context)) Navigator.pop(context);
        });
        return const Center(child: Text('🍻 GLUG GLUG!', style: TextStyle(color: Colors.orangeAccent, fontSize: 40, fontWeight: FontWeight.bold)));
      }
    );

    if (widget.gameSessionId != null) {
      FirebaseFirestore.instance.collection('game_sessions').doc(widget.gameSessionId).get().then((doc) {
        if (!doc.exists) return;
        final data = doc.data() as Map<String, dynamic>;
        final isP1 = data['player1Uid'] == currentUid;
        final nextTurn = isP1 ? data['player2Uid'] : data['player1Uid'];

        FirebaseFirestore.instance.collection('game_sessions').doc(widget.gameSessionId).update({
          isP1 ? 'player1Drinks' : 'player2Drinks': FieldValue.increment(1),
          'currentTurnUid': nextTurn,
          'isFlipped': false,
          'currentQuestion': 'Tap to draw...',
          'updatedAt': FieldValue.serverTimestamp(),
        });
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
        title: const Text('Spill your truth 💬', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Type your honest confession here...',
            hintStyle: TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.black26,
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            onPressed: () {
              Navigator.pop(context);
              
              if (widget.gameSessionId != null) {
                FirebaseFirestore.instance.collection('game_sessions').doc(widget.gameSessionId).get().then((doc) {
                  if (!doc.exists) return;
                  final data = doc.data() as Map<String, dynamic>;
                  final isP1 = data['player1Uid'] == currentUid;
                  final nextTurn = isP1 ? data['player2Uid'] : data['player1Uid'];

                  FirebaseFirestore.instance.collection('game_sessions').doc(widget.gameSessionId).update({
                    isP1 ? 'player1Points' : 'player2Points': FieldValue.increment(5),
                    'currentTurnUid': nextTurn,
                    'isFlipped': false,
                    'currentQuestion': 'Tap to draw...',
                    'lastAnswer': controller.text.trim(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                });
              } else {
                setState(() {
                  _myPoints += 5;
                  _isCardFlipped = false;
                  _currentQuestion = 'Tap the card to draw...';
                });
                _flipController.reverse();
              }
            },
            child: const Text('Send Truth (+5 pts)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      )
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
        title: const Text('Truth or Dare 🎲', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                _buildScoreBadge('You', _myDrinks, _myPoints, true),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: _isMyTurn ? Colors.orangeAccent.withOpacity(0.2) : Colors.white10, borderRadius: BorderRadius.circular(20)),
                  child: Text(_isMyTurn ? 'YOUR TURN' : 'OPPONENT TURN', style: TextStyle(color: _isMyTurn ? Colors.orangeAccent : Colors.white54, fontWeight: FontWeight.bold)),
                ),
                if (widget.opponentUid != null) _buildScoreBadge('Them', _opponentDrinks, _opponentPoints, false),
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
                onTap: _isCardFlipped ? null : () => _drawCard(),
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: !_isCardFlipped
                ? Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurpleAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _isMyTurn ? () => _drawCard('TRUTH') : null,
                          icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                          label: const Text('Truth', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _isMyTurn ? () => _drawCard('DARE') : null,
                          icon: const Icon(Icons.local_fire_department, color: Colors.white),
                          label: const Text('Dare', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _isMyTurn ? Colors.orangeAccent : Colors.grey),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _isMyTurn ? _takeDrink : null,
                          icon: const Icon(Icons.local_bar, color: Colors.orangeAccent),
                          label: const Text('Drink / Pass', style: TextStyle(color: Colors.orangeAccent, fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _cardType == 'DARE' ? Colors.green : Colors.deepPurpleAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _isMyTurn
                              ? (_cardType == 'DARE' ? _completeDare : _answerTruth)
                              : null,
                          icon: Icon(_cardType == 'DARE' ? Icons.check_circle : Icons.send, color: Colors.white),
                          label: Text(
                            _cardType == 'DARE' ? 'Done! (+10)' : 'Answer (+5)',
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
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

  Widget _buildScoreBadge(String name, int drinks, int points, bool isMe) {
    return Column(
      children: [
        Text(name, style: TextStyle(color: isMe ? Colors.white : Colors.white70, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.orangeAccent, size: 13),
                  const SizedBox(width: 3),
                  Text('$points pts', style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.local_bar, color: Colors.redAccent, size: 13),
                  const SizedBox(width: 3),
                  Text('$drinks', style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildCardBack() {
    return Container(
      width: 280,
      height: 400,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE65100), Color(0xFF6A1B9A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 20, spreadRadius: 5, offset: Offset(0, 10))],
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.5), width: 2),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.casino, color: Colors.white, size: 70),
            SizedBox(height: 16),
            Text('Truth or Dare', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'serif')),
            SizedBox(height: 8),
            Text('TRUTH • DARE • DRINK', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w600)),
            SizedBox(height: 36),
            Text('TAP OR CHOOSE BELOW', style: TextStyle(color: Colors.white60, fontSize: 12, letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildCardFront() {
    final isDare = _cardType == 'DARE';
    return Container(
      width: 280,
      height: 400,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 20, spreadRadius: 5, offset: Offset(0, 10))],
        border: Border.all(color: isDare ? Colors.redAccent : Colors.deepPurpleAccent, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDare ? Colors.redAccent : Colors.deepPurpleAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(isDare ? Icons.local_fire_department : Icons.record_voice_over, color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  isDare ? 'DARE (+10 PTS)' : 'TRUTH (+5 PTS)',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _selectedCategory.toUpperCase(),
                              style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _currentQuestion,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w600, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        isDare ? 'Perform the dare or drink!' : 'Confess your truth or drink!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54, fontStyle: FontStyle.italic, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
