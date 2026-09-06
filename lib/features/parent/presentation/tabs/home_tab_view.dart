import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _textSecondary = Color(0xFF8B9BB4);

class HomeTabView extends StatelessWidget {
  final Map<String, dynamic> user;
  final double vaultBalance;
  final List<Map<String, dynamic>> linkedStudents;

  const HomeTabView({
    super.key,
    required this.user,
    required this.vaultBalance,
    required this.linkedStudents,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Vault Balance Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _neonBlue.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Parent Vault Balance', style: TextStyle(color: _textSecondary)),
              const SizedBox(height: 8),
              Text(
                'Ksh $vaultBalance',
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(backgroundColor: _neonCyan),
                      child: const Text('Top Up Vault', style: TextStyle(color: Colors.black)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('Linked Students', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ...linkedStudents.map((s) => _buildStudentCard(s)).toList(),
      ],
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: _neonBlue,
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s['name'] ?? 'Student', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(s['status'] ?? 'Active', style: TextStyle(color: (s['balance'] ?? 0) < 200 ? Colors.redAccent : _neonCyan, fontSize: 12)),
                ],
              ),
            ],
          ),
          Text('Ksh ${s['balance']}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
