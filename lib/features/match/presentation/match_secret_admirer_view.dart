import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/theme/glass_card.dart';
import 'match_chat_view.dart';

class MatchSecretAdmirerView extends StatefulWidget {
  final Map<String, dynamic>? userModel;
  const MatchSecretAdmirerView({super.key, this.userModel});

  @override
  State<MatchSecretAdmirerView> createState() => _MatchSecretAdmirerViewState();
}

class _MatchSecretAdmirerViewState extends State<MatchSecretAdmirerView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  
  List<DocumentSnapshot> _searchResults = [];
  bool _isSearching = false;

  final List<String> _eCardTemplates = [
    'None', 'Are you a library book? Because I am checking you out.',
    'Is your name Google? Because you have everything I am searching for.',
    'Are you made of Copper and Tellurium? Because you are CuTe.'
  ];
  String _selectedECard = 'None';

  String get currentUid => FirebaseAuth.instance.currentUser?.uid ?? 'guest';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _searchStudents(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    
    // In a real app, use Algolia. For now, simple prefix match on firstName
    try {
      final snap = await FirebaseFirestore.instance.collection('users')
          .where('firstName', isGreaterThanOrEqualTo: query)
          .where('firstName', isLessThan: '${query}z')
          .limit(10)
          .get();
          
      if (mounted) {
        setState(() {
          _searchResults = snap.docs.where((d) => d.id != currentUid).toList();
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _openSendModal(DocumentSnapshot targetUser) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
              decoration: const BoxDecoration(color: Color(0xFF1E293B), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Send Secret Crush 💌', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Sending to ${targetUser['firstName']} anonymously.', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  
                  const Text('Attach an E-Card (Optional)', style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _eCardTemplates.length,
                      itemBuilder: (context, i) {
                        final ecard = _eCardTemplates[i];
                        final isSel = ecard == _selectedECard;
                        return GestureDetector(
                          onTap: () => setModalState(() => _selectedECard = ecard),
                          child: Container(
                            width: 120,
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSel ? Colors.pinkAccent.withOpacity(0.2) : Colors.black26,
                              border: Border.all(color: isSel ? Colors.pinkAccent : Colors.transparent),
                              borderRadius: BorderRadius.circular(12)
                            ),
                            child: Center(child: Text(ecard, style: TextStyle(color: isSel ? Colors.pinkAccent : Colors.white70, fontSize: 10), textAlign: TextAlign.center)),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _messageController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Or write your own secret message...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      onPressed: () {
                        _sendCrush(targetUser.id);
                        Navigator.pop(context);
                      },
                      child: const Text('Send Anonymously', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Future<void> _sendCrush(String targetUid) async {
    final msg = _messageController.text.trim();
    if (msg.isEmpty && _selectedECard == 'None') return;
    
    // Check for Mutual Crush Auto-Reveal
    final mutualSnap = await FirebaseFirestore.instance.collection('secret_crushes')
        .where('senderUid', isEqualTo: targetUid)
        .where('recipientUid', isEqualTo: currentUid)
        .where('status', isEqualTo: 'sent')
        .get();

    if (mutualSnap.docs.isNotEmpty) {
      // Mutual Crush!
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF131A2A),
          title: const Text('MUTUAL CRUSH! 💖', style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
          content: const Text('Omg! They actually sent you a secret crush too! Identities have been revealed. Go chat with them!'),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
              onPressed: () => Navigator.pop(context), 
              child: const Text('Nice!', style: TextStyle(color: Colors.white))
            )
          ],
        )
      );
      
      // Update theirs to revealed
      await mutualSnap.docs.first.reference.update({'status': 'revealed'});
      
      // Save ours as revealed
      await FirebaseFirestore.instance.collection('secret_crushes').add({
        'senderUid': currentUid,
        'recipientUid': targetUid,
        'message': msg,
        'ecard': _selectedECard,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'revealed', 
      });
      
    } else {
      // Normal Send
      await FirebaseFirestore.instance.collection('secret_crushes').add({
        'senderUid': currentUid,
        'recipientUid': targetUid,
        'message': msg,
        'ecard': _selectedECard,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent', 
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Crush sent anonymously!')));
    }
    
    _messageController.clear();
    setState(() => _selectedECard = 'None');
  }

  Future<void> _retractCrush(String docId) async {
    await FirebaseFirestore.instance.collection('secret_crushes').doc(docId).delete();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Crush retracted.')));
  }

  void _playGuessWho(DocumentSnapshot crushDoc) {
    // Premium users bypass
    if (widget.userModel?['isPremium'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Premium Reveal: Identity Unlocked! 💎')));
      crushDoc.reference.update({'status': 'revealed'});
      return;
    }

    // Guess Who Mini-game
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: const Text('Guess Who? 🤔', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('One of these 3 people sent you this crush. Guess correctly to reveal them!', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(3, (index) => GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  // 1 in 3 chance of getting it right for demo purposes
                  if (math.Random().nextInt(3) == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You guessed right! Identity Revealed!')));
                    crushDoc.reference.update({'status': 'revealed'});
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wrong guess! Better luck next time.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
                  }
                },
                child: const CircleAvatar(radius: 30, backgroundColor: Colors.white10, child: Icon(Icons.person, color: Colors.white38)),
              )),
            )
          ],
        ),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Secret Admirer 💌', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.pinkAccent,
          labelColor: Colors.pinkAccent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Directory'),
            Tab(text: 'Inbox'),
            Tab(text: 'Outbox'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDirectoryTab(),
          _buildInboxTab(),
          _buildOutboxTab(),
        ],
      ),
    );
  }

  Widget _buildDirectoryTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search for a student...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.black26,
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            onChanged: (val) => _searchStudents(val),
          ),
        ),
        if (_isSearching) const Center(child: CircularProgressIndicator(color: Colors.pinkAccent)),
        Expanded(
          child: _searchResults.isEmpty 
            ? const Center(child: Text('Search for your crush to send an anonymous message.', style: TextStyle(color: Colors.white54)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final user = _searchResults[index];
                  return ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.black26, child: Icon(Icons.person, color: Colors.white54)),
                    title: Text(user['firstName'] ?? 'Student', style: const TextStyle(color: Colors.white)),
                    subtitle: Text(user['university'] ?? 'Campus', style: const TextStyle(color: Colors.white54)),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent.withOpacity(0.2), elevation: 0),
                      onPressed: () => _openSendModal(user),
                      child: const Text('Crush', style: TextStyle(color: Colors.pinkAccent)),
                    ),
                  );
                },
              ),
        )
      ],
    );
  }

  Widget _buildInboxTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('secret_crushes').where('recipientUid', isEqualTo: currentUid).orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text('No secret crushes yet.', style: TextStyle(color: Colors.white54)));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final bool isRevealed = doc['status'] == 'revealed';
            
            return GlassCard(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              borderRadius: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(isRevealed ? Icons.favorite : Icons.favorite_border, color: Colors.pinkAccent),
                      const SizedBox(width: 8),
                      Text(isRevealed ? 'Identity Revealed!' : 'Secret Admirer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      if (!isRevealed)
                        TextButton(onPressed: () => _playGuessWho(doc), child: const Text('Guess Who?', style: TextStyle(color: Colors.pinkAccent)))
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (doc['ecard'] != 'None')
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.pinkAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Text(doc['ecard'], style: const TextStyle(color: Colors.pinkAccent, fontStyle: FontStyle.italic)),
                    ),
                  if (doc['message'] != null && doc['message'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(doc['message'], style: const TextStyle(color: Colors.white70)),
                  ]
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOutboxTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('secret_crushes').where('senderUid', isEqualTo: currentUid).orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text('You haven\'t sent any crushes.', style: TextStyle(color: Colors.white54)));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final bool isRevealed = doc['status'] == 'revealed';
            
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.send, color: Colors.white54),
              title: const Text('Sent to a student', style: TextStyle(color: Colors.white)),
              subtitle: Text(isRevealed ? 'They revealed you! 💖' : 'Status: Unseen', style: TextStyle(color: isRevealed ? Colors.pinkAccent : Colors.white54)),
              trailing: isRevealed ? null : IconButton(icon: const Icon(Icons.undo, color: Colors.redAccent), onPressed: () => _retractCrush(doc.id), tooltip: 'Retract'),
            );
          },
        );
      },
    );
  }
}
