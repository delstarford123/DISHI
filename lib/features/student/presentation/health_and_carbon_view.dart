import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/user_model.dart';

class HealthAndCarbonView extends StatefulWidget {
  final UserModel userModel;

  const HealthAndCarbonView({super.key, required this.userModel});

  @override
  State<HealthAndCarbonView> createState() => _HealthAndCarbonViewState();
}

class _HealthAndCarbonViewState extends State<HealthAndCarbonView> {
  double _carbonSaved = 0.0;
  int _carbonRank = 0;

  @override
  void initState() {
    super.initState();
    _fetchMyEcoStats();
  }

  Future<void> _fetchMyEcoStats() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('eco_profiles').doc(widget.userModel.uid).get();
      if (doc.exists) {
        setState(() {
          _carbonSaved = (doc.data()?['carbonSaved'] ?? 0.0).toDouble();
          _carbonRank = doc.data()?['rank'] ?? 0;
        });
      } else {
        // Init profile if missing
        await FirebaseFirestore.instance.collection('eco_profiles').doc(widget.userModel.uid).set({
          'uid': widget.userModel.uid,
          'name': widget.userModel.displayName,
          'carbonSaved': 0.0,
          'rank': 0,
        });
      }
    } catch (e) {
      debugPrint('Error fetching eco stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Health & Impact'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Campus Impact',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildCarbonTracker(),
            const SizedBox(height: 32),
            const Text(
              'Community Leaderboard',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildLeaderboard(),
            const SizedBox(height: 32),
            const Text(
              'Smart Nudges',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('health_nudges').limit(3).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SizedBox();
                }
                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    // Convert color string to Color safely
                    Color nudgeColor = Colors.greenAccent;
                    if (data['color'] == 'red') nudgeColor = Colors.redAccent;
                    if (data['color'] == 'blue') nudgeColor = Colors.blueAccent;
                    
                    final nudgeMap = {
                      'title': data['title'] ?? 'Eco Tip',
                      'message': data['message'] ?? '',
                      'icon': Icons.energy_savings_leaf, // Fallback icon
                      'color': nudgeColor,
                    };
                    return _buildNudgeCard(nudgeMap);
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarbonTracker() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF05D5AA).withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF05D5AA).withOpacity(0.2), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.eco, color: Color(0xFF05D5AA), size: 48),
          const SizedBox(height: 16),
          const Text('Carbon Footprint Saved', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text('$_carbonSaved kg CO₂', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text('Rank #$_carbonRank on Campus', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLeaderboard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131A2A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('eco_profiles')
            .orderBy('carbonSaved', descending: true)
            .limit(10)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF05D5AA)));
          
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Padding(padding: EdgeInsets.all(16.0), child: Text('No leaderboard data yet.', style: TextStyle(color: Colors.white54)));

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 1),
            itemBuilder: (context, index) {
              final item = docs[index].data() as Map<String, dynamic>;
              final isMe = docs[index].id == widget.userModel.uid;
              final name = isMe ? 'You' : (item['name'] ?? 'Student');
              final points = (item['carbonSaved'] ?? 0.0).toStringAsFixed(1);
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isMe ? const Color(0xFF05D5AA) : Colors.white12,
                  child: Text('${index + 1}', style: TextStyle(color: isMe ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: Text(name, style: TextStyle(color: isMe ? const Color(0xFF05D5AA) : Colors.white, fontWeight: isMe ? FontWeight.bold : FontWeight.normal)),
                trailing: Text('$points kg', style: const TextStyle(color: Colors.white70)),
              );
            },
          );
        }
      ),
    );
  }

  Widget _buildNudgeCard(Map<String, dynamic> nudge) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (nudge['color'] as Color).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (nudge['color'] as Color).withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (nudge['color'] as Color).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(nudge['icon'] as IconData, color: nudge['color'] as Color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nudge['title'] as String, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(nudge['message'] as String, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
