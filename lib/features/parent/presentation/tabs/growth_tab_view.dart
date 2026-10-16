import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/mpesa_theme.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonPink = Color(0xFFF92B60);
const Color _textSecondary = Color(0xFF8B9BB4);

class GrowthTabView extends StatelessWidget {
  final Map<String, dynamic> user;
  final List<dynamic> linkedStudents;
  
  const GrowthTabView({super.key, required this.user, required this.linkedStudents});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? user['uid'];

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
                      value: 0.88,
                      strokeWidth: 8,
                      color: _neonCyan,
                      backgroundColor: Colors.white.withOpacity(0.1),
                    ),
                    const Center(child: Text('88', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Smart Spender Score: A+', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Excellent! Top 10% of campus based on healthy eating and disciplined budgeting.', style: TextStyle(color: _textSecondary, fontSize: 12)),
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
            TextButton.icon(
              onPressed: () => _showAssignChoreDialog(context),
              icon: const Icon(Icons.add_task_rounded, color: _neonOrange, size: 16),
              label: const Text('+ Assign', style: TextStyle(color: _neonOrange, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('bounties')
                  .where('parentUid', isEqualTo: currentUid)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _neonOrange));
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) return const Text('No chores assigned yet. Tap + Assign to motivate your child!', style: TextStyle(color: _textSecondary));
            
            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _buildChoreCard(context, doc, data['title'] ?? 'Chore', (data['reward'] ?? 0.0).toDouble(), data['status'] == 'completed');
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
                  .where('parentUid', isEqualTo: currentUid)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _neonCyan));
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) return const Text('No savings goals set.', style: TextStyle(color: _textSecondary));
            
            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _buildSavingsCard(context, doc, data['title'] ?? 'Goal', (data['current'] ?? 0.0).toDouble(), (data['target'] ?? 1000.0).toDouble());
              }).toList(),
            );
          },
        ),
        
        const SizedBox(height: 24),
        
        // Themes
        const Text('Unlockable Student Themes', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildThemeCard('Neon Cyber', _neonCyan),
              _buildThemeCard('Sunset Gold', _neonOrange),
              _buildThemeCard('Bubblegum Pink', _neonPink),
              _buildThemeCard('Emerald Guard', MPesaTheme.primaryGreen),
            ],
          ),
        )
      ],
    );
  }
  
  Widget _buildChoreCard(BuildContext context, DocumentSnapshot doc, String title, double reward, bool isCompleted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isCompleted ? _neonCyan.withOpacity(0.3) : Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked, color: isCompleted ? _neonCyan : _neonOrange),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('Reward: Ksh ${reward.toStringAsFixed(0)}', style: const TextStyle(color: _neonCyan, fontSize: 12)),
                ],
              ),
            ],
          ),
          if (!isCompleted)
            ElevatedButton(
              onPressed: () => _approveChore(context, doc),
              style: ElevatedButton.styleFrom(backgroundColor: _neonOrange, minimumSize: const Size(70, 32)),
              child: const Text('Approve', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: _neonCyan.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
              child: const Text('PAID', style: TextStyle(color: _neonCyan, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildSavingsCard(BuildContext context, DocumentSnapshot doc, String title, double current, double target) {
    final double ratio = (current / (target > 0 ? target : 1)).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _neonCyan.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('Ksh ${current.toStringAsFixed(0)} / ${target.toStringAsFixed(0)}', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: ratio,
            backgroundColor: Colors.white.withOpacity(0.1),
            color: _neonCyan,
            minHeight: 8,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _matchFundsDialog(context, doc),
              icon: const Icon(Icons.handshake_rounded, size: 14, color: _neonCyan),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: _neonCyan)),
              label: const Text('Match Funds', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
  
  Widget _buildThemeCard(String title, Color color) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Center(
        child: Text(title, textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  void _showAssignChoreDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final rewardCtrl = TextEditingController(text: '100');
    final parentUid = FirebaseAuth.instance.currentUser?.uid ?? user['uid'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Assign Chore / Bounty', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Task Title',
                labelStyle: TextStyle(color: _neonOrange),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _neonOrange)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rewardCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Reward (Ksh)',
                labelStyle: TextStyle(color: _neonCyan),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _neonCyan)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            onPressed: () async {
              final t = titleCtrl.text.trim();
              final r = double.tryParse(rewardCtrl.text.trim()) ?? 0.0;
              if (t.isEmpty || r <= 0) return;
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('bounties').add({
                'parentUid': parentUid,
                'title': t,
                'reward': r,
                'status': 'pending',
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Task "$t" assigned!'), backgroundColor: _neonOrange));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _neonOrange),
            child: const Text('Assign', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _approveChore(BuildContext context, DocumentSnapshot doc) async {
    try {
      await doc.reference.update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chore approved and marked completed!'), backgroundColor: MPesaTheme.primaryGreen));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _matchFundsDialog(BuildContext context, DocumentSnapshot doc) {
    final amtCtrl = TextEditingController(text: '200');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Match Savings Goal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: amtCtrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Match Amount (Ksh)',
            labelStyle: TextStyle(color: _neonCyan),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _neonCyan)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amtCtrl.text.trim()) ?? 0.0;
              if (amt <= 0) return;
              Navigator.pop(ctx);
              await doc.reference.update({'current': FieldValue.increment(amt)});
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Matched Ksh ${amt.toStringAsFixed(0)}!'), backgroundColor: MPesaTheme.primaryGreen));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _neonCyan),
            child: const Text('Match', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
