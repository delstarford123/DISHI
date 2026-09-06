import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/glass_card.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonPink = Color(0xFFFF2A6D);

class MatchShotInTheDarkView extends StatefulWidget {
  final Map<String, dynamic>? userModel;
  
  const MatchShotInTheDarkView({super.key, this.userModel});

  @override
  State<MatchShotInTheDarkView> createState() => _MatchShotInTheDarkViewState();
}

class _MatchShotInTheDarkViewState extends State<MatchShotInTheDarkView> {
  String _status = 'idle'; // idle, queuing, chatting, revealed
  String? _sessionId;
  StreamSubscription? _sessionSubscription;
  
  final TextEditingController _msgController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  Timer? _timer;
  int _timeLeft = 180; // 3 minutes

  String get currentUid => FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  String get currentGender => widget.userModel?['gender'] ?? '';

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _timer?.cancel();
    _msgController.dispose();
    super.dispose();
  }

  Future<void> _joinQueue() async {
    if (currentGender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please set your gender in your profile first!')));
      return;
    }
    
    setState(() => _status = 'queuing');
    
    try {
      final oppositeGender = currentGender.toLowerCase() == 'male' ? 'female' : 'male';
      
      final queueRef = FirebaseFirestore.instance.collection('blind_chat_queue');
      final potentialMatches = await queueRef
          .where('gender', isEqualTo: oppositeGender)
          .where('status', isEqualTo: 'waiting')
          .limit(1)
          .get();

      if (potentialMatches.docs.isNotEmpty) {
        // Match found!
        final matchDoc = potentialMatches.docs.first;
        final sessionId = 'blind_${DateTime.now().millisecondsSinceEpoch}';
        
        // Create session
        await FirebaseFirestore.instance.collection('blind_chat_sessions').doc(sessionId).set({
          'users': [currentUid, matchDoc.id],
          'status': 'active',
          'revealVotes': [],
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        // Update both queue docs
        await matchDoc.reference.update({'status': 'matched', 'session_id': sessionId});
        await queueRef.doc(currentUid).set({'status': 'matched', 'session_id': sessionId, 'gender': currentGender});
        
        setState(() {
          _sessionId = sessionId;
        });
        _startChat();
      } else {
        // Wait in queue
        await queueRef.doc(currentUid).set({
          'gender': currentGender,
          'status': 'waiting',
          'timestamp': FieldValue.serverTimestamp(),
        });
        _listenForQueueMatch();
      }
    } catch (e) {
      debugPrint('Queue error: $e');
      if (mounted) setState(() => _status = 'idle');
    }
  }

  void _listenForQueueMatch() {
    FirebaseFirestore.instance.collection('blind_chat_queue').doc(currentUid).snapshots().listen((doc) {
      if (doc.exists && doc.data()?['status'] == 'matched') {
        setState(() {
          _sessionId = doc.data()?['session_id'];
        });
        _startChat();
      }
    });
  }

  void _startChat() {
    setState(() {
      _status = 'chatting';
      _timeLeft = 180;
    });
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        timer.cancel();
      }
    });

    _sessionSubscription = FirebaseFirestore.instance
        .collection('blind_chat_sessions')
        .doc(_sessionId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final data = doc.data()!;
        if (data['status'] == 'revealed') {
          setState(() => _status = 'revealed');
        }
      }
    });
    
    // Listen for messages
    FirebaseFirestore.instance
      .collection('blind_chat_sessions')
      .doc(_sessionId)
      .collection('messages')
      .orderBy('timestamp')
      .snapshots()
      .listen((snapshot) {
        if (mounted) {
          setState(() {
            _messages = snapshot.docs.map((d) => d.data()).toList();
          });
        }
    });
  }

  Future<void> _sendMessage() async {
    if (_msgController.text.trim().isEmpty) return;
    
    final text = _msgController.text.trim();
    _msgController.clear();
    
    await FirebaseFirestore.instance
      .collection('blind_chat_sessions')
      .doc(_sessionId)
      .collection('messages')
      .add({
        'sender_id': currentUid,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
  }

  Future<void> _voteReveal() async {
    if (_sessionId == null) return;
    try {
      final docRef = FirebaseFirestore.instance.collection('blind_chat_sessions').doc(_sessionId);
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;
        
        final data = snapshot.data()!;
        List<dynamic> votes = data['revealVotes'] ?? [];
        if (!votes.contains(currentUid)) {
          votes.add(currentUid);
          
          if (votes.length >= 2) {
             transaction.update(docRef, {'revealVotes': votes, 'status': 'revealed'});
          } else {
             transaction.update(docRef, {'revealVotes': votes});
          }
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voted to reveal! Waiting for partner...')));
      }
    } catch (e) {
      debugPrint('Reveal error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Shot in the Dark 🎯', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case 'idle':
        return _buildIdleView();
      case 'queuing':
        return _buildQueuingView();
      case 'chatting':
        return _buildChatView();
      case 'revealed':
        return _buildRevealedView();
      default:
        return const SizedBox();
    }
  }

  Widget _buildIdleView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.nightlight_round, color: _neonPink, size: 80),
            const SizedBox(height: 24),
            const Text('Shot in the Dark', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
              'You have 3 minutes to chat blindly. When time runs out, vote to Reveal or Run. Only opposite genders are matched.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: _joinQueue,
                child: const Text('ENTER BLIND CHAT', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildQueuingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          CircularProgressIndicator(color: _neonCyan),
          SizedBox(height: 24),
          Text('Searching for a match in the dark...', style: TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildChatView() {
    final String minutes = (_timeLeft ~/ 60).toString().padLeft(2, '0');
    final String seconds = (_timeLeft % 60).toString().padLeft(2, '0');
    
    return Column(
      children: [
        // Blurred Avatar Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.black26,
          child: Row(
            children: [
              ClipOval(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 50, height: 50,
                    color: Colors.grey,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Text('Mystery Comrade', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('$minutes:$seconds', style: TextStyle(color: _timeLeft <= 30 ? Colors.redAccent : _neonCyan, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              final isMe = msg['sender_id'] == currentUid;
              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? _neonCyan.withOpacity(0.2) : Colors.white12,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(msg['text'] ?? '', style: const TextStyle(color: Colors.white)),
                ),
              );
            },
          ),
        ),
        
        if (_timeLeft == 0)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const Text('TIME IS UP!', style: TextStyle(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                        child: const Text('RUN', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _voteReveal,
                        style: ElevatedButton.styleFrom(backgroundColor: _neonCyan),
                        child: const Text('REVEAL', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _neonCyan,
                  child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _sendMessage),
                )
              ],
            ),
          )
      ],
    );
  }

  Widget _buildRevealedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.celebration, color: Colors.amber, size: 80),
          const SizedBox(height: 24),
          const Text('IT\'S A MATCH! 🎉', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text('You both chose to reveal! Check your Match Inbox to see who they are.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: _neonPink),
            child: const Text('Return to Hub', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}
