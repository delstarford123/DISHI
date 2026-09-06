import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonPink = Color(0xFFF92B60);
const Color _textSecondary = Color(0xFF8B9BB4);

class ParentControlsTab extends StatelessWidget {
  final List<Map<String, dynamic>> linkedStudents;
  final VoidCallback onKillSwitch;
  final VoidCallback onNutritionSelector;
  final VoidCallback onAutoTopUpSelector;
  final VoidCallback onSharedWallet;
  final VoidCallback onLunchboxSelector;

  const ParentControlsTab({
    super.key,
    required this.linkedStudents,
    required this.onKillSwitch,
    required this.onNutritionSelector,
    required this.onAutoTopUpSelector,
    required this.onSharedWallet,
    required this.onLunchboxSelector,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          const Text('Controls & Safety', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Manage restrictions, diets, and security for your children.', style: TextStyle(color: _textSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildActionGridButton(context, Icons.security, 'Kill Switch', _neonPink, onKillSwitch),
              _buildActionGridButton(context, Icons.restaurant, 'Nutrition Limits', _neonOrange, onNutritionSelector),
              _buildActionGridButton(context, Icons.bento, 'Lunchbox Pre-order', Colors.greenAccent, onLunchboxSelector),
              _buildActionGridButton(context, Icons.account_balance_wallet, 'Auto Top-Up', _neonCyan, onAutoTopUpSelector),
              _buildActionGridButton(context, Icons.family_restroom, 'Shared Wallet', _neonBlue, onSharedWallet),
              
              // New Features
              _buildActionGridButton(context, Icons.medical_services, 'Allergies Profile', Colors.redAccent, () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Allergies Profile coming soon')));
              }),
              _buildActionGridButton(context, Icons.store, 'Merchant Whitelist', Colors.purpleAccent, () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Merchant Whitelist coming soon')));
              }),
              _buildActionGridButton(context, Icons.map, 'Purchase Location', Colors.blueAccent, () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geolocation coming soon')));
              }),
              _buildActionGridButton(context, Icons.calendar_today, 'Meal Subscriptions', Colors.orangeAccent, () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meal Plans coming soon')));
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
