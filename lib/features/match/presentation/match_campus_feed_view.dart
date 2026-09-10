import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _textSecondary = Color(0xFF8B9BB4);

class MatchCampusFeedView extends StatefulWidget {
  const MatchCampusFeedView({super.key});

  @override
  State<MatchCampusFeedView> createState() => _MatchCampusFeedViewState();
}

class _MatchCampusFeedViewState extends State<MatchCampusFeedView> {
  final TextEditingController _postController = TextEditingController();
  bool _isPosting = false;

  String get _currentUid =>
      FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  Future<void> _createPost() async {
    final text = _postController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isPosting = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .get();
      final userData = userDoc.data() ?? {};
      final name = userData['name'] ??
          userData['firstName'] ??
          FirebaseAuth.instance.currentUser?.displayName ??
          'Campus Student';
      final avatar = userData['profileImageUrl'];

      await FirebaseFirestore.instance.collection('campus_feed').add({
        'uid': _currentUid,
        'author_id': _currentUid,
        'authorName': name,
        'authorAvatar': avatar,
        'content': text,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [],
        'commentCount': 0,
      });
      _postController.clear();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  void _showCreatePostSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('New Post',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _postController,
              autofocus: true,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "What's on your mind, comrade?",
                hintStyle: const TextStyle(color: _textSecondary),
                filled: true,
                fillColor: _surfaceLight,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isPosting ? null : _createPost,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _neonPink,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _isPosting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Post',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Campus Feed',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('campus_feed')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _neonPink));
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white54)));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline,
                      size: 64, color: _textSecondary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  const Text('No posts yet — be the first to post!',
                      style: TextStyle(color: _textSecondary, fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final post = docs[index].data() as Map<String, dynamic>;
              final postId = docs[index].id;
              return _PostCard(
                  postId: postId, post: post, currentUid: _currentUid);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _neonPink,
        onPressed: _showCreatePostSheet,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }
}

// ─── Post Card Widget ───────────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> post;
  final String currentUid;

  const _PostCard(
      {required this.postId, required this.post, required this.currentUid});

  Future<void> _toggleLike() async {
    final ref =
        FirebaseFirestore.instance.collection('campus_feed').doc(postId);
    final likes = List<String>.from(post['likes'] ?? []);
    if (likes.contains(currentUid)) {
      await ref.update({
        'likes': FieldValue.arrayRemove([currentUid])
      });
    } else {
      await ref.update({
        'likes': FieldValue.arrayUnion([currentUid])
      });
    }
  }

  void _showReplies(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131A2A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _RepliesSheet(postId: postId, currentUid: currentUid),
    );
  }

  @override
  Widget build(BuildContext context) {
    final likes = List<String>.from(post['likes'] ?? []);
    final isLiked = likes.contains(currentUid);
    final name = post['authorName'] ?? 'Campus Student';
    final content = post['content'] ?? '';
    final avatar = post['authorAvatar'] as String?;
    final ts = post['createdAt'] as Timestamp?;
    final timeAgo = ts != null
        ? _formatTime(ts.toDate())
        : 'Just now';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF131A2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF1A2235),
                backgroundImage:
                    avatar != null ? NetworkImage(avatar) : null,
                child: avatar == null
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                    Text(timeAgo,
                        style: const TextStyle(
                            color: _textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(content,
              style: const TextStyle(color: Colors.white, height: 1.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: _toggleLike,
                child: Row(
                  children: [
                    Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: _neonPink,
                        size: 20),
                    const SizedBox(width: 6),
                    Text('${likes.length}',
                        style: const TextStyle(color: _neonPink)),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: () => _showReplies(context),
                child: const Row(
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        color: _textSecondary, size: 20),
                    SizedBox(width: 6),
                    Text('Reply',
                        style: TextStyle(color: _textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─── Replies Bottom Sheet ───────────────────────────────────────────────────

class _RepliesSheet extends StatefulWidget {
  final String postId;
  final String currentUid;

  const _RepliesSheet({required this.postId, required this.currentUid});

  @override
  State<_RepliesSheet> createState() => _RepliesSheetState();
}

class _RepliesSheetState extends State<_RepliesSheet> {
  final TextEditingController _replyController = TextEditingController();
  bool _isSending = false;

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUid)
          .get();
      final userData = userDoc.data() ?? {};
      final name = userData['name'] ??
          userData['firstName'] ??
          FirebaseAuth.instance.currentUser?.displayName ??
          'Comrade';
      final avatar = userData['profileImageUrl'];

      final postRef = FirebaseFirestore.instance
          .collection('campus_feed')
          .doc(widget.postId);

      await postRef.collection('comments').add({
        'uid': widget.currentUid,
        'authorName': name,
        'authorAvatar': avatar,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await postRef.update(
          {'commentCount': FieldValue.increment(1)});
      _replyController.clear();
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (_, sc) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Replies',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('campus_feed')
                    .doc(widget.postId)
                    .collection('comments')
                    .orderBy('createdAt')
                    .snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                        child: Text('No replies yet. Be the first!',
                            style: TextStyle(color: _textSecondary)));
                  }
                  return ListView.builder(
                    controller: sc,
                    itemCount: docs.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, i) {
                      final c =
                          docs[i].data() as Map<String, dynamic>;
                      final avatar = c['authorAvatar'] as String?;
                      final name = c['authorName'] ?? 'Comrade';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFF1A2235),
                              backgroundImage: avatar != null
                                  ? NetworkImage(avatar)
                                  : null,
                              child: avatar == null
                                  ? Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12))
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: const Color(0xFF1A2235),
                                    borderRadius:
                                        BorderRadius.circular(12)),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight:
                                                FontWeight.bold,
                                            fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Text(c['text'] ?? '',
                                        style: const TextStyle(
                                            color: Colors.white70)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // Reply input
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Write a reply...',
                        hintStyle: const TextStyle(color: _textSecondary),
                        filled: true,
                        fillColor: const Color(0xFF1A2235),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isSending ? null : _sendReply,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                          color: _neonPink, shape: BoxShape.circle),
                      child: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send,
                              color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
