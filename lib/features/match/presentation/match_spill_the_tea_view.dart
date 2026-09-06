import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/theme/glass_card.dart';

class MatchSpillTheTeaView extends StatefulWidget {
  const MatchSpillTheTeaView({super.key});

  @override
  State<MatchSpillTheTeaView> createState() => _MatchSpillTheTeaViewState();
}

class _MatchSpillTheTeaViewState extends State<MatchSpillTheTeaView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _postController = TextEditingController();
  final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _postController.dispose();
    super.dispose();
  }

  void _showNewPostModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Spill The Tea ☕', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Your post is completely anonymous. Keep it fun and respectful!', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 16),
                TextField(
                  controller: _postController,
                  maxLines: 4,
                  maxLength: 280,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Type your confession or missed connection...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      if (_postController.text.trim().isNotEmpty) {
                        _submitPost(_postController.text.trim());
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Post Anonymously', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Future<void> _submitPost(String text) async {
    _postController.clear();
    await FirebaseFirestore.instance.collection('campus_confessions').add({
      'text': text,
      'author_uid': currentUid,
      'university': 'Campus', // Could be dynamically fetched
      'vibe_count': 0,
      'cap_count': 0,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _vote(String docId, String voteType) async {
    final docRef = FirebaseFirestore.instance.collection('campus_confessions').doc(docId);
    final voteRef = docRef.collection('votes').doc(currentUid);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final voteDoc = await transaction.get(voteRef);
      final postDoc = await transaction.get(docRef);

      if (!postDoc.exists) return;

      int currentVibes = postDoc.data()?['vibe_count'] ?? 0;
      int currentCaps = postDoc.data()?['cap_count'] ?? 0;

      if (voteDoc.exists) {
        String existingVote = voteDoc.data()?['type'];
        if (existingVote == voteType) return; // Already voted this way
        
        // Changing vote
        if (existingVote == 'vibe') currentVibes--;
        if (existingVote == 'cap') currentCaps--;
      }

      if (voteType == 'vibe') currentVibes++;
      if (voteType == 'cap') currentCaps++;

      transaction.update(docRef, {'vibe_count': currentVibes, 'cap_count': currentCaps});
      transaction.set(voteRef, {'type': voteType, 'timestamp': FieldValue.serverTimestamp()});
    });
  }

  Widget _buildPostCard(Map<String, dynamic> data, String docId) {
    final int vibes = data['vibe_count'] ?? 0;
    final int caps = data['cap_count'] ?? 0;
    final String text = data['text'] ?? '';
    final Timestamp? timestamp = data['created_at'];
    final timeStr = timestamp != null ? _timeAgo(timestamp.toDate()) : 'Just now';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        blur: 20,
      opacity: 0.1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_outline, color: Colors.orangeAccent, size: 20),
                  const SizedBox(width: 8),
                  const Text('Anonymous Comrade', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              Text(timeStr, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildVoteButton(Icons.local_fire_department, 'Vibe', vibes, Colors.orangeAccent, () => _vote(docId, 'vibe')),
              const SizedBox(width: 16),
              _buildVoteButton(Icons.thumb_down_alt_outlined, 'Cap', caps, Colors.blueGrey, () => _vote(docId, 'cap')),
              const Spacer(),
              IconButton(icon: const Icon(Icons.share, color: Colors.white54, size: 20), onPressed: () {}),
            ],
          )
        ],
      ),
    ));
  }

  Widget _buildVoteButton(IconData icon, String label, int count, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(count > 0 ? '$count $label' : label, style: TextStyle(color: count > 0 ? color : Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime d) {
    Duration diff = DateTime.now().difference(d);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Spill The Tea ☕', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orangeAccent,
          labelColor: Colors.orangeAccent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Recent'),
            Tab(text: 'Trending 🔥'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFeed(false), // Recent
          _buildFeed(true),  // Trending
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewPostModal,
        backgroundColor: Colors.orangeAccent,
        icon: const Icon(Icons.edit, color: Colors.white),
        label: const Text('Spill', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFeed(bool isTrending) {
    Query query = FirebaseFirestore.instance.collection('campus_confessions');
    
    if (isTrending) {
      query = query.orderBy('vibe_count', descending: true).limit(50);
    } else {
      query = query.orderBy('created_at', descending: true).limit(50);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.orangeAccent));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.coffee_outlined, color: Colors.white.withOpacity(0.2), size: 64),
                const SizedBox(height: 16),
                const Text('No tea spilled yet.', style: TextStyle(color: Colors.white54, fontSize: 16)),
                const Text('Be the first to confess!', style: TextStyle(color: Colors.white38, fontSize: 14)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16).copyWith(bottom: 100),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            return _buildPostCard(doc.data() as Map<String, dynamic>, doc.id);
          },
        );
      },
    );
  }
}
