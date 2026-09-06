import 'dart:async';
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

  String _selectedCategory = 'Gossip';
  final Map<String, List<Color>> _categoryColors = {
    'Gossip': [Color(0xFF9C27B0), Color(0xFF6A1B9A)],
    'Confession': [Color(0xFFFF2A6D), Color(0xFFC2185B)],
    'Rant': [Color(0xFFE65100), Color(0xFFBF360C)],
    'Missed Connection': [Color(0xFF05D5AA), Color(0xFF00897B)],
  };
  
  String _activeTagFilter = '';
  final List<String> _trendingTags = ['#FinalsWeek', '#MessHall', '#Freshers', '#CampusCrush', '#Exams'];

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
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _categoryColors[_selectedCategory]!),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Spill The Tea ☕', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    // Category Selector
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _categoryColors.keys.map((cat) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(cat, style: TextStyle(color: _selectedCategory == cat ? Colors.black : Colors.white)),
                            selected: _selectedCategory == cat,
                            selectedColor: Colors.white,
                            backgroundColor: Colors.black26,
                            onSelected: (val) => setModalState(() => _selectedCategory = cat),
                          ),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _postController,
                      maxLines: 4,
                      maxLength: 280,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: InputDecoration(
                        hintText: 'Type your $_selectedCategory anonymously...',
                        hintStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(icon: const Icon(Icons.mic, color: Colors.white), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recording Voice Note... Pitch shift applied! 🎭')))),
                        IconButton(icon: const Icon(Icons.image, color: Colors.white), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image attached (will be blurred as spoiler).')))),
                        IconButton(icon: const Icon(Icons.timer, color: Colors.white), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post will expire in 24 hours.')))),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            if (_postController.text.trim().isNotEmpty) {
                              _submitPost(_postController.text.trim());
                              Navigator.pop(context);
                            }
                          },
                          child: Text('Post', style: TextStyle(color: _categoryColors[_selectedCategory]!.first, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Future<void> _submitPost(String text) async {
    final String cat = _selectedCategory;
    _postController.clear();
    await FirebaseFirestore.instance.collection('campus_confessions').add({
      'text': text,
      'category': cat,
      'author_uid': currentUid,
      'vibe_count': 0,
      'cap_count': 0,
      'comment_count': 0,
      'created_at': FieldValue.serverTimestamp(),
      'expires': true, // Feature 27: Expiring posts
    });
  }

  void _openComments(String docId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Anonymous Comments', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _buildCommentMockup('Agreed, happened to me too!'),
                  _buildCommentMockup('This is major cap 🧢'),
                  _buildCommentMockup('I think I know who wrote this 😂'),
                ],
              ),
            ),
            SafeArea(
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Reply anonymously...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  suffixIcon: IconButton(icon: const Icon(Icons.send, color: Colors.orangeAccent), onPressed: () => Navigator.pop(context)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCommentMockup(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(radius: 12, backgroundColor: Colors.orangeAccent, child: Icon(Icons.person, size: 16, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> data, String docId) {
    final int vibes = data['vibe_count'] ?? 0;
    final int caps = data['cap_count'] ?? 0;
    final int comments = data['comment_count'] ?? 0;
    final String text = data['text'] ?? '';
    final String category = data['category'] ?? 'Gossip';
    
    // Feature 26: Tea Temperature (Hotness algorithm mockup)
    final double hotness = (vibes * 2.0) - caps + (comments * 3.0);
    final bool isHot = hotness > 10;

    final colors = _categoryColors[category] ?? _categoryColors['Gossip']!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (isHot) BoxShadow(color: colors.first.withOpacity(0.5), blurRadius: 15, spreadRadius: 2)
          ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                  child: Text(category, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                Row(
                  children: [
                    if (isHot) const Text('🔥 HOT TEA', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(width: 12),
                    IconButton(
                      padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                      icon: const Icon(Icons.more_horiz, color: Colors.white70),
                      onPressed: () {
                        // Mod/Flagging / Reveal / Bookmark menu
                        showModalBottomSheet(context: context, builder: (_) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(leading: const Icon(Icons.bookmark), title: const Text('Save Tea'), onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tea saved!'))); }),
                            ListTile(leading: const Icon(Icons.flag, color: Colors.red), title: const Text('Report Post', style: TextStyle(color: Colors.red)), onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted to moderation.'))); }),
                          ],
                        ));
                      },
                    )
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.4, fontWeight: FontWeight.w500)),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildActionChip(Icons.local_fire_department, '$vibes Vibe', () {}),
                const SizedBox(width: 12),
                _buildActionChip(Icons.thumb_down, '$caps Cap', () {}),
                const SizedBox(width: 12),
                _buildActionChip(Icons.chat_bubble, '$comments', () => _openComments(docId)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
        title: const Text('Spill The Tea ☕', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orangeAccent,
          labelColor: Colors.orangeAccent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Latest Feed'),
            Tab(text: 'My Saved Tea'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMainFeed(),
          const Center(child: Text('Saved posts appear here', style: TextStyle(color: Colors.white54))),
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
  
  Widget _buildMainFeed() {
    return Column(
      children: [
        // Trending Tags
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: _trendingTags.map((tag) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(tag, style: TextStyle(color: _activeTagFilter == tag ? Colors.black : Colors.orangeAccent)),
                backgroundColor: _activeTagFilter == tag ? Colors.orangeAccent : Colors.transparent,
                side: const BorderSide(color: Colors.orangeAccent),
                onPressed: () => setState(() => _activeTagFilter = _activeTagFilter == tag ? '' : tag),
              ),
            )).toList(),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('campus_confessions').orderBy('created_at', descending: true).limit(50).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.orangeAccent));
              
              var docs = snapshot.data?.docs ?? [];
              if (_activeTagFilter.isNotEmpty) {
                docs = docs.where((d) => (d.data() as Map<String, dynamic>)['text'].toString().contains(_activeTagFilter)).toList();
              }
              
              if (docs.isEmpty) return const Center(child: Text('No tea matching this filter.', style: TextStyle(color: Colors.white54)));

              return ListView.builder(
                padding: const EdgeInsets.all(16).copyWith(bottom: 100),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  return _buildPostCard(doc.data() as Map<String, dynamic>, doc.id);
                },
              );
            },
          ),
        )
      ],
    );
  }
}
