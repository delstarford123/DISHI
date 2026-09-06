import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/theme/glass_card.dart';

class MatchCampusIdolView extends StatefulWidget {
  const MatchCampusIdolView({super.key});

  @override
  State<MatchCampusIdolView> createState() => _MatchCampusIdolViewState();
}

class _MatchCampusIdolViewState extends State<MatchCampusIdolView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _waveformController;
  
  bool _isRecording = false;
  double _recordingProgress = 0.0;
  Timer? _recordingTimer;
  
  String _selectedFilter = 'Normal';
  final List<String> _filters = ['Normal', 'Autotune 🎤', 'Deep 👹', 'Chipmunk 🐿️', 'Echo 🌊'];

  final List<Color> _coverColors = [Colors.blueAccent, Colors.purpleAccent, Colors.pinkAccent, Colors.orangeAccent, Colors.tealAccent];
  Color _selectedCover = Colors.blueAccent;

  String get currentUid => FirebaseAuth.instance.currentUser?.uid ?? 'guest';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _waveformController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _waveformController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordingProgress = 0.0;
    });
    
    // Simulate recording up to 10 seconds
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        setState(() {
          _recordingProgress += 0.01; // 100 * 0.01 = 1 second. So 1000 * 0.01 = 10s. 100ms * 100 = 10s. Wait, 0.01 per 100ms means 1.0 reached in 100 * 100ms = 10,000ms = 10s.
          if (_recordingProgress >= 1.0) {
            _stopRecording();
          }
        });
      }
    });
  }

  void _stopRecording() {
    _recordingTimer?.cancel();
    setState(() => _isRecording = false);
    
    if (_recordingProgress > 0.1) {
      _showUploadModal();
    } else {
      setState(() => _recordingProgress = 0.0);
    }
  }

  void _showUploadModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: Color(0xFF1E293B), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Publish Audition 🎤', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  const Text('Select Voice Filter', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      itemBuilder: (context, i) {
                        final f = _filters[i];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f, style: TextStyle(color: _selectedFilter == f ? Colors.black : Colors.white)),
                            selected: _selectedFilter == f,
                            selectedColor: Colors.blueAccent,
                            backgroundColor: Colors.black26,
                            onSelected: (val) => setModalState(() => _selectedFilter = f),
                          ),
                        );
                      }
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  const Text('Select Cover Color', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _coverColors.map((c) => GestureDetector(
                      onTap: () => setModalState(() => _selectedCover = c),
                      child: CircleAvatar(backgroundColor: c, radius: _selectedCover == c ? 20 : 15, child: _selectedCover == c ? const Icon(Icons.check, color: Colors.white) : null),
                    )).toList(),
                  ),
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      onPressed: () async {
                        Navigator.pop(context);
                        await FirebaseFirestore.instance.collection('campus_idols').add({
                          'uid': currentUid,
                          'filter': _selectedFilter,
                          'colorHex': _selectedCover.value,
                          'likes': 0,
                          'createdAt': FieldValue.serverTimestamp(),
                          'isAnonymous': true, // Photos hidden initially
                        });
                        setState(() => _recordingProgress = 0.0);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Audition published!')));
                      },
                      child: const Text('Submit Audition', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }
        );
      }
    );
  }

  void _turnChair(String docId, String creatorUid) {
    // Like logic
    FirebaseFirestore.instance.collection('campus_idols').doc(docId).update({'likes': FieldValue.increment(1)});
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: const Text('I WANT YOU! 🔴', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('You turned your chair for this voice!', style: TextStyle(color: Colors.white)),
            SizedBox(height: 16),
            Text('Identity Revealed:', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 8),
            CircleAvatar(radius: 40, backgroundColor: Colors.blueAccent, child: Icon(Icons.person, size: 40, color: Colors.white)),
            SizedBox(height: 8),
            Text('Alex (Engineering)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep Swiping')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opened Chat!'))); },
            child: const Text('Message', style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );
  }

  void _hitBuzzer() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buzzed! ❌ Next audition...')));
  }

  void _openComments(String docId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        height: 400,
        child: Column(
          children: [
            const Text('Audition Feedback', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: const [
                  ListTile(leading: CircleAvatar(backgroundColor: Colors.white12, child: Icon(Icons.person, color: Colors.white)), title: Text('Singing like an angel 😭', style: TextStyle(color: Colors.white))),
                  ListTile(leading: CircleAvatar(backgroundColor: Colors.white12, child: Icon(Icons.mic, color: Colors.orange)), title: Text('Audio Reply (Duet) 🎵', style: TextStyle(color: Colors.orange))),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(icon: const Icon(Icons.mic, color: Colors.orange), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recording Duet Reply...')))),
                Expanded(
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(hintText: 'Leave a comment...', hintStyle: const TextStyle(color: Colors.white38), filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send, color: Colors.blueAccent), onPressed: () => Navigator.pop(context)),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Campus Idol 🎤', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueAccent,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Blind Feed'),
            Tab(text: 'Studio'),
            Tab(text: 'Leaderboard'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(), // Custom scroll handling for feed
        children: [
          _buildBlindFeed(),
          _buildStudio(),
          _buildLeaderboard(),
        ],
      ),
    );
  }

  Widget _buildBlindFeed() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('campus_idols').orderBy('createdAt', descending: true).limit(10).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text('No auditions found. Be the first!', style: TextStyle(color: Colors.white54)));

        return PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final Color coverColor = data['colorHex'] != null ? Color(data['colorHex']) : Colors.blueAccent;
            
            return Container(
              color: Colors.black, // Dark backdrop
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Blurry Cover Art Background
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(colors: [coverColor.withOpacity(0.5), Colors.black], radius: 1.5),
                    ),
                  ),
                  
                  // Dynamic Waveform Visualizer
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.multotrack_audio, color: Colors.white, size: 80),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(15, (i) {
                          return AnimatedBuilder(
                            animation: _waveformController,
                            builder: (context, child) {
                              final height = 20.0 + (math.Random(i).nextDouble() * 60.0 * _waveformController.value);
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: 8, height: height,
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                              );
                            }
                          );
                        }),
                      ),
                      const SizedBox(height: 40),
                      if (data['filter'] != 'Normal')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                          child: Text('Filter: ${data['filter']}', style: const TextStyle(color: Colors.white70)),
                        )
                    ],
                  ),
                  
                  // Interaction Overlay
                  Positioned(
                    right: 16, bottom: 100,
                    child: Column(
                      children: [
                        _buildSideAction(Icons.favorite, '${data['likes'] ?? 0}', Colors.white, () {}),
                        const SizedBox(height: 24),
                        _buildSideAction(Icons.chat_bubble, 'Reply', Colors.white, () => _openComments(doc.id)),
                        const SizedBox(height: 24),
                        _buildSideAction(Icons.share, 'Share', Colors.white, () {}),
                      ],
                    ),
                  ),
                  
                  // Judging Buttons
                  Positioned(
                    bottom: 32,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FloatingActionButton.large(
                          heroTag: 'buzzer_${doc.id}',
                          backgroundColor: Colors.red,
                          onPressed: _hitBuzzer,
                          child: const Icon(Icons.close, color: Colors.white, size: 40),
                        ),
                        const SizedBox(width: 40),
                        FloatingActionButton.large(
                          heroTag: 'turn_${doc.id}',
                          backgroundColor: Colors.blueAccent,
                          onPressed: () => _turnChair(doc.id, data['uid']),
                          child: const Icon(Icons.chair, color: Colors.white, size: 40),
                        )
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildSideAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStudio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Record your 10s Audition', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text('Hold the mic to record. Your photos will be hidden until someone matches you!', style: TextStyle(color: Colors.white54), textAlign: TextAlign.center),
          const SizedBox(height: 40),
          
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 160, height: 160,
                child: CircularProgressIndicator(value: _recordingProgress, backgroundColor: Colors.white12, color: Colors.redAccent, strokeWidth: 8),
              ),
              GestureDetector(
                onLongPressStart: (_) => _startRecording(),
                onLongPressEnd: (_) => _stopRecording(),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: _isRecording ? Colors.redAccent : Colors.white12,
                  child: Icon(Icons.mic, size: 60, color: _isRecording ? Colors.white : Colors.blueAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          if (_recordingProgress > 0)
            Text('${(_recordingProgress * 10).toStringAsFixed(1)}s / 10s', style: const TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold))
          else
            const Text('HOLD TO RECORD', style: TextStyle(color: Colors.white38, letterSpacing: 2, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLeaderboard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('campus_idols').orderBy('likes', descending: true).limit(10).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final isAnonymous = data['isAnonymous'] ?? true;
            
            return GlassCard(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              borderRadius: 12,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isAnonymous ? Colors.black26 : Colors.blueAccent,
                  child: isAnonymous ? Text('#${index+1}', style: const TextStyle(color: Colors.white)) : const Icon(Icons.person, color: Colors.white),
                ),
                title: Text(isAnonymous ? 'Anonymous Voice #${index+1}' : 'Alex', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('Filter: ${data['filter']}', style: const TextStyle(color: Colors.white54)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${data['likes']} ', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                    const Icon(Icons.favorite, color: Colors.redAccent, size: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
