import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'match_dishi_date_dialog.dart';
import 'match_call_view.dart' as match_call;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/user_model.dart';
import '../../student/presentation/student_profile_settings.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  
  // Voice Note State
  final Record _audioRecorder = Record();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isUploadingAudio = false;
  String? _currentlyPlayingAudio;
  
  bool _isWhisperMode = false;
  bool _isTyping = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
    
    // Typing listener
    _textController.addListener(() {
      if (mounted) setState(() {}); // rebuild to show/hide send button
      if (_textController.text.isNotEmpty && !_isTyping) {
        _setTypingStatus(true);
      }
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        if (_isTyping) _setTypingStatus(false);
      });
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        if (mounted) setState(() => _currentlyPlayingAudio = null);
      }
    });
  }

  @override
  void dispose() {
    _setTypingStatus(false);
    _typingTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _setTypingStatus(bool isTyping) async {
    _isTyping = isTyping;
    try {
      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set({
        'typing_${widget.myUid}': isTyping,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _markMessagesAsRead() async {
    final unreadMsgs = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: widget.myUid)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in unreadMsgs.docs) {
      doc.reference.update({'isRead': true});
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0, 
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
    _setTypingStatus(false);

    if (_isWhisperMode) {
      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').add({
        'type': 'whisper',
        'text': text,
        'senderId': widget.myUid,
        'timestamp': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(seconds: 10))),
        'isRead': false,
        'reactions': {},
      });
    } else {
      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').add({
        'type': 'text',
        'text': text,
        'senderId': widget.myUid,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'reactions': {},
      });
    }
    _scrollToBottom();
  }

  // ---- AUDIO MESSAGING ----
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = p.join(dir.path, 'chat_audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
        await _audioRecorder.start(path: path);
        setState(() => _isRecording = true);
      }
    } catch (e) {
      debugPrint('Error starting record: $e');
    }
  }

  Future<void> _stopAndSendRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        _uploadAndSendAudio(path);
      }
    } catch (e) {
      debugPrint('Error stopping record: $e');
    }
  }

  Future<void> _uploadAndSendAudio(String path) async {
    setState(() => _isUploadingAudio = true);
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = FirebaseStorage.instance.ref().child('chat_audio/${widget.chatId}_$timestamp.m4a');
      await storageRef.putFile(File(path), SettableMetadata(contentType: 'audio/m4a'));
      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').add({
        'type': 'audio',
        'audioUrl': downloadUrl,
        'senderId': widget.myUid,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'reactions': {},
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error uploading audio: $e');
    } finally {
      if (mounted) setState(() => _isUploadingAudio = false);
    }
  }

  Future<void> _playPauseAudio(String url) async {
    if (_currentlyPlayingAudio == url) {
      await _audioPlayer.pause();
      setState(() => _currentlyPlayingAudio = null);
    } else {
      await _audioPlayer.play(UrlSource(url));
      setState(() => _currentlyPlayingAudio = url);
    }
  }

  // ---- REACTIONS ----
  void _addReaction(String msgId, String emoji) async {
    final docRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').doc(msgId);
    await docRef.set({
      'reactions': {widget.myUid: emoji}
    }, SetOptions(merge: true));
  }

  Future<void> _makeCellularCall(String calleeId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(calleeId).get();
      final calleePhone = doc.data()?['phone_number']?.toString();
      
      if (calleePhone != null && calleePhone.trim().isNotEmpty) {
        final Uri launchUri = Uri(scheme: 'tel', path: calleePhone);
        if (await canLaunchUrl(launchUri)) {
          await launchUrl(launchUri);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch dialer.')));
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This user has not added their phone number yet.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error making call: $e')));
      }
    }
  }

  void _promptPhoneNumber(String calleeId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('Phone Number Required', style: TextStyle(color: _neonPink)),
          content: const Text(
            'To make cellular calls, you need to add your phone number to your profile.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudentProfileSettings(
                        userModel: UserModel(
                          uid: user.uid,
                          displayName: user.displayName ?? '',
                          email: user.email ?? '',
                          roles: ['student'],
                        ),
                      ),
                    ),
                  );
                  // Check again if they added it
                  final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                  final hasPhone = doc.data()?['phone_number'] != null && doc.data()!['phone_number'].toString().trim().isNotEmpty;
                  if (hasPhone && mounted) {
                    _makeCellularCall(calleeId);
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _neonPink),
              child: const Text('Add Number', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
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
              Navigator.push(context, MaterialPageRoute(builder: (_) => match_call.MatchCallView(userName: widget.matchName, userAvatar: widget.matchAvatar ?? '', calleeId: widget.matchId ?? '', isVideoCall: false, isIncoming: false)));
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.greenAccent), 
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => match_call.MatchCallView(userName: widget.matchName, userAvatar: widget.matchAvatar ?? '', calleeId: widget.matchId ?? '', isVideoCall: true, isIncoming: false)));
            },
          ),
          IconButton(
            icon: const Icon(Icons.phone_iphone, color: Colors.white70), 
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null || widget.matchId == null) return;
              
              final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
              final hasPhone = doc.data()?['phone_number'] != null && doc.data()!['phone_number'].toString().trim().isNotEmpty;
              
              if (!hasPhone) {
                _promptPhoneNumber(widget.matchId!);
              } else {
                _makeCellularCall(widget.matchId!);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Typing Indicator Area
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final opponentId = widget.matchId; // Or derive from users array
                if (opponentId != null && data['typing_$opponentId'] == true) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                    alignment: Alignment.centerLeft,
                    child: Text('${widget.matchName} is typing...', style: const TextStyle(color: _neonPink, fontSize: 12, fontStyle: FontStyle.italic)),
                  );
                }
              }
              return const SizedBox();
            }
          ),

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
                  return const Center(child: CircularProgressIndicator(color: _neonPink));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No messages yet. Send an Icebreaker!', style: TextStyle(color: Colors.white54)));
                }

                final docs = snapshot.data!.docs;
                
                // Mark unread as read automatically
                WidgetsBinding.instance.addPostFrameCallback((_) => _markMessagesAsRead());

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final msg = doc.data() as Map<String, dynamic>;
                    final isMe = msg['senderId'] == widget.myUid;
                    
                    return GestureDetector(
                      onLongPress: () {
                        // Emoji Reaction Menu
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (context) => Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(30)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: ['❤️', '😂', '🔥', '👍', '👀'].map((emoji) => GestureDetector(
                                onTap: () {
                                  _addReaction(doc.id, emoji);
                                  Navigator.pop(context);
                                },
                                child: Text(emoji, style: const TextStyle(fontSize: 32)),
                              )).toList(),
                            ),
                          )
                        );
                      },
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (msg['type'] == 'text')
                            _buildMessageBubble(msg, isMe)
                          else if (msg['type'] == 'audio')
                            _buildAudioBubble(msg, isMe)
                          else if (msg['type'] == 'whisper')
                            _buildWhisperBubble(msg, isMe)
                          else if (msg['type'] == 'flashcard')
                            _buildFlashcardBubble(msg, isMe),
                            
                          // Display Reactions
                          if (msg['reactions'] != null && (msg['reactions'] as Map).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(12)),
                                child: Text((msg['reactions'] as Map).values.toSet().join(' '), style: const TextStyle(fontSize: 12)),
                              ),
                            )
                        ],
                      ),
                    );
                  },
                );
              }
            ),
          ),
          
          if (_isUploadingAudio)
            const LinearProgressIndicator(color: _neonPink, backgroundColor: Colors.transparent),

          Container(
            padding: const EdgeInsets.all(16),
            color: _cardColor,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.remove_red_eye, color: _isWhisperMode ? _neonPurple : _textSecondary), 
                  onPressed: () => setState(() => _isWhisperMode = !_isWhisperMode),
                  tooltip: 'Whisper Mode (Disappearing Messages)',
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
                // Always show send button; show mic only when text is empty
                if (_textController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.send, color: _neonPink),
                    onPressed: _sendMessage,
                    tooltip: 'Send',
                  )
                else
                  GestureDetector(
                    onLongPressStart: (_) => _startRecording(),
                    onLongPressEnd: (_) => _stopAndSendRecording(),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                          _isRecording ? Icons.mic : Icons.mic_none,
                          color: _isRecording ? Colors.redAccent : _neonPink),
                    ),
                  )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final text = msg['text'] ?? '';
    final isRead = msg['isRead'] ?? false;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 4, top: 4),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(text, style: const TextStyle(color: Colors.white)),
          if (isMe)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Icon(isRead ? Icons.done_all : Icons.done, size: 14, color: isRead ? Colors.blueAccent : Colors.white54),
            )
        ],
      ),
    );
  }

  Widget _buildAudioBubble(Map<String, dynamic> msg, bool isMe) {
    final url = msg['audioUrl'] ?? '';
    final isPlaying = _currentlyPlayingAudio == url;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 4, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isMe ? _neonPink.withOpacity(0.8) : _surfaceLight,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMe ? 16 : 0),
          bottomRight: Radius.circular(isMe ? 0 : 16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
            onPressed: () => _playPauseAudio(url),
          ),
          const SizedBox(width: 8),
          const Text('Voice Note', style: TextStyle(color: Colors.white)),
          const SizedBox(width: 24),
          if (isMe)
            Icon(msg['isRead'] == true ? Icons.done_all : Icons.done, size: 14, color: msg['isRead'] == true ? Colors.blueAccent : Colors.white54),
        ],
      ),
    );
  }

  Widget _buildWhisperBubble(Map<String, dynamic> msg, bool isMe) {
    final text = msg['text'] ?? '';
    final expiresAt = msg['expiresAt'] as Timestamp?;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt.toDate())) {
      return const SizedBox(); // Vanished
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4, top: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: _neonPurple, width: 1.5),
        boxShadow: [BoxShadow(color: _neonPurple.withOpacity(0.2), blurRadius: 10)],
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
          const Text('Disappearing Message', style: TextStyle(color: _neonPurple, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFlashcardBubble(Map<String, dynamic> msg, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4, top: 4),
      padding: const EdgeInsets.all(16),
      width: 250,
      decoration: BoxDecoration(
        color: Colors.yellowAccent.withOpacity(0.1),
        border: Border.all(color: Colors.yellowAccent),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.style, color: Colors.yellowAccent, size: 16),
              SizedBox(width: 8),
              Text('Shared Flashcard', style: TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(msg['question'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Answer: ${msg['answer'] ?? ''}', style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
