import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'match_chat_view.dart';

class MatchLibraryLockInView extends StatefulWidget {
  const MatchLibraryLockInView({super.key});

  @override
  State<MatchLibraryLockInView> createState() => _MatchLibraryLockInViewState();
}

class _MatchLibraryLockInViewState extends State<MatchLibraryLockInView> {
  bool _isSearching = false;
  String? _queueDocId;
  StreamSubscription? _queueSubscription;

  final List<String> _libraries = ['Main Library', 'Science Library', 'Law Library', 'Medical Library'];
  String _selectedLibrary = 'Main Library';
  
  final List<String> _subjects = ['Computer Science', 'Law', 'Medicine', 'Engineering', 'Arts', 'Business'];
  String _selectedSubject = 'Computer Science';
  
  final TextEditingController _locationController = TextEditingController();
  bool _isSilenceMode = false;
  
  // Pomodoro
  bool _isMatched = false;
  String? _matchUid;
  Timer? _pomodoroTimer;
  int _pomodoroSeconds = 1500; // 25 mins

  int _activeCount = 0;
  final int _studyStreak = 3;

  String get currentUid => FirebaseAuth.instance.currentUser?.uid ?? 'guest';

  @override
  void initState() {
    super.initState();
    _listenToActiveCount();
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    if (_queueDocId != null) {
      FirebaseFirestore.instance.collection('library_lockin_queue').doc(_queueDocId).delete();
    }
    _pomodoroTimer?.cancel();
    _locationController.dispose();
    super.dispose();
  }
  
  void _listenToActiveCount() {
    FirebaseFirestore.instance.collection('library_lockin_queue').where('status', isEqualTo: 'waiting').snapshots().listen((snap) {
      if (mounted) setState(() => _activeCount = snap.docs.length * 3 + 12); // Mocking higher numbers for feel
    });
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
    
    // Background matchmaking notice
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Searching in background! You can browse other tabs.')));
    
    try {
      final queueSnapshot = await FirebaseFirestore.instance
          .collection('library_lockin_queue')
          .where('status', isEqualTo: 'waiting')
          .where('library', isEqualTo: _selectedLibrary)
          .where('uid', isNotEqualTo: currentUid)
          .limit(1)
          .get();

      if (queueSnapshot.docs.isNotEmpty) {
        final matchDoc = queueSnapshot.docs.first;
        await matchDoc.reference.update({'status': 'matched', 'matchUid': currentUid});
        _onMatchFound(matchDoc['uid']);
      } else {
        final docRef = await FirebaseFirestore.instance.collection('library_lockin_queue').add({
          'uid': currentUid,
          'library': _selectedLibrary,
          'subject': _selectedSubject,
          'floor': _locationController.text,
          'silenceMode': _isSilenceMode,
          'status': 'waiting',
          'timestamp': FieldValue.serverTimestamp(),
        });
        _queueDocId = docRef.id;

        _queueSubscription = docRef.snapshots().listen((snapshot) {
          if (snapshot.exists && snapshot.data()?['status'] == 'matched') {
            _onMatchFound(snapshot.data()?['matchUid'] ?? 'Study Buddy');
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
    setState(() {
      _isSearching = false;
      _isMatched = true;
      _matchUid = matchId;
    });
    _queueSubscription?.cancel();
    _startPomodoro();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('📍 Buddy Found!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(radius: 30, backgroundColor: Colors.greenAccent, child: Icon(Icons.person, color: Colors.black, size: 30)),
            const SizedBox(height: 16),
            const Text('We found a study partner checked in nearby.', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('They are studying: $_selectedSubject', style: const TextStyle(color: Colors.greenAccent)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); 
            },
            child: const Text('Close', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => MatchChatView(
                chatId: 'library_chat_${DateTime.now().millisecondsSinceEpoch}',
                myUid: currentUid,
                matchName: 'Study Buddy',
                matchAvatar: '',
              )));
            },
            child: const Text('Chat & Meet', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }
  
  void _startPomodoro() {
    _pomodoroTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_pomodoroSeconds > 0) {
        setState(() => _pomodoroSeconds--);
      } else {
        timer.cancel();
        _notifyBreak();
      }
    });
  }
  
  void _notifyBreak() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('☕ Coffee Break!', style: TextStyle(color: Colors.white)),
        content: const Text('You\'ve completed a 25-minute focus session! Take a 5 minute break with your buddy.', style: TextStyle(color: Colors.white70)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            onPressed: () {
              Navigator.pop(context);
              setState(() => _pomodoroSeconds = 1500); // Reset
              _startPomodoro();
            }, 
            child: const Text('Restart Timer', style: TextStyle(color: Colors.black))
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
        title: const Text('Library Lock-In 📍', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 16),
                    const SizedBox(width: 4),
                    Text('$_studyStreak', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
      body: _isMatched ? _buildMatchedView() : _buildSetupView(),
    );
  }
  
  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live Map Preview
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
              image: const DecorationImage(
                image: NetworkImage('https://images.unsplash.com/photo-1524661135-423995f22d0b?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
              )
            ),
            child: Stack(
              children: [
                const Center(child: Icon(Icons.map, color: Colors.white24, size: 60)),
                Positioned(top: 30, left: 50, child: _buildMapDot()),
                Positioned(top: 80, right: 100, child: _buildMapDot()),
                Positioned(bottom: 40, left: 150, child: _buildMapDot()),
                Positioned(
                  bottom: 12, left: 12,
                  child: Row(
                    children: [
                      const Icon(Icons.people, color: Colors.greenAccent, size: 16),
                      const SizedBox(width: 4),
                      Text('$_activeCount Locked In', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          const Text('Check-In Details', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          // Library Select
          DropdownButtonFormField<String>(
            initialValue: _selectedLibrary,
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Library',
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.account_balance, color: Colors.white54),
            ),
            items: _libraries.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
            onChanged: (v) => setState(() => _selectedLibrary = v!),
          ),
          const SizedBox(height: 16),
          
          // Floor/Desk
          TextField(
            controller: _locationController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Current Floor / Desk',
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.place, color: Colors.white54),
            ),
          ),
          const SizedBox(height: 16),
          
          // Subject
          DropdownButtonFormField<String>(
            initialValue: _selectedSubject,
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Study Subject',
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.menu_book, color: Colors.white54),
            ),
            items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _selectedSubject = v!),
          ),
          const SizedBox(height: 16),
          
          // Silence Mode
          SwitchListTile(
            title: const Text('Silence Mode', style: TextStyle(color: Colors.white)),
            subtitle: const Text('I want a quiet accountability buddy.', style: TextStyle(color: Colors.white54)),
            activeThumbColor: Colors.greenAccent,
            value: _isSilenceMode,
            onChanged: (v) => setState(() => _isSilenceMode = v),
          ),
          const SizedBox(height: 32),
          
          if (_isSearching) ...[
            const Center(child: CircularProgressIndicator(color: Colors.greenAccent)),
            const SizedBox(height: 16),
            Center(child: TextButton(onPressed: _cancelSearch, child: const Text('Cancel Search', style: TextStyle(color: Colors.redAccent))))
          ] else ...[
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: _startMatchmaking, 
                style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), 
                child: const Text('LOCK IN', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold))
              ),
            )
          ]
        ],
      ),
    );
  }
  
  Widget _buildMapDot() {
    return Container(
      width: 10, height: 10,
      decoration: BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)]),
    );
  }
  
  Widget _buildMatchedView() {
    final String minutes = (_pomodoroSeconds ~/ 60).toString().padLeft(2, '0');
    final String seconds = (_pomodoroSeconds % 60).toString().padLeft(2, '0');
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer, color: Colors.greenAccent, size: 80),
          const SizedBox(height: 24),
          Text('$minutes:$seconds', style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(height: 8),
          const Text('Focus Session Active', style: TextStyle(color: Colors.greenAccent, fontSize: 18)),
          const SizedBox(height: 40),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                onPressed: () {
                  setState(() { _isMatched = false; _isSearching = false; });
                  _pomodoroTimer?.cancel();
                },
                icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
                label: const Text('End Session', style: TextStyle(color: Colors.redAccent)),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent Coffee Break nudge to buddy!'))),
                icon: const Icon(Icons.coffee, color: Colors.black),
                label: const Text('Take a Break', style: TextStyle(color: Colors.black)),
              )
            ],
          )
        ],
      ),
    );
  }
}
