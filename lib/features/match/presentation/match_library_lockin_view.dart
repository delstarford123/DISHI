import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'match_chat_view.dart'; // Ensure this exists to route to

class MatchLibraryLockInView extends StatefulWidget {
  const MatchLibraryLockInView({super.key});

  @override
  State<MatchLibraryLockInView> createState() => _MatchLibraryLockInViewState();
}

class _MatchLibraryLockInViewState extends State<MatchLibraryLockInView> {
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
      await FirebaseFirestore.instance.collection('library_lockin_queue').doc(_queueDocId).delete();
      _queueDocId = null;
    }
    if (mounted) setState(() => _isSearching = false);
  }

  Future<void> _startMatchmaking() async {
    setState(() => _isSearching = true);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    
    try {
      final queueSnapshot = await FirebaseFirestore.instance
          .collection('library_lockin_queue')
          .where('uid', isNotEqualTo: uid)
          .limit(1)
          .get();

      if (queueSnapshot.docs.isNotEmpty) {
        final matchDoc = queueSnapshot.docs.first;
        final matchUid = matchDoc['uid'];
        await matchDoc.reference.delete();
        _onMatchFound(matchUid);
      } else {
        final docRef = await FirebaseFirestore.instance.collection('library_lockin_queue').add({
          'uid': uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
        _queueDocId = docRef.id;

        _queueSubscription = docRef.snapshots().listen((snapshot) {
          if (!snapshot.exists && _isSearching) {
            _onMatchFound('Study Buddy');
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
        title: const Text('📍 Buddy Found!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('We found a study partner checked in nearby.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); 
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => MatchChatView(
                chatId: 'temp_chat',
                myUid: FirebaseAuth.instance.currentUser?.uid ?? 'guest',
                matchName: 'Study Buddy',
                matchAvatar: '',
              )));
            },
            child: const Text('Say Hi', style: TextStyle(color: Colors.greenAccent, fontSize: 16)),
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
        title: const Text('Library Lock-In 📍', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book, color: _isSearching ? Colors.greenAccent.shade100 : Colors.greenAccent, size: 80),
            const SizedBox(height: 20),
            Text(
              _isSearching ? 'Scanning for students nearby...' : 'Match with students studying nearby.', 
              style: const TextStyle(color: Colors.white, fontSize: 18)
            ),
            const SizedBox(height: 32),
            if (_isSearching) ...[
              const CircularProgressIndicator(color: Colors.greenAccent),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _cancelSearch, 
                child: const Text('Cancel', style: TextStyle(color: Colors.redAccent))
              )
            ] else ...[
              ElevatedButton(
                onPressed: _startMatchmaking, 
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ), 
                child: const Text('Check In Now', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold))
              )
            ]
          ],
        ),
      ),
    );
  }
}
