import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../../core/services/vibe_service.dart';

const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonBlue = Color(0xFF00FFD1);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1E293B);

class MatchVibeInboxView extends StatefulWidget {
  const MatchVibeInboxView({super.key});

  @override
  State<MatchVibeInboxView> createState() => _MatchVibeInboxViewState();
}

class _MatchVibeInboxViewState extends State<MatchVibeInboxView> with SingleTickerProviderStateMixin {
  final VibeService _vibeService = VibeService();
  int _vibeScore = 0;
  Timer? _timer;
  
  late TabController _tabController;
  String _filter = 'All'; // All, Super, Expiring

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchVibeScore();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchVibeScore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists) {
      setState(() {
        _vibeScore = doc.data()?['vibeScore'] ?? 0;
      });
    }
  }

  String _getTimeRemaining(Timestamp? expiresAt) {
    if (expiresAt == null) return '';
    final now = DateTime.now();
    final expiration = expiresAt.toDate();
    if (now.isAfter(expiration)) return 'Expired';
    
    final diff = expiration.difference(now);
    if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m left';
    } else {
      return '${diff.inMinutes}m left';
    }
  }

  Future<void> _handleVibe(String vibeId, String action, {String? customReaction}) async {
    try {
      await _vibeService.respondToVibe(vibeId: vibeId, action: action);
      if (customReaction != null) {
        await FirebaseFirestore.instance.collection('vibes').doc(vibeId).update({'reaction': customReaction});
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'accept' ? 'Vibe Accepted! ${customReaction ?? ''}' : 'Vibe Passed.'),
          backgroundColor: action == 'accept' ? Colors.green : Colors.grey,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
  
  void _revealSecret(String vibeId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Reveal Secret Admirer?', style: TextStyle(color: Colors.white)),
        content: const Text('This will cost 50 DISHI Points to reveal their identity.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonPink),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('vibes').doc(vibeId).update({'isSecret': false});
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Identity Revealed! -50 Points')));
              }
            },
            child: const Text('Reveal (50 pts)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  void _undoPass(String vibeId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Undo Pass?', style: TextStyle(color: Colors.white)),
        content: const Text('Did you swipe left by mistake? Undo for 20 DISHI Points.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('vibes').doc(vibeId).update({'status': 'pending'});
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pass Undone! -20 Points')));
              }
            },
            child: const Text('Undo (20 pts)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  void _reportVibe(String vibeId) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vibe reported. Our team will review this shortly.')));
  }
  
  void _replyWithVoiceNote(String vibeId) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recording... (Voice Note Reply Mock)')));
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Vibe Check', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _neonPink,
          labelColor: _neonPink,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Inbox', icon: Icon(Icons.inbox)),
            Tab(text: 'Archive', icon: Icon(Icons.history)),
            Tab(text: 'Stats', icon: Icon(Icons.bar_chart)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInboxTab(uid),
          _buildArchiveTab(uid),
          _buildStatsTab(),
        ],
      ),
    );
  }

  Widget _buildInboxTab(String uid) {
    return Column(
      children: [
        // Vibe Score / Streak
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [_neonPink, _neonBlue]), borderRadius: BorderRadius.circular(16)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Vibe Score', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('Total vibes sent & received', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              Text('$_vibeScore 🔥', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        
        // Filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: ['All', 'Super', 'Expiring'].map((f) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(f, style: TextStyle(color: _filter == f ? Colors.black : Colors.white)),
                selected: _filter == f,
                selectedColor: _neonBlue,
                backgroundColor: _surfaceLight,
                onSelected: (v) => setState(() => _filter = f),
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Inbox Stream
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('vibes').where('receiverId', isEqualTo: uid).where('status', isEqualTo: 'pending').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _neonPink));
              
              var docs = snapshot.data?.docs ?? [];
              
              if (_filter == 'Super') docs = docs.where((d) => (d.data() as Map)['isSuper'] == true).toList();
              if (_filter == 'Expiring') {
                docs = docs.where((d) {
                  final exp = (d.data() as Map)['expiresAt'] as Timestamp?;
                  if (exp == null) return false;
                  final diff = exp.toDate().difference(DateTime.now());
                  return diff.inHours < 24 && !diff.isNegative;
                }).toList();
              }

              if (docs.isEmpty) {
                return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inbox, color: Colors.white24, size: 64), SizedBox(height: 16), Text('No pending vibes.', style: TextStyle(color: Colors.white54))]));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final docId = docs[index].id;
                  
                  final isSuper = data['isSuper'] == true;
                  final isSecret = data['isSecret'] == true;
                  final expiresAt = data['expiresAt'] as Timestamp?;
                  final streak = data['streak'] ?? 0;
                  
                  final timeRemaining = _getTimeRemaining(expiresAt);
                  final isExpired = timeRemaining == 'Expired';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16), border: isSuper ? Border.all(color: Colors.amber, width: 2) : Border.all(color: Colors.white10), boxShadow: isSuper ? [BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 10)] : []),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: _surfaceLight,
                                    backgroundImage: (!isSecret && data['senderAvatar'] != null && data['senderAvatar'].isNotEmpty) ? NetworkImage(data['senderAvatar']) : null,
                                    child: isSecret ? const Icon(Icons.help_outline, color: _neonPink) : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(isSecret ? 'Someone' : data['senderName'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                          if (isSuper) ...[const SizedBox(width: 4), const Icon(Icons.star, color: Colors.amber, size: 14)]
                                        ],
                                      ),
                                      if (isSecret) const Text('Secret Admirer', style: TextStyle(color: _neonPink, fontSize: 12)),
                                      if (!isSecret && streak > 2) Text('Vibe Streak: 🔥 $streak', style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  if (isSecret)
                                    IconButton(icon: const Icon(Icons.visibility, color: _neonBlue, size: 20), onPressed: () => _revealSecret(docId), tooltip: 'Reveal Identity'),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: Colors.white54),
                                    color: _surfaceLight,
                                    onSelected: (val) { if (val == 'report') _reportVibe(docId); },
                                    itemBuilder: (ctx) => [const PopupMenuItem(value: 'report', child: Text('Report Vibe', style: TextStyle(color: Colors.redAccent)))],
                                  ),
                                ],
                              )
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: isExpired ? Colors.red.withOpacity(0.2) : _surfaceLight, borderRadius: BorderRadius.circular(12)),
                                child: Row(children: [Icon(Icons.timer, color: isExpired ? Colors.red : Colors.white54, size: 12), const SizedBox(width: 4), Text(timeRemaining, style: TextStyle(color: isExpired ? Colors.red : Colors.white54, fontSize: 10))]),
                              ),
                            ],
                          ),
                          if (data['icebreaker'] != null && data['icebreaker'].toString().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(8)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Icebreaker', style: TextStyle(color: _neonBlue, fontSize: 10, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('"${data['icebreaker']}"', style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic)),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          if (!isExpired)
                            Row(
                              children: [
                                Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24)), onPressed: () => _handleVibe(docId, 'reject'), child: const Text('Pass', style: TextStyle(color: Colors.white54)))),
                                const SizedBox(width: 8),
                                Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _neonPink), onPressed: () => _handleVibe(docId, 'accept'), child: const Text('Accept', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
                                const SizedBox(width: 8),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.add_reaction, color: Colors.amber),
                                  color: _surfaceLight,
                                  onSelected: (val) => _handleVibe(docId, 'accept', customReaction: val),
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(value: '🔥', child: Text('🔥 Fire', style: TextStyle(color: Colors.white))),
                                    const PopupMenuItem(value: '❤️', child: Text('❤️ Heart', style: TextStyle(color: Colors.white))),
                                    const PopupMenuItem(value: '👻', child: Text('👻 Ghost', style: TextStyle(color: Colors.white))),
                                  ],
                                ),
                                IconButton(icon: const Icon(Icons.mic, color: _neonBlue), onPressed: () => _replyWithVoiceNote(docId)),
                              ],
                            )
                          else
                            const Center(child: Text('This vibe has expired.', style: TextStyle(color: Colors.redAccent)))
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildArchiveTab(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('vibes').where('receiverId', isEqualTo: uid).where('status', whereIn: ['accepted', 'rejected']).orderBy('createdAt', descending: true).limit(30).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: _neonPink));
        
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('Archive is empty.', style: TextStyle(color: Colors.white54)));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            final isAccepted = data['status'] == 'accepted';
            final reaction = data['reaction'];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  CircleAvatar(backgroundColor: _surfaceLight, child: Icon(isAccepted ? Icons.check : Icons.close, color: isAccepted ? Colors.greenAccent : Colors.redAccent)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vibe from ${data['isSecret'] == true ? 'Secret Admirer' : data['senderName']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text(isAccepted ? 'You vibed back ${reaction != null ? reaction : ''}' : 'You passed', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (!isAccepted)
                    IconButton(icon: const Icon(Icons.undo, color: Colors.amber), onPressed: () => _undoPass(docId), tooltip: 'Undo Pass')
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Vibe Leaderboard 🏆', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildLeaderboardRow(1, 'Sarah K.', 1240),
        _buildLeaderboardRow(2, 'David N.', 980),
        _buildLeaderboardRow(3, 'You', _vibeScore, isMe: true),
        
        const SizedBox(height: 32),
        const Text('Your Vibe Statistics 📊', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
          child: const Column(
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Most Active Day:', style: TextStyle(color: Colors.white54)), Text('Friday 🔥', style: TextStyle(color: _neonPink, fontWeight: FontWeight.bold))]),
              Divider(color: Colors.white10, height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Total Super Vibes:', style: TextStyle(color: Colors.white54)), Text('14 ⭐', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))]),
              Divider(color: Colors.white10, height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Longest Streak:', style: TextStyle(color: Colors.white54)), Text('12 Days 🔥', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold))]),
            ],
          ),
        )
      ],
    );
  }
  
  Widget _buildLeaderboardRow(int rank, String name, int score, {bool isMe = false}) {
    Color medalColor = rank == 1 ? Colors.amber : (rank == 2 ? Colors.grey.shade400 : Colors.brown.shade300);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: isMe ? _neonPink.withOpacity(0.2) : _cardColor, borderRadius: BorderRadius.circular(12), border: isMe ? Border.all(color: _neonPink) : null),
      child: Row(
        children: [
          Text('#$rank', style: TextStyle(color: medalColor, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 16),
          Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          Text('$score', style: const TextStyle(color: _neonBlue, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
