import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/mpesa_theme.dart';
import 'match_chat_view.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonPurple = Color(0xFF9C27B0);
const Color _neonCyan = Color(0xFF05D5AA);

class MatchEventDateView extends StatefulWidget {
  const MatchEventDateView({super.key});

  @override
  State<MatchEventDateView> createState() => _MatchEventDateViewState();
}

class _MatchEventDateViewState extends State<MatchEventDateView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedVibe = 'All';
  final List<String> _vibes = ['All', 'Party', 'Chill', 'Academic', 'Arts', 'Sports'];

  String get currentUid => FirebaseAuth.instance.currentUser?.uid ?? 'guest';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _findDateForEvent(Map<String, dynamic> event) {
    // 1. Shows "Searching for matches attending this event..." animation
    // 2. We mock finding a match immediately for demo purposes
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pop(context); // Close searching
          _showMatchFound(event);
        });
        return const AlertDialog(
          backgroundColor: _cardColor,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _neonPink),
              SizedBox(height: 16),
              Text('Matching you with other solo attendees...', style: TextStyle(color: Colors.white)),
            ],
          ),
        );
      }
    );
  }

  void _showMatchFound(Map<String, dynamic> event) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Event Date Found! 🎉', style: TextStyle(color: _neonPink, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(radius: 40, backgroundColor: _neonPurple, child: Icon(Icons.person, size: 40)),
            const SizedBox(height: 16),
            const Text('Alex is also looking for a date to:', style: TextStyle(color: Colors.white70)),
            Text(event['title'] ?? 'this event', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            const Text('Match compatibility: 87%', style: TextStyle(color: _neonCyan)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Pass')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonPink),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Matched! Opening Chat...')));
            },
            child: const Text('Say Hi', style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );
  }

  void _joinEventGroupChat(Map<String, dynamic> event) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Joined ${event['title']} Group Chat!')));
  }

  void _openOutfitBoard(Map<String, dynamic> event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Color(0xFF1E293B), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          children: [
            const Text('Outfit Planning Board 👗👔', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _buildOutfitPost('Jessica', 'Thinking of wearing all black, is that too much? 🤔'),
                  _buildOutfitPost('Brian', 'Dress code is strictly smart casual guys!'),
                  _buildOutfitPost('Anonymous', 'Who is wearing heels to the freshers bash? Pls dont let me be the only one 😭'),
                ],
              ),
            ),
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ask what people are wearing...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                suffixIcon: IconButton(icon: const Icon(Icons.send, color: _neonCyan), onPressed: () => Navigator.pop(context)),
              ),
            )
          ],
        ),
      )
    );
  }

  Widget _buildOutfitPost(String name, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(color: _neonPurple, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Varsity Dates', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _neonPink,
          labelColor: _neonPink,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Find a Date'),
            Tab(text: 'My Event Dates'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDiscoverTab(),
          _buildMyDatesTab(),
        ],
      ),
    );
  }

  Widget _buildDiscoverTab() {
    return Column(
      children: [
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _vibes.length,
            itemBuilder: (context, index) {
              final vibe = _vibes[index];
              final isSel = vibe == _selectedVibe;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(vibe),
                  selected: isSel,
                  selectedColor: _neonCyan,
                  backgroundColor: _cardColor,
                  labelStyle: TextStyle(color: isSel ? Colors.black : Colors.white),
                  onSelected: (val) => setState(() => _selectedVibe = vibe),
                ),
              );
            }
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('events').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _neonPink));
              
              var docs = snapshot.data?.docs ?? [];
              if (_selectedVibe != 'All') {
                // Approximate filtering since we use categories on events
                docs = docs.where((d) => (d.data() as Map<String, dynamic>)['category'] == _selectedVibe).toList();
              }
              
              if (docs.isEmpty) return const Center(child: Text('No events found for this vibe.', style: TextStyle(color: Colors.white54)));

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  data['id'] = docs[index].id;
                  return _buildEventCard(data);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final attendeesCount = (event['attendees'] as List?)?.length ?? event['ticketsSold'] ?? 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              event['imageUrl'] != null
                ? ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), child: Image.network(event['imageUrl'], height: 160, width: double.infinity, fit: BoxFit.cover))
                : Container(
                    height: 140,
                    decoration: const BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                    child: const Center(child: Icon(Icons.event, size: 60, color: _textSecondary)),
                  ),
              Positioned(
                top: 12, right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.people, color: _neonCyan, size: 14),
                      const SizedBox(width: 4),
                      Text('$attendeesCount attending', style: const TextStyle(color: _neonCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              )
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event['title'] ?? 'Campus Event', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: _neonPink, size: 16),
                    const SizedBox(width: 4),
                    Text(event['location'] ?? 'TBA', style: const TextStyle(color: _textSecondary)),
                  ],
                ),
                
                const SizedBox(height: 16),
                const Text("Who's Going", style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      height: 32, width: 100,
                      child: Stack(
                        children: List.generate(4, (index) => Positioned(
                          left: index * 20.0,
                          child: CircleAvatar(radius: 16, backgroundColor: Colors.primaries[index % Colors.primaries.length], child: Text('${index+1}', style: const TextStyle(fontSize: 10, color: Colors.white))),
                        )),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.checkroom, color: _neonPurple, size: 16),
                      label: const Text('Outfit Board', style: TextStyle(color: _neonPurple)),
                      onPressed: () => _openOutfitBoard(event),
                    )
                  ],
                ),
                
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: _neonCyan)),
                        onPressed: () => _joinEventGroupChat(event),
                        icon: const Icon(Icons.chat, color: _neonCyan, size: 16),
                        label: const Text('Group Chat', style: TextStyle(color: _neonCyan)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _neonPink),
                        onPressed: () => _findDateForEvent(event),
                        child: const Text('FIND A DATE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Navigating to Campus Tickets...')));
                    },
                    child: const Text('Need a ticket? Buy here', style: TextStyle(color: Colors.white54, decoration: TextDecoration.underline, fontSize: 12)),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMyDatesTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite_border, color: Colors.white24, size: 80),
          const SizedBox(height: 16),
          const Text('No Event Dates Yet', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Hit "FIND A DATE" on an event to start matching!', style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 32),
          
          // Feature 17: Post-event prompt mockup
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _neonPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: _neonPurple.withOpacity(0.5))),
            child: Column(
              children: [
                const Text('Post-Event Question', style: TextStyle(color: _neonPurple, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Did you meet anyone at the Freshers Bash last night?', style: TextStyle(color: Colors.white), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(onPressed: (){}, style: ElevatedButton.styleFrom(backgroundColor: _neonCyan), child: const Text('Yes! 💖', style: TextStyle(color: Colors.black))),
                    const SizedBox(width: 16),
                    OutlinedButton(onPressed: (){}, child: const Text('No 😔', style: TextStyle(color: Colors.white))),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
