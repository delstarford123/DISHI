import 'package:flutter/material.dart';
import '../../../core/theme/mpesa_theme.dart';

class TreatBountiesView extends StatefulWidget {
  const TreatBountiesView({super.key});

  @override
  State<TreatBountiesView> createState() => _TreatBountiesViewState();
}

class _TreatBountiesViewState extends State<TreatBountiesView> {
  final List<Map<String, dynamic>> _bounties = [
    {
      'title': 'A+ Math Score',
      'student': 'Sarah K.',
      'reward': 'Free Ice Cream',
      'status': 'Claimed',
      'icon': Icons.calculate,
      'color': Colors.blue,
    },
    {
      'title': 'Perfect Attendance',
      'student': 'John M.',
      'reward': 'Extra Fries',
      'status': 'Pending',
      'icon': Icons.calendar_month,
      'color': Colors.green,
    },
    {
      'title': 'Sports Day Winner',
      'student': 'Alice W.',
      'reward': 'Juice Box',
      'status': 'Pending',
      'icon': Icons.sports_basketball,
      'color': Colors.orange,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Treat Bounties'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Good Behavior Rewards',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Teachers can lock "Treat Bounties" onto a student\'s tag for good behavior.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: ListView.builder(
                itemCount: _bounties.length,
                itemBuilder: (context, index) {
                  final bounty = _bounties[index];
                  final isPending = bounty['status'] == 'Pending';
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131A2A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: (bounty['color'] as Color).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (bounty['color'] as Color).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(bounty['icon'] as IconData, color: bounty['color'] as Color),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(bounty['title'] as String, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('${bounty['student']} • ${bounty['reward']}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isPending ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            bounty['status'] as String,
                            style: TextStyle(
                              color: isPending ? Colors.orange : Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF05D5AA),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only Teachers can add Treat Bounties')));
        },
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('Add Bounty', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
