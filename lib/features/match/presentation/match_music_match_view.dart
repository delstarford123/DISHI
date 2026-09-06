import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'match_chat_view.dart'; // Ensure this exists to route to

class MatchMusicMatchView extends StatefulWidget {
  const MatchMusicMatchView({super.key});

  @override
  State<MatchMusicMatchView> createState() => _MatchMusicMatchViewState();
}

class _MatchMusicMatchViewState extends State<MatchMusicMatchView> {
  bool _isSearching = false;
  String? _queueDocId;
  StreamSubscription? _queueSubscription;

  @override
  void dispose() {
    _cancelSearch();
    super.dispose();
  }

  Future<void> _cancelSearch() async {
    _queueSubscription?.cancel();
    if (_queueDocId != null) {
      await FirebaseFirestore.instance.collection('music_match_queue').doc(_queueDocId).delete();
      _queueDocId = null;
    }
    if (mounted) setState(() => _isSearching = false);
  }

  Future<void> _startMatchmaking() async {
    setState(() => _isSearching = true);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    
    try {
      final queueSnapshot = await FirebaseFirestore.instance
          .collection('music_match_queue')
          .where('uid', isNotEqualTo: uid)
          .limit(1)
          .get();

      if (queueSnapshot.docs.isNotEmpty) {
        final matchDoc = queueSnapshot.docs.first;
        final matchUid = matchDoc['uid'];
        await matchDoc.reference.delete();
        _onMatchFound(matchUid);
      } else {
        final docRef = await FirebaseFirestore.instance.collection('music_match_queue').add({
          'uid': uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
        _queueDocId = docRef.id;

        _queueSubscription = docRef.snapshots().listen((snapshot) {
          if (!snapshot.exists && _isSearching) {
            _onMatchFound('Music Match');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isSearching = false);
      }
    }
  }

  void _onMatchFound(String matchId) {
    if (!mounted) return;
    setState(() => _isSearching = false);
    _queueSubscription?.cancel();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🎵 Vibe Matched!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('We found someone with similar Spotify tastes.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); 
              Navigator.pop(context);
              // Navigate to a chat view (assuming it takes basic params, or just let them see it in Hub)
              Navigator.push(context, MaterialPageRoute(builder: (_) => MatchChatView(
                chatId: 'temp_chat',
                myUid: FirebaseAuth.instance.currentUser?.uid ?? 'guest',
                matchName: 'Music Lover',
                matchAvatar: '',
              )));
            },
            child: const Text('Start Chatting', style: TextStyle(color: Colors.purpleAccent, fontSize: 16)),
          )
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
        title: const Text('Music Match 🎧', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note, color: _isSearching ? Colors.purpleAccent.shade100 : Colors.purpleAccent, size: 80),
            const SizedBox(height: 20),
            Text(
              _isSearching ? 'Analyzing your vibes & searching...' : 'Match based on Spotify vibes.', 
              style: const TextStyle(color: Colors.white, fontSize: 18)
            ),
            const SizedBox(height: 32),
            if (_isSearching) ...[
              const CircularProgressIndicator(color: Colors.purpleAccent),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _cancelSearch, 
                child: const Text('Cancel', style: TextStyle(color: Colors.redAccent))
              )
            ] else ...[
              ElevatedButton(
                onPressed: _startMatchmaking, 
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ), 
                child: const Text('Sync Music Taste', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))
              )
            ]
          ],
        ),
      ),
    );
  }
}
