import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
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

class _MatchShotInTheDarkViewState extends State<MatchShotInTheDarkView> with SingleTickerProviderStateMixin {
  String _status = 'idle'; // idle, queuing, chatting, revealed
  String? _sessionId;
  StreamSubscription? _sessionSubscription;
  
  final TextEditingController _msgController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  Timer? _timer;
  int _timeLeft = 180; // 3 minutes
  
  bool _isOpponentTyping = false;
  double _blurAmount = 15.0; // Starts at 15.0 blur
  int _messagesSent = 0;

  final List<String> _icebreakers = [
    'What is your biggest hot take?',
    'What song have you had on repeat lately?',
    'If you had to eat one meal for the rest of your life, what is it?',
    'What is the most embarrassing thing you did as a freshman?',
  ];

  late AnimationController _smokeController;

  String get currentUid => FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  String get currentGender => widget.userModel?['gender'] ?? '';

  @override
  void initState() {
    super.initState();
    _smokeController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _timer?.cancel();
    _msgController.dispose();
    _smokeController.dispose();
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
        final matchDoc = potentialMatches.docs.first;
        final sessionId = 'blind_${DateTime.now().millisecondsSinceEpoch}';
        
        await FirebaseFirestore.instance.collection('blind_chat_sessions').doc(sessionId).set({
          'users': [currentUid, matchDoc.id],
          'status': 'active',
          'revealVotes': [],
          'extendVotes': [],
          'createdAt': FieldValue.serverTimestamp(),
          '${currentUid}_typing': false,
          '${matchDoc.id}_typing': false,
        });
        
        await matchDoc.reference.update({'status': 'matched', 'session_id': sessionId});
        await queueRef.doc(currentUid).set({'status': 'matched', 'session_id': sessionId, 'gender': currentGender});
        
        setState(() => _sessionId = sessionId);
        _startChat();
      } else {
        await queueRef.doc(currentUid).set({
          'gender': currentGender,
          'status': 'waiting',
          'timestamp': FieldValue.serverTimestamp(),
        });
        _listenForQueueMatch();
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'idle');
    }
  }

  void _listenForQueueMatch() {
    FirebaseFirestore.instance.collection('blind_chat_queue').doc(currentUid).snapshots().listen((doc) {
      if (doc.exists && doc.data()?['status'] == 'matched') {
        setState(() => _sessionId = doc.data()?['session_id']);
        _startChat();
      }
    });
  }

  void _startChat() {
    setState(() {
      _status = 'chatting';
      _timeLeft = 180;
      _blurAmount = 15.0;
      _messagesSent = 0;
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
      if (doc.exists && mounted) {
        final data = doc.data()!;
        if (data['status'] == 'revealed') setState(() => _status = 'revealed');
        if (data['status'] == 'bailed') _handleBail();
        
        // Typing indicator
        final opponentUid = data['users'].firstWhere((u) => u != currentUid, orElse: () => '');
        if (opponentUid.isNotEmpty) {
          setState(() => _isOpponentTyping = data['${opponentUid}_typing'] == true);
        }
      }
    });
    
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
            _messagesSent = _messages.where((m) => m['sender_id'] == currentUid).length;
            // Unblur profile logic (1.5 blur reduction per message, max 10 messages to clear)
            _blurAmount = math.max(0.0, 15.0 - (_messagesSent * 1.5));
          });
        }
    });
  }

  Future<void> _sendMessage() async {
    if (_msgController.text.trim().isEmpty) return;
    final text = _msgController.text.trim();
    _msgController.clear();
    
    // Reset typing
    _updateTypingStatus(false);
    
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

  void _updateTypingStatus(bool isTyping) {
    if (_sessionId != null) {
      FirebaseFirestore.instance.collection('blind_chat_sessions').doc(_sessionId).update({
        '${currentUid}_typing': isTyping
      });
    }
  }

  Future<void> _voteReveal() async {
    if (_sessionId == null) return;
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
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voted to reveal! Waiting for partner...')));
  }

  Future<void> _extendTime() async {
    if (_sessionId == null) return;
    final docRef = FirebaseFirestore.instance.collection('blind_chat_sessions').doc(_sessionId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      final data = snapshot.data()!;
      List<dynamic> votes = data['extendVotes'] ?? [];
      if (!votes.contains(currentUid)) {
        votes.add(currentUid);
        if (votes.length >= 2) {
           transaction.update(docRef, {'extendVotes': []}); // Reset for future extends
           if (mounted) setState(() => _timeLeft += 60); // Add 60s locally
        } else {
           transaction.update(docRef, {'extendVotes': votes});
        }
      }
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Requested +1 minute! Waiting for partner...')));
  }

  void _sendIcebreaker() {
    final q = _icebreakers[math.Random().nextInt(_icebreakers.length)];
    _msgController.text = q;
  }

  void _bail() {
    if (_sessionId != null) {
      FirebaseFirestore.instance.collection('blind_chat_sessions').doc(_sessionId).update({'status': 'bailed'});
    }
    _handleBail();
  }
  
  void _handleBail() {
    _timer?.cancel();
    _smokeController.forward().then((_) {
      if (mounted) {
        setState(() => _status = 'idle');
        _smokeController.reset();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat ended abruptly. 💨')));
      }
    });
  }

  void _showRatingModal() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: const Text('Rate Conversation', style: TextStyle(color: Colors.white)),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(icon: const Icon(Icons.thumb_down, color: Colors.redAccent, size: 40), onPressed: () { Navigator.pop(context); Navigator.pop(context); }),
            IconButton(icon: const Icon(Icons.thumb_up, color: Colors.greenAccent, size: 40), onPressed: () { Navigator.pop(context); Navigator.pop(context); }),
          ],
        ),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Shot in the Dark 🎯', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_status == 'chatting')
            IconButton(icon: const Icon(Icons.exit_to_app, color: Colors.redAccent), onPressed: _bail, tooltip: 'Bail (Smoke Bomb)'),
        ],
      ),
      body: Stack(
        children: [
          _buildBody(),
          
          // Smoke Bomb Animation Overlay
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _smokeController,
              builder: (context, child) {
                if (_smokeController.value == 0) return const SizedBox();
                return Container(
                  color: Colors.grey.shade900.withOpacity(_smokeController.value),
                  child: Center(
                    child: Icon(Icons.cloud, color: Colors.white.withOpacity(_smokeController.value), size: 100 * (1 + _smokeController.value)),
                  ),
                );
              }
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case 'idle': return _buildIdleView();
      case 'queuing': return _buildQueuingView();
      case 'chatting': return _buildChatView();
      case 'revealed': return _buildRevealedView();
      default: return const SizedBox();
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
              'You have 3 minutes to chat blindly. Talk more to unblur their photo! When time runs out, vote to Reveal or Run.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: _joinQueue,
                child: const Text('ENTER BLIND CHAT', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined Anime theme queue!')));
              },
              icon: const Icon(Icons.tag, color: _neonCyan),
              label: const Text('Theme Queue: Anime', style: TextStyle(color: _neonCyan)),
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
    final bool isLowTime = _timeLeft <= 10;
    
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: isLowTime ? Colors.redAccent.withOpacity(0.2) : Colors.black26,
          child: Row(
            children: [
              ClipOval(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: _blurAmount, sigmaY: _blurAmount),
                  child: Container(
                    width: 50, height: 50,
                    decoration: const BoxDecoration(
                      color: Colors.grey,
                      image: DecorationImage(image: NetworkImage('https://images.unsplash.com/photo-1524504388940-b1c1722653e1?ixlib=rb-4.0.3&auto=format&fit=crop&w=300&q=80'), fit: BoxFit.cover)
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mystery Comrade', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  if (_isOpponentTyping) const Text('typing...', style: TextStyle(color: _neonCyan, fontSize: 12, fontStyle: FontStyle.italic)),
                ],
              ),
              const Spacer(),
              Text('$minutes:$seconds', style: TextStyle(color: isLowTime ? Colors.redAccent : _neonCyan, fontSize: 24, fontWeight: FontWeight.bold)),
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
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe ? _neonCyan.withOpacity(0.2) : Colors.white12,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(msg['text'] ?? '', style: const TextStyle(color: Colors.white)),
                    ),
                    if (isMe) const Text('Seen', style: TextStyle(color: Colors.white38, fontSize: 10)),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        ),
        
        if (_timeLeft == 0)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
              children: [
                const Text('TIME IS UP!', style: TextStyle(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: _bail, style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)), child: const Text('RUN', style: TextStyle(color: Colors.redAccent)))),
                    const SizedBox(width: 16),
                    Expanded(child: ElevatedButton(onPressed: _voteReveal, style: ElevatedButton.styleFrom(backgroundColor: _neonCyan), child: const Text('REVEAL', style: TextStyle(color: Colors.white)))),
                  ],
                )
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black26,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(onPressed: _sendIcebreaker, icon: const Icon(Icons.ac_unit, color: Colors.white54, size: 16), label: const Text('Icebreaker', style: TextStyle(color: Colors.white54))),
                    TextButton.icon(onPressed: _extendTime, icon: const Icon(Icons.timer_add, color: _neonCyan, size: 16), label: const Text('+1 Min', style: TextStyle(color: _neonCyan))),
                    IconButton(icon: const Icon(Icons.mic, color: _neonPink), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recording Distorted Voice Note... 👹')))),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        style: const TextStyle(color: Colors.white),
                        onChanged: (v) => _updateTypingStatus(v.isNotEmpty),
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
            onPressed: _showRatingModal,
            style: ElevatedButton.styleFrom(backgroundColor: _neonPink),
            child: const Text('Rate Chat & Exit', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}
