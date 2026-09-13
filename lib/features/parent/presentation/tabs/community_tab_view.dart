import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
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
  Set<String> _expandedPosts = {};

  Future<bool> _checkRateLimit() async {
    final prefs = await SharedPreferences.getInstance();
    final lastPostTime = prefs.getInt('last_forum_post_time') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    if (now - lastPostTime < 60000) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please wait 1 minute between posts/replies to prevent spam.'), backgroundColor: Colors.orange)
        );
      }
      return false;
    }
    
    await prefs.setInt('last_forum_post_time', now);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
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
    );
  }

  Widget _buildForumView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('forums').orderBy('createdAt', descending: true).limit(20).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _neonBlue));
        }

        final docs = snapshot.data?.docs ?? [];
        
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Parent Forum', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: () => _showAddPostDialog(context), 
                  icon: const Icon(Icons.edit, size: 16), 
                  label: const Text('Post'),
                  style: ElevatedButton.styleFrom(backgroundColor: _neonBlue),
                )
              ],
            ),
            const SizedBox(height: 16),
            if (docs.isEmpty)
               const Text('No forum posts yet. Be the first to start a discussion!', style: TextStyle(color: _textSecondary)),
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _buildForumPost(
                doc.id,
                data['title'] ?? 'No Title',
                data['content'] ?? '',
                data['authorName'] ?? 'Anonymous',
                'Recently',
                data['authorUid'] ?? '',
              );
            }),
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
        title: const Text('New Forum Post', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Title',
                labelStyle: const TextStyle(color: _neonCyan),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonCyan.withOpacity(0.5))),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _neonCyan)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Content',
                labelStyle: const TextStyle(color: _neonCyan),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonCyan.withOpacity(0.5))),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _neonCyan)),
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
                    await FirebaseFirestore.instance.collection('forums').add({
                      'title': title,
                      'content': content,
                      'authorUid': FirebaseAuth.instance.currentUser!.uid,
                      'authorName': widget.user['name'] ?? widget.user['displayName'] ?? 'Parent',
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
                style: ElevatedButton.styleFrom(backgroundColor: _neonBlue),
                child: const Text('Post', style: TextStyle(color: Colors.white)),
            )
          ],
        )
      );
    }

    Widget _buildForumPost(String docId, String title, String content, String author, String time, String authorUid) {
      final bool canDelete = authorUid == FirebaseAuth.instance.currentUser?.uid;
      final bool isExpanded = _expandedPosts.contains(docId);
      
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
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
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                        if (canDelete)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            onPressed: () async {
                              await FirebaseFirestore.instance.collection('forums').doc(docId).delete();
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(content, style: const TextStyle(color: _textSecondary)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$author • $time', style: const TextStyle(color: _neonCyan, fontSize: 12)),
                        const Row(
                          children: [
                            Icon(Icons.comment_outlined, color: _textSecondary, size: 16),
                            SizedBox(width: 4),
                            Text('Replies', style: TextStyle(color: _textSecondary, fontSize: 12)),
                          ],
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
            if (isExpanded)
              _buildRepliesSection(docId),
          ],
        ),
      );
    }

    Widget _buildRepliesSection(String postId) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: Column(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('forums')
                  .doc(postId)
                  .collection('replies')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: _neonBlue));
                }
                final replies = snapshot.data?.docs ?? [];
                if (replies.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('No replies yet.', style: TextStyle(color: _textSecondary, fontSize: 12)),
                  );
                }
                return Column(
                  children: replies.map((replyDoc) {
                    final rData = replyDoc.data() as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.subdirectory_arrow_right, color: _textSecondary, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(rData['content'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                const SizedBox(height: 2),
                                Text(rData['authorName'] ?? 'Anonymous', style: const TextStyle(color: _neonCyan, fontSize: 10)),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  }).toList(),
                );
              }
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showAddReplyDialog(context, postId),
                    icon: const Icon(Icons.reply, size: 16, color: _neonBlue),
                    label: const Text('Add Reply', style: TextStyle(color: _neonBlue)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _neonBlue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                    ),
                  ),
                )
              ],
            )
          ],
        ),
      );
    }

    void _showAddReplyDialog(BuildContext context, String postId) {
      final contentController = TextEditingController();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _cardColor,
          title: const Text('Add Reply', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: contentController,
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Type your reply...',
              hintStyle: const TextStyle(color: _textSecondary),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonCyan.withOpacity(0.5))),
              focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _neonCyan)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final content = contentController.text.trim();
                if (content.isEmpty) return;
                if (!await _checkRateLimit()) return;
                
                try {
                  await FirebaseFirestore.instance
                      .collection('forums')
                      .doc(postId)
                      .collection('replies')
                      .add({
                    'content': content,
                    'authorUid': FirebaseAuth.instance.currentUser!.uid,
                    'authorName': widget.user['name'] ?? widget.user['displayName'] ?? 'Parent',
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  await FirebaseFirestore.instance.collection('forums').doc(postId).update({
                    'replyCount': FieldValue.increment(1)
                  });
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _neonBlue),
              child: const Text('Reply', style: TextStyle(color: Colors.white)),
            )
          ],
        )
      );
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
            border: Border(left: BorderSide(color: isSchool ? _neonBlue : _neonCyan, width: 4)),
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
