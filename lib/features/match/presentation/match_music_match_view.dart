import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'match_chat_view.dart'; 

const Color _bgColor = Color(0xFF0F172A);
const Color _cardColor = Color(0xFF131A2A);
const Color _neonPurple = Colors.purpleAccent;

class MatchMusicMatchView extends StatefulWidget {
  const MatchMusicMatchView({super.key});

  @override
  State<MatchMusicMatchView> createState() => _MatchMusicMatchViewState();
}

class _MatchMusicMatchViewState extends State<MatchMusicMatchView> with SingleTickerProviderStateMixin {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  bool _isSearching = false;
  String? _queueDocId;
  StreamSubscription? _queueSubscription;

  // Music Profile State
  final TextEditingController _spotifyController = TextEditingController();
  final TextEditingController _artist1Controller = TextEditingController();
  final TextEditingController _artist2Controller = TextEditingController();
  final TextEditingController _artist3Controller = TextEditingController();
  
  bool _lookingForConcertBuddy = false;
  List<String> _selectedGenres = [];
  final List<String> _allGenres = ['Afrobeats', 'Gengetone', 'Hip Hop', 'R&B', 'Pop', 'Amapiano', 'EDM', 'Rock', 'Indie', 'Gospel'];

  late AnimationController _eqController;
  int _currentTab = 0; // 0: Profile, 1: Match, 2: Feed

  @override
  void initState() {
    super.initState();
    _fetchMusicProfile();
    _eqController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    if (_queueDocId != null) {
      FirebaseFirestore.instance.collection('music_match_queue').doc(_queueDocId).delete();
    }
    _eqController.dispose();
    _spotifyController.dispose();
    _artist1Controller.dispose();
    _artist2Controller.dispose();
    _artist3Controller.dispose();
    super.dispose();
  }

  Future<void> _fetchMusicProfile() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      if (doc.exists && doc.data() != null && doc.data()!['musicProfile'] != null) {
        final data = doc.data()!['musicProfile'];
        setState(() {
          _spotifyController.text = data['spotifyUrl'] ?? '';
          _artist1Controller.text = data['topArtists']?[0] ?? '';
          if ((data['topArtists'] as List).length > 1) _artist2Controller.text = data['topArtists'][1];
          if ((data['topArtists'] as List).length > 2) _artist3Controller.text = data['topArtists'][2];
          _selectedGenres = List<String>.from(data['genres'] ?? []);
          _lookingForConcertBuddy = data['concertBuddy'] ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveMusicProfile() async {
    if (_selectedGenres.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one genre.')));
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('users').doc(_uid).set({
        'musicProfile': {
          'spotifyUrl': _spotifyController.text,
          'topArtists': [_artist1Controller.text, _artist2Controller.text, _artist3Controller.text].where((a) => a.isNotEmpty).toList(),
          'genres': _selectedGenres,
          'concertBuddy': _lookingForConcertBuddy,
        }
      }, SetOptions(merge: true));
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Music Profile Saved! 🎵'), backgroundColor: _neonPurple));
      setState(() => _currentTab = 1); // Move to match tab
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
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
    if (_selectedGenres.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Update your profile with genres first!')));
      setState(() => _currentTab = 0);
      return;
    }

    setState(() => _isSearching = true);
    
    try {
      // Find someone with at least one overlapping genre
      final queueSnapshot = await FirebaseFirestore.instance.collection('music_match_queue').where('uid', isNotEqualTo: _uid).get();

      DocumentSnapshot? bestMatch;
      int highestOverlap = 0;

      for (var doc in queueSnapshot.docs) {
        final theirGenres = List<String>.from(doc['genres'] ?? []);
        final overlap = theirGenres.where((g) => _selectedGenres.contains(g)).length;
        if (overlap > 0 && overlap > highestOverlap) {
          highestOverlap = overlap;
          bestMatch = doc;
        }
      }

      if (bestMatch != null) {
        final matchUid = bestMatch['uid'];
        final score = ((highestOverlap / max(_selectedGenres.length, 1)) * 100).toInt();
        await bestMatch.reference.delete();
        _onMatchFound(matchUid, score);
      } else {
        final docRef = await FirebaseFirestore.instance.collection('music_match_queue').add({
          'uid': _uid,
          'genres': _selectedGenres,
          'concertBuddy': _lookingForConcertBuddy,
          'timestamp': FieldValue.serverTimestamp(),
        });
        _queueDocId = docRef.id;

        _queueSubscription = docRef.snapshots().listen((snapshot) {
          if (!snapshot.exists && _isSearching) {
            // Found by someone else! We assume 80% for now if initiated by them
            _onMatchFound('Music Match', 80);
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

  void _onMatchFound(String matchId, int compatibilityScore) {
    if (!mounted) return;
    setState(() => _isSearching = false);
    _queueSubscription?.cancel();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🎵 Vibe Matched!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('We found someone with similar tastes!', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            Text('$compatibilityScore% Vibe Match', style: const TextStyle(color: _neonPurple, fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context); 
              // Send Song Icebreaker
              if (_spotifyController.text.isNotEmpty) {
                 // Sort IDs to ensure universal chat ID
                List<String> ids = [_uid, matchId];
                ids.sort();
                final chatId = '${ids[0]}_${ids[1]}';
                await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add({
                  'type': 'text',
                  'text': '🎧 I want you to listen to this: ${_spotifyController.text}',
                  'senderId': _uid,
                  'timestamp': FieldValue.serverTimestamp(),
                  'isRead': false,
                  'reactions': {},
                });
              }
              Navigator.push(context, MaterialPageRoute(builder: (_) => MatchChatView(
                chatId: 'temp_chat', // Fallback, would normally resolve to sorted ID
                myUid: _uid,
                matchName: 'Music Lover',
                matchAvatar: '',
                matchId: matchId,
              )));
            },
            child: const Text('Send Song & Chat', style: TextStyle(color: _neonPurple, fontSize: 16)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => MatchChatView(
                chatId: 'temp_chat',
                myUid: _uid,
                matchName: 'Music Lover',
                matchAvatar: '',
                matchId: matchId,
              )));
            },
            child: const Text('Just Chat', style: TextStyle(color: Colors.white54)),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        title: const Text('Music Match 🎧', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTab(0, 'Profile'),
              _buildTab(1, 'Match'),
              _buildTab(2, 'Discover'),
            ],
          ),
          Expanded(
            child: IndexedStack(
              index: _currentTab,
              children: [
                _buildProfileTab(),
                _buildMatchTab(),
                _buildDiscoverTab(),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTab(int index, String title) {
    final isSelected = _currentTab == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isSelected ? _neonPurple : Colors.transparent, width: 2))
        ),
        child: Text(title, style: TextStyle(color: isSelected ? _neonPurple : Colors.white54, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top 3 Artists', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(controller: _artist1Controller, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Artist 1')),
          const SizedBox(height: 8),
          TextField(controller: _artist2Controller, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Artist 2')),
          const SizedBox(height: 8),
          TextField(controller: _artist3Controller, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Artist 3')),
          const SizedBox(height: 24),
          
          const Text('Favorite Song / Spotify Link', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(controller: _spotifyController, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Paste a Spotify URL or Song Name')),
          const SizedBox(height: 24),

          const Text('Music Genres', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allGenres.map((genre) {
              final isSelected = _selectedGenres.contains(genre);
              return ChoiceChip(
                label: Text(genre, style: TextStyle(color: isSelected ? Colors.white : Colors.white70)),
                selected: isSelected,
                selectedColor: _neonPurple,
                backgroundColor: _cardColor,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _selectedGenres.add(genre);
                    } else {
                      _selectedGenres.remove(genre);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Concert Buddy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text('Looking for someone to go to gigs with?', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                Switch(
                  value: _lookingForConcertBuddy,
                  activeThumbColor: _neonPurple,
                  onChanged: (v) => setState(() => _lookingForConcertBuddy = v),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _neonPurple, padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _saveMusicProfile,
              child: const Text('Save Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: _cardColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
    );
  }

  Widget _buildMatchTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isSearching)
            AnimatedBuilder(
              animation: _eqController,
              builder: (context, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(5, (index) {
                    final height = 20 + (80 * (_eqController.value * (index % 2 == 0 ? 1 : 0.5) + (Random().nextDouble() * 0.5)));
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 12,
                      height: height,
                      decoration: BoxDecoration(color: _neonPurple, borderRadius: BorderRadius.circular(6)),
                    );
                  }),
                );
              }
            )
          else
            const Icon(Icons.music_note, color: _neonPurple, size: 80),
          
          const SizedBox(height: 40),
          Text(
            _isSearching ? 'Analyzing your vibes & searching...' : 'Find someone with your music taste.', 
            style: const TextStyle(color: Colors.white, fontSize: 18)
          ),
          const SizedBox(height: 32),
          
          if (_isSearching) ...[
            TextButton(
              onPressed: _cancelSearch, 
              child: const Text('Cancel Search', style: TextStyle(color: Colors.redAccent))
            )
          ] else ...[
            ElevatedButton(
              onPressed: _startMatchmaking, 
              style: ElevatedButton.styleFrom(
                backgroundColor: _neonPurple,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ), 
              child: const Text('Sync Music Taste', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))
            )
          ]
        ],
      ),
    );
  }

  Widget _buildDiscoverTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('musicProfile.genres', isNull: false).limit(20).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: _neonPurple));
        
        final docs = snapshot.data!.docs.where((d) => d.id != _uid).toList();
        if (docs.isEmpty) return const Center(child: Text('No users found in Discover', style: TextStyle(color: Colors.white54)));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final profile = data['musicProfile'];
            final name = data['displayName'] ?? 'Student';
            final avatar = data['profileImageUrl'];
            final topArtist = profile['topArtists'] != null && (profile['topArtists'] as List).isNotEmpty ? profile['topArtists'][0] : 'Unknown';

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
                    backgroundColor: Colors.grey[800],
                    child: (avatar == null || avatar.isEmpty) ? const Icon(Icons.person, color: Colors.white54) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('🎵 Listens to $topArtist', style: const TextStyle(color: _neonPurple, fontSize: 12)),
                        if (profile['concertBuddy'] == true)
                          const Padding(
                            padding: EdgeInsets.only(top: 4.0),
                            child: Text('🎟️ Looking for concert buddy!', style: TextStyle(color: Colors.orange, fontSize: 10)),
                          )
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, color: Colors.white54),
                    onPressed: () {
                      List<String> ids = [_uid, docs[index].id];
                      ids.sort();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => MatchChatView(
                        chatId: '${ids[0]}_${ids[1]}',
                        myUid: _uid,
                        matchName: name,
                        matchAvatar: avatar,
                        matchId: docs[index].id,
                      )));
                    },
                  )
                ],
              ),
            );
          },
        );
      }
    );
  }
}
