import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonPink = Color(0xFFF92B60);
const Color _textSecondary = Color(0xFF8B9BB4);

class ParentHomeTab extends StatelessWidget {
  final Map<String, dynamic> user;
  final double vaultBalance;
  final List<Map<String, dynamic>> linkedStudents;
  final VoidCallback onBulkFund;
  final VoidCallback onLinkChild;
  final VoidCallback onAddOfflineChild;
  final Function(BuildContext, String, String) onTopUp;
  final Function(BuildContext, String, String) onGetIdCard;

  const ParentHomeTab({
    super.key,
    required this.user,
    required this.vaultBalance,
    required this.linkedStudents,
    required this.onBulkFund,
    required this.onLinkChild,
    required this.onAddOfflineChild,
    required this.onTopUp,
    required this.onGetIdCard,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // The Shared Vault
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _neonBlue.withOpacity(0.4), width: 1.5),
              boxShadow: [BoxShadow(color: _neonBlue.withOpacity(0.1), blurRadius: 20, spreadRadius: 2)]
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield, color: _neonBlue, size: 24),
                    SizedBox(width: 8),
                    Text('Shared Family Vault', style: TextStyle(color: _textSecondary, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'KSH ${vaultBalance.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                Text('Linked to: ${user['phone'] ?? '254700000000'}', style: const TextStyle(color: _textSecondary)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onBulkFund,
                  icon: const Icon(Icons.account_balance_wallet),
                  label: const Text('Fund Students'),
                  style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          const Text('Linked Students', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          ...linkedStudents.map((student) => _buildStudentCard(context, student)),
          
          const SizedBox(height: 32),
          const Text('Manage Children', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onLinkChild,
                  icon: const Icon(Icons.link),
                  label: const Text('Link Student'),
                  style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onAddOfflineChild,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Offline'),
                  style: ElevatedButton.styleFrom(backgroundColor: _neonBlue, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 100),
        ]),
      ),
    );
  }

  Widget _buildStudentCard(BuildContext context, Map<String, dynamic> student) {
    bool isActive = student['status'] == 'Active';
    Color statusColor = isActive ? _neonCyan : _neonOrange;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: _surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.school, color: statusColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student['name'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(student['status'], style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        if (student['isOffline'] == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _neonBlue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: _neonBlue),
                            ),
                            child: const Text('OFFLINE', style: TextStyle(color: _neonBlue, fontSize: 10, fontWeight: FontWeight.bold)),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _neonCyan.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: _neonCyan),
                            ),
                            child: const Text('ONLINE', style: TextStyle(color: _neonCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Wallet', style: TextStyle(color: _textSecondary, fontSize: 12)),
                  Text('KSH ${student['balance'].toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => onTopUp(context, student['uid'], student['name']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _neonBlue),
                    ),
                    alignment: Alignment.center,
                    child: const Text('Top Up', style: TextStyle(color: _neonBlue, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => onGetIdCard(context, student['uid'], student['name']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _neonBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Text('Get ID Card', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
