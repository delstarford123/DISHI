import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/glass_card.dart';

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
  
  String get currentUid => FirebaseAuth.instance.currentUser?.uid ?? 'guest';

  @override
  void initState() {
    super.initState();
    // Assuming if they already have a squad, we'd fetch it here.
    // For demo, we just fetch the feed.
    _fetchSquadFeed();
  }

  Future<void> _createSquad() async {
    if (_squadNameController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    
    try {
      final inviteCode = (100000 + DateTime.now().millisecondsSinceEpoch % 899999).toString();
      final docRef = await FirebaseFirestore.instance.collection('squads').add({
        'host_id': currentUid,
        'squad_name': _squadNameController.text.trim(),
        'invite_code': inviteCode,
        'members': [currentUid],
        'created_at': FieldValue.serverTimestamp(),
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
      final snapshot = await FirebaseFirestore.instance
          .collection('squads')
          .where('invite_code', isEqualTo: _inviteCodeController.text.trim())
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        await doc.reference.update({
          'members': FieldValue.arrayUnion([currentUid])
        });
        setState(() {
          _mySquadId = doc.id;
        });
        _fetchSquadFeed();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid invite code.')));
        }
      }
    } catch (e) {
      debugPrint('Error joining squad: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      
      if (mounted) {
        setState(() {
          _squadFeed = feed;
        });
      }
    } catch (e) {
      debugPrint('Error fetching squads: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _swipeSquad(String targetSquadId, String action) async {
    if (_mySquadId == null) return;
    
    try {
      await FirebaseFirestore.instance.collection('squad_swipes').add({
        'from_squad_id': _mySquadId,
        'to_squad_id': targetSquadId,
        'action': action,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      if (action == 'like' && mounted) {
        // Simulating match logic
        showDialog(context: context, builder: (_) => AlertDialog(
          backgroundColor: _neonPurple,
          title: const Text('ITS A MATCH! 🔥', style: TextStyle(color: Colors.white)),
          content: const Text('Your Squad matched! A group chat has been created.', style: TextStyle(color: Colors.white)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('LFG!', style: TextStyle(color: Colors.white)))
          ],
        ));
      }
      
      setState(() {
        _squadFeed.removeWhere((s) => s['id'] == targetSquadId);
      });
    } catch (e) {
      debugPrint('Error swiping: $e');
    }
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
              const SizedBox(height: 8),
              const Text('Squad up with 1-3 friends and swipe on other groups for double dates or hangouts.', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              TextField(
                controller: _squadNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. The Night Owls',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
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
              TextField(
                controller: _inviteCodeController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter 6-digit code',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonCyan,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _joinSquad,
                  child: const Text('Join Squad', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSquadFeedView() {
    return Column(
      children: [
        if (_myInviteCode != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Squad Invite Code: ', style: TextStyle(color: Colors.white70)),
                Text(_myInviteCode!, style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
              ],
            ),
          ),
          
        Expanded(
          child: _squadFeed.isEmpty 
            ? const Center(child: Text('No squads found nearby. Create one!', style: TextStyle(color: Colors.white54)))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _squadFeed.length,
                itemBuilder: (context, index) {
                  final squad = _squadFeed[index];
                  return _buildSquadCard(squad);
                },
              ),
        ),
      ],
    );
  }

  Widget _buildSquadCard(Map<String, dynamic> squad) {
    final int memberCount = (squad['members'] as List?)?.length ?? 1;
    
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
                Text(squad['squad_name'] ?? 'Unknown Squad', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _neonPurple.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: Text('$memberCount Members', style: const TextStyle(color: _neonPurple, fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const SizedBox(height: 8),
            Text(squad['squad_type'] ?? 'Group Hangout', style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _swipeSquad(squad['id'], 'pass'),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Icon(Icons.close, color: Colors.redAccent),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _swipeSquad(squad['id'], 'like'),
                    style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Icon(Icons.favorite, color: Colors.white),
                    ),
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
