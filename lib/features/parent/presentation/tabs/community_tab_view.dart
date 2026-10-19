import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _textSecondary = Color(0xFF8B9BB4);

class CommunityTabView extends StatefulWidget {
  final Map<String, dynamic> user;
  
  const CommunityTabView({super.key, required this.user});

  @override
  State<CommunityTabView> createState() => _CommunityTabViewState();
}

class _CommunityTabViewState extends State<CommunityTabView> {
  final Set<String> _expandedPosts = {};
  final Map<String, TextEditingController> _replyControllers = {};
  final Map<String, bool> _isSubmittingReply = {};

  @override
  void dispose() {
    for (var controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    DateTime dt;
    if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    } else if (timestamp is String) {
      dt = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else {
      return 'Recently';
    }
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM yyyy, h:mm a').format(dt);
  }

  Future<bool> _checkRateLimit() async {
    final prefs = await SharedPreferences.getInstance();
    final lastPostTime = prefs.getInt('last_forum_post_time') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    if (now - lastPostTime < 30000) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please wait a moment between posts to prevent spam.'), backgroundColor: Colors.orange)
        );
      }
      return false;
    }
    
    await prefs.setInt('last_forum_post_time', now);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bgColor,
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              indicatorColor: _neonBlue,
              labelColor: _neonBlue,
              unselectedLabelColor: _textSecondary,
              tabs: [
                Tab(text: 'Forum'),
                Tab(text: 'Calendar'),
                Tab(text: 'P2P Transfer'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildForumView(),
                  _buildCalendarView(),
                  _buildP2pTransferView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForumView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('forums').orderBy('createdAt', descending: true).limit(30).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _neonBlue));
        }

        final docs = snapshot.data?.docs ?? [];
        
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_cardColor, _neonBlue.withOpacity(0.12)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _neonBlue.withOpacity(0.3), width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _neonBlue.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.forum_rounded, color: _neonBlue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Parent Community Forum', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 2),
                        Text('Share parenting tips, school updates & advice', style: TextStyle(color: _textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddPostDialog(context),
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text('Post'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                ],
              ),
            ),
            if (docs.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, size: 48, color: _neonCyan.withOpacity(0.4)),
                    const SizedBox(height: 12),
                    const Text('No Discussions Yet', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('Be the first parent to share advice or ask a question!', textAlign: TextAlign.center, style: TextStyle(color: _textSecondary, fontSize: 13)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showAddPostDialog(context),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Start First Discussion'),
                      style: ElevatedButton.styleFrom(backgroundColor: _neonBlue, foregroundColor: Colors.white),
                    )
                  ],
                ),
              ),
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final int replyCount = (data['replyCount'] is num) ? (data['replyCount'] as num).toInt() : 0;
              return _buildForumPost(
                doc.id,
                data['title'] ?? 'No Title',
                data['content'] ?? '',
                data['authorName'] ?? 'Parent',
                _formatTimestamp(data['createdAt']),
                data['authorUid'] ?? '',
                replyCount,
              );
            }),
            const SizedBox(height: 40),
          ],
        );
      }
    );
  }

  void _showAddPostDialog(BuildContext context) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: _neonBlue.withOpacity(0.4))),
        title: const Row(
          children: [
            Icon(Icons.add_comment_rounded, color: _neonCyan, size: 22),
            SizedBox(width: 8),
            Text('New Discussion', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Topic / Question',
                labelStyle: const TextStyle(color: _neonCyan),
                filled: true,
                fillColor: _surfaceLight,
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _neonCyan.withOpacity(0.4))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _neonCyan)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: contentController,
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Details / Description',
                labelStyle: const TextStyle(color: _neonCyan),
                filled: true,
                fillColor: _surfaceLight,
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _neonCyan.withOpacity(0.4))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _neonCyan)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final content = contentController.text.trim();
              if (title.isEmpty || content.isEmpty) return;
              
              if (!await _checkRateLimit()) return;
              
              try {
                final currentAuthUser = FirebaseAuth.instance.currentUser;
                final authorName = widget.user['name'] ?? widget.user['displayName'] ?? currentAuthUser?.displayName ?? 'Parent';
                await FirebaseFirestore.instance.collection('forums').add({
                  'title': title,
                  'content': content,
                  'authorUid': currentAuthUser?.uid ?? '',
                  'authorName': authorName,
                  'createdAt': FieldValue.serverTimestamp(),
                  'replyCount': 0,
                });
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _neonBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Post Discussion', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  Widget _buildForumPost(
    String docId,
    String title,
    String content,
    String author,
    String time,
    String authorUid,
    int replyCount,
  ) {
    final bool canDelete = authorUid == FirebaseAuth.instance.currentUser?.uid;
    final bool isExpanded = _expandedPosts.contains(docId);
    final String initial = author.trim().isNotEmpty ? author.trim()[0].toUpperCase() : 'P';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? _neonBlue.withOpacity(0.5) : Colors.white.withOpacity(0.08),
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: isExpanded
            ? [BoxShadow(color: _neonBlue.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedPosts.remove(docId);
                } else {
                  _expandedPosts.add(docId);
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author & timestamp row
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: _neonBlue.withOpacity(0.2),
                        child: Text(
                          initial,
                          style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    author,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: _neonCyan.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: _neonCyan.withOpacity(0.4), width: 0.8),
                                  ),
                                  child: const Text('Parent', style: TextStyle(color: _neonCyan, fontSize: 9.5, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(time, style: const TextStyle(color: _textSecondary, fontSize: 11)),
                          ],
                        ),
                      ),
                      if (canDelete)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 19),
                          tooltip: 'Delete post',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: _cardColor,
                                title: const Text('Delete Post?', style: TextStyle(color: Colors.white)),
                                content: const Text('Are you sure you want to delete this discussion?', style: TextStyle(color: _textSecondary)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await FirebaseFirestore.instance.collection('forums').doc(docId).delete();
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, height: 1.3),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    content,
                    style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isExpanded ? _neonBlue.withOpacity(0.18) : Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isExpanded ? _neonBlue.withOpacity(0.4) : Colors.white12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 14, color: isExpanded ? _neonCyan : _textSecondary),
                            const SizedBox(width: 5),
                            Text(
                              replyCount == 0 ? 'No replies' : '$replyCount ${replyCount == 1 ? "reply" : "replies"}',
                              style: TextStyle(
                                color: isExpanded ? _neonCyan : _textSecondary,
                                fontSize: 12,
                                fontWeight: isExpanded ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            isExpanded ? 'Hide replies' : 'View replies',
                            style: TextStyle(
                              color: isExpanded ? _neonBlue : _textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(
                            isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            color: isExpanded ? _neonBlue : _textSecondary,
                            size: 18,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) _buildRepliesSection(docId, author),
        ],
      ),
    );
  }

  Widget _buildRepliesSection(String postId, String originalAuthor) {
    final controller = _replyControllers.putIfAbsent(postId, () => TextEditingController());
    final bool isSubmitting = _isSubmittingReply[postId] ?? false;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1424),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.forum_outlined, size: 14, color: _neonCyan),
              SizedBox(width: 6),
              Text(
                'Discussion Thread',
                style: TextStyle(color: _neonCyan, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('forums')
                .doc(postId)
                .collection('replies')
                .orderBy('createdAt', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _neonBlue, strokeWidth: 2))),
                );
              }
              final replies = snapshot.data?.docs ?? [];
              if (replies.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  alignment: Alignment.centerLeft,
                  child: const Text('No replies yet. Be the first to join this conversation below.', style: TextStyle(color: _textSecondary, fontSize: 12)),
                );
              }
              return Column(
                children: replies.map((replyDoc) {
                  final rData = replyDoc.data() as Map<String, dynamic>;
                  final rAuthor = rData['authorName'] ?? 'Parent';
                  final rContent = rData['content'] ?? '';
                  final rUid = rData['authorUid'] ?? '';
                  final isMe = rUid == FirebaseAuth.instance.currentUser?.uid;
                  final rTime = _formatTimestamp(rData['createdAt']);
                  final rInitial = rAuthor.isNotEmpty ? rAuthor[0].toUpperCase() : 'P';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _surfaceLight.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: _neonCyan.withOpacity(0.2),
                          child: Text(rInitial, style: const TextStyle(color: _neonCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    rAuthor,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 4),
                                    const Text('(You)', style: TextStyle(color: _neonCyan, fontSize: 10)),
                                  ],
                                  const SizedBox(width: 8),
                                  Text(rTime, style: const TextStyle(color: _textSecondary, fontSize: 10)),
                                  const Spacer(),
                                  if (isMe)
                                    GestureDetector(
                                      onTap: () async {
                                        await replyDoc.reference.delete();
                                        await FirebaseFirestore.instance.collection('forums').doc(postId).update({
                                          'replyCount': FieldValue.increment(-1),
                                        });
                                      },
                                      child: const Icon(Icons.close, size: 14, color: Colors.white38),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                rContent,
                                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 10),
          // Inline Reply Input
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: _surfaceLight,
                    borderRadius: BorderRadius.circular(21),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: TextField(
                    controller: controller,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Reply to $originalAuthor...',
                      hintStyle: const TextStyle(color: _textSecondary, fontSize: 12),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _submitReply(postId),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 42,
                width: 42,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [_neonBlue, _neonCyan]),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Icon(Icons.send_rounded, color: Colors.black, size: 18),
                  onPressed: isSubmitting ? null : () => _submitReply(postId),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submitReply(String postId) async {
    final controller = _replyControllers.putIfAbsent(postId, () => TextEditingController());
    final content = controller.text.trim();
    if (content.isEmpty) return;
    
    if (!await _checkRateLimit()) return;
    
    setState(() => _isSubmittingReply[postId] = true);
    
    try {
      final currentAuthUser = FirebaseAuth.instance.currentUser;
      final authorName = widget.user['name'] ?? widget.user['displayName'] ?? currentAuthUser?.displayName ?? 'Parent';
      
      await FirebaseFirestore.instance
          .collection('forums')
          .doc(postId)
          .collection('replies')
          .add({
        'content': content,
        'authorUid': currentAuthUser?.uid ?? '',
        'authorName': authorName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      await FirebaseFirestore.instance.collection('forums').doc(postId).update({
        'replyCount': FieldValue.increment(1),
        'lastRepliedAt': FieldValue.serverTimestamp(),
      });
      
      controller.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post reply: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingReply[postId] = false);
      }
    }
  }

  Widget _buildCalendarView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('events').orderBy('date', descending: false).limit(20).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _neonCyan));
        }

        final docs = snapshot.data?.docs ?? [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Upcoming Events', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (docs.isEmpty)
               const Text('No upcoming events found.', style: TextStyle(color: _textSecondary)),
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _buildEventCard(
                context,
                doc.id,
                data['title'] ?? 'Event', 
                data['dateStr'] ?? 'Upcoming', 
                data['location'] ?? 'TBD', 
                data['isSchool'] ?? true,
                data['creatorId'] ?? data['uid'] ?? '',
              );
            }),
          ],
        );
      }
    );
  }

    Widget _buildEventCard(BuildContext context, String docId, String title, String date, String location, bool isSchool, String creatorUid) {
      final bool canDelete = creatorUid == FirebaseAuth.instance.currentUser?.uid;
      
      return GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: _cardColor,
              title: Text(title, style: const TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date: $date', style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 8),
                  Text('Location: $location', style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 8),
                  Text('Type: ${isSchool ? 'School' : 'Family'}', style: const TextStyle(color: Colors.white)),
                ],
              ),
              actions: [
                if (canDelete)
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await FirebaseFirestore.instance.collection('events').doc(docId).delete();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event deleted')));
                      }
                    },
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: _neonBlue)),
                )
              ],
            )
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: (isSchool ? _neonBlue : _neonCyan).withOpacity(0.35), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: isSchool ? _neonBlue.withOpacity(0.2) : _neonCyan.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Text(isSchool ? 'School' : 'Family', style: TextStyle(color: isSchool ? _neonBlue : _neonCyan, fontSize: 10)),
              )
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, color: _textSecondary, size: 14),
              const SizedBox(width: 4),
              Text(date, style: const TextStyle(color: _textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on, color: _textSecondary, size: 14),
              const SizedBox(width: 4),
              Text(location, style: const TextStyle(color: _textSecondary, fontSize: 12)),
            ],
          )
        ],
      ),
      ),
    );
  }

  Widget _buildP2pTransferView() {
    final phoneController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    bool isProcessing = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Send Funds to Another Parent', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Chip in for gifts, carpools, or cover a friend\'s lunchbox instantly.', style: TextStyle(color: _textSecondary)),
              const SizedBox(height: 24),
              TextField(
                controller: phoneController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Parent Phone Number or Tag ID',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (Ksh)',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Note (e.g. Teacher Gift)',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isProcessing ? null : () async {
                    final phone = phoneController.text.trim();
                    final amountStr = amountController.text.trim();
                    if (phone.isEmpty || amountStr.isEmpty) return;
                    final amount = double.tryParse(amountStr);
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid amount')));
                      return;
                    }
                    
                    setState(() => isProcessing = true);
                    try {
                      final db = FirebaseFirestore.instance;
                      final parentRef = db.collection('users').doc(FirebaseAuth.instance.currentUser!.uid);
                      
                      final targetQuery = await db.collection('users').where('phone', isEqualTo: phone).limit(1).get();
                      if (targetQuery.docs.isEmpty) {
                        setState(() => isProcessing = false);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recipient not found.')));
                        return;
                      }
                      
                      final targetRef = db.collection('users').doc(targetQuery.docs.first.id);
                      
                      await db.runTransaction((transaction) async {
                        final parentSnap = await transaction.get(parentRef);
                        final targetSnap = await transaction.get(targetRef);
                        
                        final parentWallet = (parentSnap.data()?['walletBalance'] ?? 0.0) as num;
                        if (parentWallet < amount) {
                          throw Exception('Insufficient funds');
                        }
                        
                        final targetWallet = (targetSnap.data()?['walletBalance'] ?? 0.0) as num;
                        
                        transaction.update(parentRef, {'walletBalance': parentWallet - amount});
                        transaction.update(targetRef, {'walletBalance': targetWallet + amount});
                        
                        final txRef = db.collection('transactions').doc();
                        transaction.set(txRef, {
                          'type': 'p2p_transfer',
                          'senderUid': parentSnap.id,
                          'receiverUid': targetSnap.id,
                          'amount': amount,
                          'note': noteController.text.trim(),
                          'timestamp': FieldValue.serverTimestamp(),
                        });
                      });
                      
                      if (context.mounted) {
                        phoneController.clear();
                        amountController.clear();
                        noteController.clear();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfer successful!')));
                      }
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Transfer failed: $e')));
                    }
                    setState(() => isProcessing = false);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _neonBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: isProcessing 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                    : const Text('Send Funds', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              )
            ],
          ),
        );
      }
    );
  }
}
