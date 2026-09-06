import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonPink = Color(0xFFF92B60);
const Color _textSecondary = Color(0xFF8B9BB4);

class ParentEngagementTab extends StatelessWidget {
  const ParentEngagementTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          const Text('Family & Engagement', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Gamify spending, track chores, and connect with the school community.', style: TextStyle(color: _textSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildActionGridButton(context, Icons.task_alt, 'Chores & Rewards', _neonCyan, () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chores & Rewards coming soon')));
              }),
              _buildActionGridButton(context, Icons.savings, 'Savings Goals', _neonBlue, () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Savings Goals coming soon')));
              }),
              _buildActionGridButton(context, Icons.score, 'Smart Spender Score', _neonOrange, () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Smart Spender Score coming soon')));
              }),
              _buildActionGridButton(context, Icons.color_lens, 'App Themes', _neonPink, () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App Themes coming soon')));
              }),
              _buildActionGridButton(context, Icons.folder_shared, 'ID & Document Vault', Colors.tealAccent, () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document Vault coming soon')));
              }),
              _buildActionGridButton(context, Icons.event, 'Family Calendar', Colors.amberAccent, () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Family Calendar coming soon')));
              }),
              _buildActionGridButton(context, Icons.forum, 'Parent Forum', Colors.indigoAccent, () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parent Forum coming soon')));
              }),
              _buildActionGridButton(context, Icons.swap_horiz, 'P2P Parent Transfer', Colors.green, () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('P2P Transfers coming soon')));
              }),
              _buildActionGridButton(context, Icons.notifications, 'Notification Center', Colors.yellow, () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification Center coming soon')));
              }),
            ],
          ),
          const SizedBox(height: 100),
        ]),
      ),
    );
  }

  Widget _buildActionGridButton(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
