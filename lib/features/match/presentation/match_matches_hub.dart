import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'match_chat_view.dart';
import 'match_call_view.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonPink = Color(0xFFF92B60);
const Color _textSecondary = Color(0xFF8B9BB4);

class MatchMatchesHub extends StatefulWidget {
  const MatchMatchesHub({super.key});

  @override
  State<MatchMatchesHub> createState() => _MatchMatchesHubState();
}

class _MatchMatchesHubState extends State<MatchMatchesHub> {
  final String _currentUid = FirebaseAuth.instance.currentUser?.uid ?? 'my_uid';
  List<Map<String, dynamic>> _matches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMatches();
  }

  Future<void> _fetchMatches() async {
    try {
      // In a real scenario, this would query a 'matches' subcollection or connection documents.
      // For now, we fetch a few users to simulate active matches.
      final snapshot = await FirebaseFirestore.instance.collection('users')
        .limit(10)
        .get();

      final profiles = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .where((user) {
             final email = (user['email'] as String?)?.toLowerCase() ?? '';
             final roles = user['roles'] as List<dynamic>? ?? [];
             final isTestAccount = user['isTestAccount'] == true || email.contains('test') || roles.contains('test');
             return user['id'] != _currentUid && !isTestAccount;
          })
          .toList();

      if (mounted) {
        setState(() {
          _matches = profiles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Matches & Chats', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: _neonPink))
        : _matches.isEmpty 
          ? _buildEmptyState()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNewMatchesSection(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text('Messages', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _matches.length,
                    separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 24),
                    itemBuilder: (context, index) {
                      return _buildChatTile(_matches[index]);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline, color: _textSecondary, size: 64),
          const SizedBox(height: 16),
          const Text('No matches yet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Start swiping to connect with students!', style: TextStyle(color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _buildNewMatchesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('New Matches', style: TextStyle(color: _neonPink, fontSize: 14, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _matches.length > 5 ? 5 : _matches.length,
            itemBuilder: (context, index) {
              final user = _matches[index];
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchChatView(chatId: '${_currentUid}_${user['id']}', myUid: _currentUid, matchName: user['displayName'] ?? 'Student', matchAvatar: user['profileImageUrl']))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _neonPink, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: _surfaceLight,
                          backgroundImage: (user['profileImageUrl'] != null && user['profileImageUrl'].isNotEmpty) 
                              ? NetworkImage(user['profileImageUrl']) 
                              : null,
                          child: (user['profileImageUrl'] == null || user['profileImageUrl'].isEmpty)
                              ? const Icon(Icons.person, color: _textSecondary)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text((user['displayName'] ?? 'Student').split(' ')[0], style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(color: Colors.white12, height: 1),
      ],
    );
  }

  Widget _buildChatTile(Map<String, dynamic> user) {
    String name = user['displayName'] ?? 'Student';
    String? avatar = user['profileImageUrl'];
    
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: _surfaceLight,
        backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
        child: (avatar == null || avatar.isEmpty) ? const Icon(Icons.person, color: _textSecondary) : null,
      ),
      title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      subtitle: const Text('Tap to chat...', style: TextStyle(color: _textSecondary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.videocam, color: _neonCyan),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => MatchCallView(
                userName: name,
                userAvatar: avatar ?? '',
                isVideoCall: true,
                isIncoming: false,
              )));
            },
          ),
        ],
      ),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => MatchChatView(
          chatId: '${_currentUid}_${user['id']}', 
          myUid: _currentUid,
          matchName: name,
          matchAvatar: avatar,
        )));
      },
    );
  }
}
