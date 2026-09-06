import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'match_call_view.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/models/match_profile_model.dart';

class MatchNightClubView extends StatefulWidget {
  const MatchNightClubView({super.key});

  @override
  State<MatchNightClubView> createState() => _MatchNightClubViewState();
}

class _MatchNightClubViewState extends State<MatchNightClubView> with TickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  
  late AnimationController _discoController;
  late Animation<Color?> _colorAnim1;
  late Animation<Color?> _colorAnim2;
  
  late AnimationController _danceController;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = true;
  String _currentTrack = 'party1.mp3';
  final List<String> _tracks = [
    'party.mp3', 'party1.mp3', 'party2.mp3', 'party3.mp3', 
    'party4.mp3', 'party5.mp3', 'party6.mp3', 'party7.mp3', 
    'party8.mp3', 'party9.mp3', 'party10.mp3', 'party11.mp3', 'party12.mp3'
  ];

  final Map<String, String> _trackNames = {
    'party.mp3': 'Campus Anthem',
    'party1.mp3': 'Neon Groove',
    'party2.mp3': 'Midnight Vibe',
    'party3.mp3': 'Electric Lounge',
    'party4.mp3': 'Rooftop Pulse',
    'party5.mp3': 'Twilight Beats',
    'party6.mp3': 'Sunset House',
    'party7.mp3': 'Velvet Dance',
    'party8.mp3': 'Cosmic Rhythm',
    'party9.mp3': 'Deep House Flow',
    'party10.mp3': 'Urban Night',
    'party11.mp3': 'Club Serenity',
    'party12.mp3': 'Weekend Energy'
  };

  @override
  void initState() {
    super.initState();
    
    // Setup Disco Lights
    _discoController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _colorAnim1 = ColorTween(begin: const Color(0xFF1E1B4B), end: const Color(0xFF31103F)).animate(_discoController);
    _colorAnim2 = ColorTween(begin: const Color(0xFF831843), end: const Color(0xFF0F766E)).animate(_discoController);

    // Setup Dancing Animation
    _danceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);

    _playTrack(_currentTrack);
    
    _audioPlayer.onPlayerComplete.listen((event) {
       _playNextTrack();
    });
  }

  @override
  void dispose() {
    _discoController.dispose();
    _danceController.dispose();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playTrack(String track) async {
    setState(() { _currentTrack = track; _isPlaying = true; });
    await _audioPlayer.play(AssetSource('sounds/$track'));
  }

  void _playNextTrack() {
    int index = _tracks.indexOf(_currentTrack);
    if (index < _tracks.length - 1) {
      _playTrack(_tracks[index + 1]);
    } else {
      _playTrack(_tracks[0]);
    }
  }

  void _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.resume();
    }
    setState(() { _isPlaying = !_isPlaying; });
  }

  void _showTrackList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      builder: (context) {
        return ListView.builder(
          itemCount: _tracks.length,
          itemBuilder: (context, index) {
            final track = _tracks[index];
            final isActive = track == _currentTrack;
              final displayName = _trackNames[track] ?? track.replaceAll('.mp3', '').toUpperCase();
              return ListTile(
                leading: Icon(isActive ? Icons.volume_up : Icons.music_note, color: isActive ? Colors.pinkAccent : Colors.grey),
                title: Text(displayName, style: TextStyle(color: isActive ? Colors.pinkAccent : Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _playTrack(track);
              },
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_note, color: Colors.pinkAccent),
            SizedBox(width: 8),
            Text('Virtual Club', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.library_music, color: Colors.pinkAccent),
            onPressed: _showTrackList,
          ),
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.amber),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No new club notifications.')),
              );
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _discoController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _colorAnim1.value ?? const Color(0xFF1E1B4B),
                  const Color(0xFF4C1D95),
                  _colorAnim2.value ?? const Color(0xFF831843),
                ],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').limit(20).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
              }

              final currentUid = FirebaseAuth.instance.currentUser?.uid;
              final profiles = snapshot.data?.docs.map((doc) => 
                {'uid': doc.id, ...doc.data() as Map<String, dynamic>}
              ).where((user) {
                 final roles = user['roles'] as List<dynamic>? ?? [];
                 final isAdmin = roles.contains('admin') || roles.contains('system_admin');
                 return user['uid'] != currentUid && !isAdmin;
              }).toList() ?? [];

              return Column(
                children: [
                  // Online Status Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text('${profiles.length} Students Online Live', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Text('24/7 Campus Club', style: TextStyle(color: Colors.pinkAccent, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Live Avatars
                  if (profiles.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text('The club is empty right now...', style: TextStyle(color: Colors.white70)),
                      ),
                    )
                  else
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 32,
                          childAspectRatio: 0.7,
                        ),
                        itemCount: profiles.length,
                        itemBuilder: (context, index) {
                          final profile = profiles[index];
                          final glowColor = [Colors.cyanAccent, Colors.pinkAccent, Colors.purpleAccent][index % 3];
                          final icon = [Icons.person, Icons.person_2, Icons.person_3, Icons.person_4][index % 4];
                          final String fakeSchool = ['UoN', 'Strathmore', 'KU', 'JKUAT'][index % 4];
                          
                          final name = (profile['displayName'] ?? profile['name'] ?? 'Student').toString();
                          final String? avatarUrl = profile['profileImageUrl'];
                          final subtext = (profile['bio'] ?? 'Looking to vibe').toString();

                          return GestureDetector(
                            onTap: () {
                              _showCallOptions(name, '$fakeSchool • $subtext', profile['uid'] ?? profile['id'] ?? '', avatarUrl ?? '');
                            },
                            child: AnimatedBuilder(
                              animation: _danceController,
                              builder: (context, child) {
                                // Add a slight offset and rotation to mimic dancing
                                final isEven = index % 2 == 0;
                                final offset = isEven ? _danceController.value * 5 : -_danceController.value * 5;
                                final rotation = isEven ? _danceController.value * 0.05 : -_danceController.value * 0.05;

                                return Transform.translate(
                                  offset: Offset(0, offset),
                                  child: Transform.rotate(
                                    angle: rotation,
                                    child: child,
                                  ),
                                );
                              },
                              child: _buildGlowingAvatar(
                                name, 
                                '$fakeSchool • $subtext', 
                                glowColor, 
                                icon
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  
                  // Bottom DJ Player
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F172A),
                      border: Border(top: BorderSide(color: Colors.pinkAccent, width: 2)),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _togglePlayPause,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(color: Colors.pinkAccent, shape: BoxShape.circle),
                            child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('NOW PLAYING IN VIRTUAL CLUB:', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                              Text(_trackNames[_currentTrack] ?? _currentTrack.replaceAll('.mp3', '').toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _showTrackList,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pinkAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: const Icon(Icons.queue_music, color: Colors.white),
                          label: const Text('DJ Tracks', style: TextStyle(color: Colors.white)),
                        )
                      ],
                    ),
                  )
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGlowingAvatar(String name, String subtext, Color glowColor, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 6,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: glowColor,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: glowColor.withOpacity(0.8), blurRadius: 10, spreadRadius: 2),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: glowColor,
            boxShadow: [
              BoxShadow(color: glowColor.withOpacity(0.5), blurRadius: 15, spreadRadius: 5),
            ],
          ),
          child: CircleAvatar(
            radius: 35,
            backgroundColor: Colors.black,
            child: Icon(icon, size: 40, color: Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(subtext, style: const TextStyle(color: Colors.grey, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
      ],
    );
  }

  void _showCallOptions(String userName, String school, String calleeId, String userAvatar) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.pinkAccent,
                backgroundImage: userAvatar.isNotEmpty ? NetworkImage(userAvatar) : null,
                child: userAvatar.isEmpty ? const Icon(Icons.person, size: 40, color: Colors.white) : null,
              ),
              const SizedBox(height: 16),
              Text('Connect with $userName', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Text(school, style: const TextStyle(color: Colors.pinkAccent, fontSize: 14)),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.videocam, color: Colors.cyanAccent),
                title: const Text('Video Call', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _startCall(userName, calleeId, userAvatar, true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.call, color: Colors.greenAccent),
                title: const Text('Audio Call', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _startCall(userName, calleeId, userAvatar, false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.phone_iphone, color: Colors.white70),
                title: const Text('Cellular Call', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _promptPhoneNumber(userName);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _startCall(String userName, String calleeId, String userAvatar, bool isVideo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MatchCallView(
          userName: userName,
          userAvatar: userAvatar,
          calleeId: calleeId,
          isVideoCall: isVideo,
        ),
      ),
    );
  }

  void _promptPhoneNumber(String userName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('Phone Number Required', style: TextStyle(color: Colors.pinkAccent)),
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
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
              child: const Text('Add Number', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
