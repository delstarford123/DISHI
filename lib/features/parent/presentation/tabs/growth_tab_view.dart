import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonPink = Color(0xFFF92B60);
const Color _textSecondary = Color(0xFF8B9BB4);

class GrowthTabView extends StatelessWidget {
  final Map<String, dynamic> user;
  final List<dynamic> linkedStudents;
  
  const GrowthTabView({super.key, required this.user, required this.linkedStudents});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Smart Spender Score
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _neonCyan.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              SizedBox(
                height: 80,
                width: 80,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: 0.85,
                      strokeWidth: 8,
                      color: _neonCyan,
                      backgroundColor: Colors.white.withOpacity(0.1),
                    ),
                    const Center(child: Text('85', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Smart Spender Score', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Excellent! Top 10% of campus based on healthy eating.', style: TextStyle(color: _textSecondary, fontSize: 12)),
                  ],
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Chores Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Chores & Tasks', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(onPressed: () {}, child: const Text('+ Assign', style: TextStyle(color: _neonOrange))),
          ],
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('bounties')
                  .where('parentUid', isEqualTo: user['uid'])
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _neonOrange));
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) return const Text('No chores assigned.', style: TextStyle(color: _textSecondary));
            
            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _buildChoreCard(data['title'] ?? 'Chore', (data['reward'] ?? 0.0).toDouble(), data['status'] == 'completed');
              }).toList(),
            );
          },
        ),
        
        const SizedBox(height: 24),
        
        // Savings Goals
        const Text('Savings Goals', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('savings_goals')
                  .where('parentUid', isEqualTo: user['uid'])
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _neonCyan));
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) return const Text('No savings goals set.', style: TextStyle(color: _textSecondary));
            
            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _buildSavingsCard(data['title'] ?? 'Goal', (data['current'] ?? 0.0).toDouble(), (data['target'] ?? 1000.0).toDouble());
              }).toList(),
            );
          },
        ),
        
        const SizedBox(height: 24),
        
        // Themes
        const Text('Unlockable Themes', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildThemeCard('Neon Cyber', _neonCyan),
              _buildThemeCard('Sunset Orange', _neonOrange),
              _buildThemeCard('Bubblegum', _neonPink),
            ],
          ),
        )
      ],
    );
  }
  
  Widget _buildChoreCard(String title, double reward, bool pendingApproval) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(pendingApproval ? Icons.check_circle_outline : Icons.radio_button_unchecked, color: pendingApproval ? _neonOrange : _textSecondary),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white)),
                  Text('Reward: Ksh $reward', style: const TextStyle(color: _neonCyan, fontSize: 12)),
                ],
              ),
            ],
          ),
          if (pendingApproval)
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(backgroundColor: _neonOrange, minimumSize: const Size(60, 30)),
              child: const Text('Approve', style: TextStyle(color: Colors.white, fontSize: 12)),
            )
        ],
      ),
    );
  }

  Widget _buildSavingsCard(String title, double current, double target) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white)),
              Text('Ksh $current / $target', style: const TextStyle(color: _textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: current / target,
            backgroundColor: Colors.white.withOpacity(0.1),
            color: _neonCyan,
            minHeight: 8,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(side: const BorderSide(color: _neonCyan)),
              child: const Text('Match Funds', style: TextStyle(color: _neonCyan)),
            ),
          )
        ],
      ),
    );
  }
  
  Widget _buildThemeCard(String title, Color color) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Center(
        child: Text(title, textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
