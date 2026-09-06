import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'match_dishi_date_dialog.dart';
import 'match_call_view.dart' as match_call;

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonPurple = Color(0xFF9C27B0);
const Color _textSecondary = Color(0xFF8B9BB4);

class MatchChatView extends StatefulWidget {
  final String chatId;
  final String myUid;
  final String matchName;
  final String? matchAvatar;
  final String? matchId;
  
  const MatchChatView({
    super.key, 
    required this.chatId, 
    required this.myUid, 
    required this.matchName, 
    this.matchAvatar,
    this.matchId,
  });

  @override
  State<MatchChatView> createState() => _MatchChatViewState();
}

class _MatchChatViewState extends State<MatchChatView> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isWhisperMode = false;
  
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0, // Reversing list view
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_textController.text.trim().isEmpty) return;
    final text = _textController.text.trim();
    _textController.clear();

    if (_isWhisperMode) {
      _sendWhisper(text);
    } else {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'type': 'text',
        'text': text,
        'senderId': widget.myUid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendWhisper(String text) async {
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'type': 'whisper',
      'text': text,
      'senderId': widget.myUid,
      'timestamp': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(seconds: 10))),
    });
    _scrollToBottom();
  }

  Future<void> _sendIcebreaker() async {
    final gameData = {
      'truths': ['I have 3 dogs', 'I broke my leg in Paris'],
      'lie': 'I speak 4 languages'
    };
    
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'type': 'icebreaker',
      'gameData': gameData,
      'senderId': widget.myUid,
      'timestamp': FieldValue.serverTimestamp(),
    });
    _scrollToBottom();
  }

  void _openDishiDateDialog() async {
    final result = await showDialog(
      context: context, 
      builder: (context) => const MatchDishiDateDialog()
    );
    
    if (result != null) {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'type': 'dishi_date',
        'venue': result['venue'],
        'splitAmount': result['splitAmount'],
        'senderId': widget.myUid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: _surfaceLight,
              backgroundImage: (widget.matchAvatar != null && widget.matchAvatar!.isNotEmpty) ? NetworkImage(widget.matchAvatar!) : null,
              child: (widget.matchAvatar == null || widget.matchAvatar!.isEmpty) ? const Icon(Icons.person, color: _textSecondary) : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.matchName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
          ],
        ),
        backgroundColor: _cardColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: Colors.greenAccent), 
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => match_call.MatchCallView(
                userName: widget.matchName,
                userAvatar: widget.matchAvatar ?? '',
                calleeId: widget.matchId ?? '',
                isVideoCall: false,
                isIncoming: false,
              )));
            },
            tooltip: 'Audio Call',
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.greenAccent), 
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => match_call.MatchCallView(
                userName: widget.matchName,
                userAvatar: widget.matchAvatar ?? '',
                calleeId: widget.matchId ?? '',
                isVideoCall: true,
                isIncoming: false,
              )));
            },
            tooltip: 'Video Call',
          ),
          IconButton(
            icon: const Icon(Icons.videogame_asset, color: Colors.cyanAccent), 
            onPressed: _sendIcebreaker,
            tooltip: 'Send Icebreaker',
          ),
          IconButton(
            icon: const Icon(Icons.local_pizza, color: Colors.orange), 
            onPressed: _openDishiDateDialog,
            tooltip: 'Propose Dishi Date',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No messages yet', style: TextStyle(color: Colors.white54)));
                }

                final docs = snapshot.data!.docs;
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final msg = docs[index].data() as Map<String, dynamic>;
                    final isMe = msg['senderId'] == widget.myUid;
                    
                    if (msg['type'] == 'text') {
                      return _buildMessageBubble(msg['text'] ?? '', isMe);
                    } else if (msg['type'] == 'whisper') {
                      final expiresAt = msg['expiresAt'] as Timestamp?;
                      if (expiresAt != null && DateTime.now().isAfter(expiresAt.toDate())) {
                        return const SizedBox(); // Vanished
                      }
                      return _buildWhisperBubble(msg['text'] ?? '', isMe, 5); // Simplification for whisper timer
                    } else if (msg['type'] == 'icebreaker') {
                      return _buildIcebreakerBubble(isMe);
                    } else if (msg['type'] == 'dishi_date') {
                      return _buildDishiDateBubble(msg['venue'] ?? '', msg['splitAmount'] ?? 0, isMe);
                    } else if (msg['type'] == 'system_nudge') {
                      return _buildSystemNudgeBubble(msg['text'] ?? '');
                    }
                    return const SizedBox();
                  },
                );
              }
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: _cardColor,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.remove_red_eye, color: _isWhisperMode ? _neonPurple : _textSecondary), 
                  onPressed: () => setState(() => _isWhisperMode = !_isWhisperMode),
                  tooltip: 'Whisper Mode',
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: TextStyle(color: _isWhisperMode ? _neonPurple : Colors.white),
                    decoration: InputDecoration(
                      hintText: _isWhisperMode ? 'Whisper...' : 'Type a message...',
                      hintStyle: TextStyle(color: _isWhisperMode ? _neonPurple.withOpacity(0.5) : _textSecondary),
                      filled: true,
                      fillColor: _surfaceLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: _neonPink), 
                  onPressed: _sendMessage
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isMe ? _neonPink : _surfaceLight,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildWhisperBubble(String text, bool isMe, int timeLeft) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: _neonPurple, width: 1.5),
          boxShadow: [
            BoxShadow(color: _neonPurple.withOpacity(0.2), blurRadius: 10)
          ],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(text, style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic)),
            const SizedBox(height: 4),
            Text('Vanishing in $timeLeft\s', style: const TextStyle(color: _neonPurple, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildIcebreakerBubble(bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        width: 250,
        decoration: BoxDecoration(
          color: Colors.cyan.withOpacity(0.1),
          border: Border.all(color: Colors.cyanAccent),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Icon(Icons.casino, color: Colors.cyanAccent, size: 32),
            const SizedBox(height: 8),
            const Text('Two Truths and a Lie', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildIcebreakerOption('I have 3 dogs'),
            const SizedBox(height: 8),
            _buildIcebreakerOption('I speak 4 languages'),
            const SizedBox(height: 8),
            _buildIcebreakerOption('I broke my leg in Paris'),
          ],
        ),
      ),
    );
  }

  Widget _buildIcebreakerOption(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
    );
  }

  Widget _buildDishiDateBubble(String venue, int amount, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          border: Border.all(color: Colors.orange),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_pizza, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Text('Dishi Date Proposal!', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text('Venue: $venue', style: const TextStyle(color: Colors.white)),
            Text('Split: $amount KSH', style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            if (!isMe)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(80, 36)),
                    onPressed: () {},
                    child: const Text('ACCEPT', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size(80, 36)),
                    onPressed: () {},
                    child: const Text('DECLINE', style: TextStyle(color: Colors.white)),
                  ),
                ],
              )
            else
              const Text('Waiting for response...', style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemNudgeBubble(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic)),
      ),
    );
  }
}
