import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);
const Color _neonPurple = Color(0xFF9C27B0);

class FlashcardsView extends StatefulWidget {
  const FlashcardsView({super.key});

  @override
  State<FlashcardsView> createState() => _FlashcardsViewState();
}

class _FlashcardsViewState extends State<FlashcardsView> with SingleTickerProviderStateMixin {
  final String _studentId = FirebaseAuth.instance.currentUser?.uid ?? "demo_student";
  List<dynamic> _allCards = [];
  List<dynamic> _filteredCards = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isReversed = false;
  int _currentStreak = 0;
  String _selectedCategory = 'All';

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
    _fetchStreak();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchStreak() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_studentId).get();
      if (doc.exists) {
        setState(() {
          _currentStreak = doc.data()?['flashcardStreak'] ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchCards() async {
    setState(() { _isLoading = true; });
    try {
      final response = await http.get(
        Uri.parse('https://swapeatbackend.vercel.app/api/v3/academic/flashcards?student_id=$_studentId'),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final cards = data['flashcards'] as List? ?? [];
        if (cards.isNotEmpty) {
          setState(() {
            _allCards = cards;
            _filterCards();
          });
          return; // backend worked — done
        }
      }
    } catch (_) {
      // Backend failed — fall through to Firestore
    }

    // Fallback: fetch from Firestore 'flashcards' collection
    try {
      final snap = await FirebaseFirestore.instance
          .collection('flashcards')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();
      setState(() {
        _allCards = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _filterCards();
      });
    } catch (e) {
      // Firestore also failed — show empty state gracefully
      setState(() {
        _allCards = [];
        _filteredCards = [];
      });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  void _filterCards() {
    if (_selectedCategory == 'All') {
      _filteredCards = List.from(_allCards);
    } else {
      _filteredCards = _allCards.where((c) => c['unitCode'] == _selectedCategory).toList();
    }
    _currentIndex = 0;
    _isReversed = false;
    _animationController.reset();
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
    final currentCard = _filteredCards[_currentIndex];
    
    // Optimistically move to next card
    setState(() {
      _isReversed = false;
      _animationController.reset();
      if (_currentIndex < _filteredCards.length - 1) {
        _currentIndex++;
      } else {
        // Done with deck
        _filteredCards = [];
      }
    });

    try {
      final response = await http.post(
        Uri.parse('https://swapeatbackend.vercel.app/api/v3/academic/flashcards/review'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'studentId': _studentId,
          'cardId': currentCard['id'],
          'quality': quality,
        })
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (resData['streak'] != null && mounted) {
          setState(() {
            _currentStreak = resData['streak'];
          });
        }
      }
    } catch (e) {
      print("Review submission failed: $e");
    }
  }

  Future<void> _shareToMatch(Map<String, dynamic> card) async {
    // Show a dialog with recent chats
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _cardColor,
          title: const Text('Share to Match', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('chats').where('participants', arrayContains: _studentId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.docs.isEmpty) return const Text('No active chats found.', style: TextStyle(color: Colors.white70));
                
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, idx) {
                    final chatDoc = snapshot.data!.docs[idx];
                    return ListTile(
                      leading: const Icon(Icons.person, color: _neonPink),
                      title: Text('Chat: ${chatDoc.id.substring(0, 8)}...', style: const TextStyle(color: Colors.white)),
                      onTap: () async {
                        await FirebaseFirestore.instance.collection('chats').doc(chatDoc.id).collection('messages').add({
                          'type': 'flashcard',
                          'question': card['question'],
                          'answer': card['answer'],
                          'senderId': _studentId,
                          'timestamp': FieldValue.serverTimestamp(),
                          'isRead': false,
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Flashcard Sent! 💌'), backgroundColor: _neonPink));
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      }
    );
  }

  void _addCustomCard() {
    final qController = TextEditingController();
    final aController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Create Flashcard', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: qController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Question', labelStyle: TextStyle(color: _textSecondary))),
            TextField(controller: aController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Answer', labelStyle: TextStyle(color: _textSecondary))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonCyan),
            onPressed: () async {
              if (qController.text.isNotEmpty && aController.text.isNotEmpty) {
                await http.post(
                  Uri.parse('https://swapeatbackend.vercel.app/api/v3/academic/flashcards'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'studentId': _studentId,
                    'unitCode': 'Custom',
                    'front': qController.text,
                    'back': aController.text,
                  })
                );
                Navigator.pop(context);
                _fetchCards();
              }
            }, 
            child: const Text('SAVE')
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    // Unique categories from available cards
    final Set<String> categories = {'All'};
    for (var c in _allCards) {
      if (c['unitCode'] != null) categories.add(c['unitCode']);
    }

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Daily Flashcards', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                  const SizedBox(width: 4),
                  Text('$_currentStreak', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.add, color: _neonCyan), onPressed: _addCustomCard, tooltip: 'Add Custom Card'),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: _neonPink))
        : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Filter
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(cat, style: TextStyle(color: isSelected ? Colors.white : _textSecondary)),
                      selected: isSelected,
                      selectedColor: _neonPurple,
                      backgroundColor: _surfaceLight,
                      onSelected: (val) {
                        if (val) setState(() { _selectedCategory = cat; _filterCards(); });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Deck: $_selectedCategory', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('${_filteredCards.length - _currentIndex} to review', style: const TextStyle(color: _neonPink, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 32),
            Expanded(
              child: _filteredCards.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                                color: const Color(0xFF1A2235),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: const Color(0xFF05D5AA)
                                          .withOpacity(0.2),
                                      blurRadius: 30)
                                ]),
                            child: const Icon(Icons.style,
                                size: 56, color: Color(0xFF05D5AA)),
                          ),
                          const SizedBox(height: 20),
                          const Text('No Flashcards for now',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text(
                              'Your flashcards will appear here.\nAsk your lecturer or create your own!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Color(0xFF8B9BB4), fontSize: 14)),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _fetchCards,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF05D5AA)),
                            icon: const Icon(Icons.refresh,
                                color: Colors.black),
                            label: const Text('Refresh',
                                style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    )
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
                                ? _buildCardFace(_filteredCards[_currentIndex]['question'] ?? _filteredCards[_currentIndex]['front'] ?? '', false, _filteredCards[_currentIndex]) 
                                : Transform(
                                    transform: Matrix4.identity()..rotateY(pi),
                                    alignment: Alignment.center,
                                    child: _buildCardFace(_filteredCards[_currentIndex]['answer'] ?? _filteredCards[_currentIndex]['back'] ?? '', true, _filteredCards[_currentIndex])
                                  ),
                          );
                        }
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            Center(child: Text(_isReversed ? 'How well did you know this?' : 'Tap card to reveal answer', style: const TextStyle(color: _textSecondary))),
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

  Widget _buildCardFace(String text, bool isAnswer, Map<String, dynamic> card) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isAnswer ? _neonCyan.withOpacity(0.5) : Colors.purpleAccent.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(color: isAnswer ? _neonCyan.withOpacity(0.1) : Colors.purpleAccent.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)
        ]
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.send, color: _neonPink),
              tooltip: 'Send to Match',
              onPressed: () => _shareToMatch(card),
            )
          )
        ],
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
      onPressed: _isReversed ? onPressed : null,
      child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}
