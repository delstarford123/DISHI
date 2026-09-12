import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/glass_card.dart';
import 'match_chat_view.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _neonPurple = Color(0xFF9C27B0);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonCyan = Color(0xFF05D5AA);

class MatchDoubleDateView extends StatefulWidget {
  final Map<String, dynamic>? userModel;
  
  const MatchDoubleDateView({super.key, this.userModel});

  @override
  State<MatchDoubleDateView> createState() => _MatchDoubleDateViewState();
}

class _MatchDoubleDateViewState extends State<MatchDoubleDateView> {
  String? _mySquadId;
  String? _myInviteCode;
  List<dynamic> _squadFeed = [];
  bool _isLoading = false;

  final TextEditingController _squadNameController = TextEditingController();
  final TextEditingController _inviteCodeController = TextEditingController();
  final TextEditingController _squadBioController = TextEditingController();
  final TextEditingController _playlistController = TextEditingController();
  
  final List<String> _selectedInterests = [];
  final List<String> _interestOptions = ['Clubbing', 'Board Games', 'Hiking', 'Foodies', 'Movies', 'Concerts', 'Gaming'];
  
  // Phase 6 Additions
  final TextEditingController _wingmanBioController = TextEditingController();
  final TextEditingController _promptAnswerController = TextEditingController();
  String _selectedVibe = 'Chill & Netflix';
  final List<String> _vibeOptions = ['Chill & Netflix', 'Party Animals', 'Late Night Drives', 'Food & Vibes', 'Gym Bros/Girls', 'Academic Weapons'];
  
  String _selectedDateIdea = 'Escape Room';
  final List<String> _dateIdeas = ['Escape Room', 'Bowling & Drinks', 'Clubbing', 'Picnic at Karura', 'Game Night', 'Dinner Date'];
  
  String _myRole = 'The Driver';
  final List<String> _roleOptions = ['The Driver', 'The Planner', 'The Hype Man', 'The Introvert', 'The DJ', 'The Foodie'];
  
  String _selectedPrompt = 'We are most likely to...';
  final List<String> _prompts = ['We are most likely to...', 'Don\'t match with us if...', 'Our squad theme song is...', 'We have a mutual obsession with...'];

  String get currentUid => FirebaseAuth.instance.currentUser?.uid ?? 'guest';

  @override
  void initState() {
    super.initState();
    _checkExistingSquad();
  }
  
  @override
  void dispose() {
    _squadNameController.dispose();
    _inviteCodeController.dispose();
    _squadBioController.dispose();
    _playlistController.dispose();
    _wingmanBioController.dispose();
    _promptAnswerController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingSquad() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('squads').where('members', arrayContains: currentUid).limit(1).get();
      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        setState(() {
          _mySquadId = doc.id;
          _myInviteCode = doc['invite_code'];
        });
        _fetchSquadFeed();
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _createSquad() async {
    if (_squadNameController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    
    try {
      final inviteCode = (100000 + DateTime.now().millisecondsSinceEpoch % 899999).toString();
      final docRef = await FirebaseFirestore.instance.collection('squads').add({
        'host_id': currentUid,
        'squad_name': _squadNameController.text.trim(),
        'squad_bio': _squadBioController.text.trim(),
        'invite_code': inviteCode,
        'members': [currentUid],
        'interests': _selectedInterests,
        'playlist': _playlistController.text.trim(),
        'created_at': FieldValue.serverTimestamp(),
        // Phase 6
        'vibe': _selectedVibe,
        'date_idea': _selectedDateIdea,
        'prompt_q': _selectedPrompt,
        'prompt_a': _promptAnswerController.text.trim(),
        'member_roles': {currentUid: _myRole},
        'wingman_bios': {currentUid: _wingmanBioController.text.trim()}, // Mock for self, usually for a friend
      });
      
      setState(() {
        _mySquadId = docRef.id;
        _myInviteCode = inviteCode;
      });
      _fetchSquadFeed();
    } catch (e) {
      debugPrint('Error creating squad: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinSquad() async {
    if (_inviteCodeController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    
    try {
      final snapshot = await FirebaseFirestore.instance.collection('squads').where('invite_code', isEqualTo: _inviteCodeController.text.trim()).limit(1).get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final members = List.from(doc['members'] ?? []);
        if (members.length >= 4) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This squad is full (Max 4 members).')));
          return;
        }
        
        await doc.reference.update({
          'members': FieldValue.arrayUnion([currentUid]),
          'member_roles.$currentUid': _myRole,
          'wingman_bios.$currentUid': _wingmanBioController.text.trim(), // Joined member wingman bio
        });
        setState(() => _mySquadId = doc.id);
        _fetchSquadFeed();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid invite code.')));
      }
    } catch (e) {
      debugPrint('Error joining squad: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _leaveSquad() async {
    if (_mySquadId == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('squads').doc(_mySquadId).get();
      if (doc.exists) {
        final hostId = doc['host_id'];
        if (hostId == currentUid) {
          // Host leaving deletes squad
          await doc.reference.delete();
        } else {
          // Member leaving
          await doc.reference.update({'members': FieldValue.arrayRemove([currentUid])});
        }
      }
      setState(() { _mySquadId = null; _myInviteCode = null; });
    } catch (_) {}
  }

  Future<void> _kickMember(String memberId) async {
    if (_mySquadId == null) return;
    try {
      await FirebaseFirestore.instance.collection('squads').doc(_mySquadId).update({'members': FieldValue.arrayRemove([memberId])});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member kicked.')));
    } catch (_) {}
  }

  Future<void> _fetchSquadFeed() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('squads').limit(20).get();
      
      final List<dynamic> feed = [];
      for (var doc in snapshot.docs) {
        if (doc.id != _mySquadId) {
          final data = doc.data();
          data['id'] = doc.id;
          feed.add(data);
        }
      }
      
      if (mounted) setState(() => _squadFeed = feed);
    } catch (e) {
      debugPrint('Error fetching squads: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _swipeSquad(Map<String, dynamic> targetSquad, String action) async {
    if (_mySquadId == null) return;
    
    try {
      await FirebaseFirestore.instance.collection('squad_swipes').add({
        'from_squad_id': _mySquadId,
        'to_squad_id': targetSquad['id'],
        'action': action,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      if (action == 'like' && mounted) {
        // Create Mega Group Chat
        final mySquadDoc = await FirebaseFirestore.instance.collection('squads').doc(_mySquadId).get();
        final myMembers = List<String>.from(mySquadDoc['members'] ?? []);
        final targetMembers = List<String>.from(targetSquad['members'] ?? []);
        
        final allMembers = [...myMembers, ...targetMembers];
        final chatId = 'squad_match_${_mySquadId}_${targetSquad['id']}';
        
        await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
          'participants': allMembers,
          'isGroup': true,
          'groupName': '${mySquadDoc['squad_name']} 🤝 ${targetSquad['squad_name']}',
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        showDialog(context: context, builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF131A2A),
          title: const Text('ITS A MATCH! 🔥', style: TextStyle(color: Colors.white)),
          content: Text('Your Squad matched with ${targetSquad['squad_name']}! A mega group chat has been created with all members.', style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => MatchChatView(
                  chatId: chatId,
                  myUid: currentUid,
                  matchName: '${mySquadDoc['squad_name']} 🤝 ${targetSquad['squad_name']}',
                  matchAvatar: '',
                  matchId: 'group',
                )));
              }, 
              child: const Text('Go to Chat', style: TextStyle(color: _neonCyan))
            )
          ],
        ));
      }
      
      setState(() => _squadFeed.removeWhere((s) => s['id'] == targetSquad['id']));
    } catch (e) {
      debugPrint('Error swiping: $e');
    }
  }

  void _ratePostDate(Map<String, dynamic> likeDoc) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: _bgColor,
      title: const Text('Rate Double Date', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('How was the date with this Squad?', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(icon: const Icon(Icons.sentiment_very_dissatisfied, color: Colors.red, size: 32), onPressed: () => Navigator.pop(context)),
              IconButton(icon: const Icon(Icons.sentiment_neutral, color: Colors.orange, size: 32), onPressed: () => Navigator.pop(context)),
              IconButton(icon: const Icon(Icons.sentiment_very_satisfied, color: Colors.green, size: 32), onPressed: () => Navigator.pop(context)),
            ],
          )
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Squad Match 🤝', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading && _squadFeed.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _neonPurple))
          : _mySquadId == null ? _buildNoSquadView() : _buildSquadFeedView(),
    );
  }

  Widget _buildNoSquadView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(24),
          borderRadius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Create a Squad', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildInput('Squad Name', _squadNameController),
              const SizedBox(height: 12),
              _buildInput('Squad Bio / Vibe', _squadBioController),
              const SizedBox(height: 12),
              _buildInput('Pregame Playlist (Spotify Link)', _playlistController),
              const SizedBox(height: 16),
              
              const Text('Squad Interests', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _interestOptions.map((i) {
                  final isSel = _selectedInterests.contains(i);
                  return ChoiceChip(
                    label: Text(i, style: TextStyle(color: isSel ? Colors.white : Colors.white70)),
                    selected: isSel,
                    selectedColor: _neonPurple,
                    backgroundColor: Colors.black26,
                    onSelected: (val) => setState(() { val ? _selectedInterests.add(i) : _selectedInterests.remove(i); }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              
              const Text('Squad Vibe & Double Date Idea', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedVibe, dropdownColor: _bgColor, style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none)),
                items: _vibeOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) => setState(() => _selectedVibe = v!),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedDateIdea, dropdownColor: _bgColor, style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none)),
                items: _dateIdeas.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) => setState(() => _selectedDateIdea = v!),
              ),
              const SizedBox(height: 16),
              
              const Text('Icebreaker Prompt', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              DropdownButtonFormField<String>(
                initialValue: _selectedPrompt, dropdownColor: _bgColor, style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(filled: true, fillColor: Colors.transparent, border: InputBorder.none),
                items: _prompts.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) => setState(() => _selectedPrompt = v!),
              ),
              _buildInput('Answer...', _promptAnswerController),
              const SizedBox(height: 16),
              
              const Text('My Role & Wingman Bio', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              DropdownButtonFormField<String>(
                initialValue: _myRole, dropdownColor: _bgColor, style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(filled: true, fillColor: Colors.transparent, border: InputBorder.none),
                items: _roleOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) => setState(() => _myRole = v!),
              ),
              _buildInput('Write a short bio for your wingman...', _wingmanBioController),
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _neonPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _createSquad,
                  child: const Text('Create Squad', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        GlassCard(
          padding: const EdgeInsets.all(24),
          borderRadius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Have an Invite Code?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildInput('Enter 6-digit code', _inviteCodeController),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _joinSquad,
                  child: const Text('Join Squad', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInput(String hint, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.black26,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildSquadFeedView() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: _neonPurple,
            labelColor: _neonPurple,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'Discover Squads'),
              Tab(text: 'My Squad & Likes'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildFeedTab(),
                _buildMySquadTab(),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFeedTab() {
    if (_squadFeed.isEmpty) return const Center(child: Text('No squads found nearby. Create one!', style: TextStyle(color: Colors.white54)));
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _squadFeed.length,
      itemBuilder: (context, index) {
        final squad = _squadFeed[index];
        return _buildSquadCard(squad);
      },
    );
  }

  Widget _buildMySquadTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('squads').doc(_mySquadId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: CircularProgressIndicator());
        
        final doc = snapshot.data!;
        final members = List<String>.from(doc['members'] ?? []);
        final isHost = doc['host_id'] == currentUid;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(doc['squad_name'], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.exit_to_app, color: Colors.redAccent), onPressed: _leaveSquad, tooltip: 'Leave Squad')
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Invite Code: ${doc['invite_code']}', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
                  const SizedBox(height: 16),
                  
                  Text('Members (${members.length}/4)', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  // Live Members UI
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: members.length,
                      itemBuilder: (context, i) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 26, backgroundColor: Colors.white12,
                                child: Text('👤', style: const TextStyle(fontSize: 24)),
                              ),
                              if (isHost && members[i] != currentUid)
                                Positioned(
                                  top: 0, right: 0,
                                  child: GestureDetector(
                                    onTap: () => _kickMember(members[i]),
                                    child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)),
                                  )
                                )
                            ],
                          ),
                        );
                      }
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // "Who Liked Us" Tab equivalent section
            const Text('Squads That Liked You 🔥', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('squad_swipes').where('to_squad_id', isEqualTo: _mySquadId).where('action', isEqualTo: 'like').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox();
                if (snap.data!.docs.isEmpty) return const Text('No likes yet. Keep swiping!', style: TextStyle(color: Colors.white54));
                
                return Column(
                  children: snap.data!.docs.map((likeDoc) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department, color: Colors.orange), // Hype
                          const SizedBox(width: 12),
                          Expanded(child: Text('A squad wants to match! (Expires in 48h)', style: const TextStyle(color: Colors.white))),
                          TextButton(onPressed: () {}, child: const Text('View', style: TextStyle(color: _neonPurple))),
                          IconButton(icon: const Icon(Icons.rate_review, color: _neonCyan), onPressed: () => _ratePostDate(likeDoc.data() as Map<String, dynamic>)),
                        ],
                      ),
                    );
                  }).toList(),
                );
              }
            )
          ],
        );
      }
    );
  }

  Widget _buildSquadCard(Map<String, dynamic> squad) {
    final int memberCount = (squad['members'] as List?)?.length ?? 1;
    final interests = List<String>.from(squad['interests'] ?? []);
    final playlist = squad['playlist'] ?? '';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(squad['squad_name'] ?? 'Unknown Squad', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _neonPurple.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: Text('$memberCount/4 Members', style: const TextStyle(color: _neonPurple, fontWeight: FontWeight.bold)),
                )
              ],
            ),
            if (squad['squad_bio'] != null && squad['squad_bio'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(squad['squad_bio'], style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ],
            const SizedBox(height: 12),
            
            // Phase 6 Additions Display
            if (squad['vibe'] != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _neonPink.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Text('Vibe: ${squad['vibe']}', style: const TextStyle(color: _neonPink, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            if (squad['date_idea'] != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _neonCyan.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Text('Date Idea: ${squad['date_idea']}', style: const TextStyle(color: _neonCyan, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            if (squad['prompt_q'] != null && squad['prompt_a'] != null && squad['prompt_a'].toString().isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12, top: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(squad['prompt_q'], style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text('"${squad['prompt_a']}"', style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),

            Wrap(
              spacing: 6, runSpacing: 6,
              children: interests.map((i) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                child: Text(i, style: const TextStyle(color: Colors.white70, fontSize: 10)),
              )).toList(),
            ),
            if (playlist.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.music_note, color: _neonCyan, size: 16),
                  const SizedBox(width: 4),
                  Expanded(child: Text('Pregame Playlist: $playlist', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _neonCyan, fontSize: 12))),
                ],
              )
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.people_alt, color: Colors.blueAccent, size: 14),
                const SizedBox(width: 4),
                Text('${(squad['squad_name'].toString().length % 3) + 1} Mutual Connections', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const Spacer(),
                const Text('🔥 Match expires in 48h', style: TextStyle(color: Colors.orange, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _swipeSquad(squad, 'pass'),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Icon(Icons.close, color: Colors.redAccent)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _swipeSquad(squad, 'like'),
                    style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Icon(Icons.favorite, color: Colors.black)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
