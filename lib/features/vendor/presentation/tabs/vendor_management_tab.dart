import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonPink = Color(0xFFFF2A5F);
const Color _textSecondary = Color(0xFF8B9BB4);

class VendorManagementTabView extends StatelessWidget {
  final Map<String, dynamic> user;

  const VendorManagementTabView({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Multi-Branch Selector
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('Shop Management', Icons.store, Colors.white),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _textSecondary.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Text('Main Cafeteria', style: TextStyle(color: Colors.white)),
                  Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 32),

        // Staff Shift Management
        _buildSectionHeader('Staff Shift Clock-In', Icons.badge, _neonCyan),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Text('Enter 4-digit PIN to clock in or out of your shift.', style: TextStyle(color: _textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Staff PIN',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.lock, color: _neonCyan),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('Clock In', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: _neonCyan), padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('Clock Out', style: TextStyle(color: _neonCyan)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Market Pricing Insights
        _buildSectionHeader('Market Pricing Insights', Icons.insights, _neonOrange),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Text('Anonymous campus averages to help you stay competitive.', style: TextStyle(color: _textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              _buildInsightRow('Beef Stew', '180 KSH', '165 KSH (Avg)', Icons.warning_amber, _neonPink),
              const Divider(color: _textSecondary),
              _buildInsightRow('Chapati', '20 KSH', '25 KSH (Avg)', Icons.check_circle, _neonCyan),
              const Divider(color: _textSecondary),
              _buildInsightRow('Pilau', '150 KSH', '150 KSH (Avg)', Icons.remove_circle_outline, Colors.white),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Health & Safety Vault
        _buildSectionHeader('Health & Safety Vault', Icons.verified_user, Colors.white),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _textSecondary.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.description, color: Colors.white),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Food Handling License', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('Verified • Expires Oct 2027', style: TextStyle(color: _neonCyan, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(onPressed: () {}, icon: const Icon(Icons.remove_red_eye, color: _textSecondary)),
            ],
          ),
        ),

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildInsightRow(String item, String myPrice, String marketPrice, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(item, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 1,
            child: Text(myPrice, style: const TextStyle(color: Colors.white)),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 4),
                Text(marketPrice, style: TextStyle(color: color, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
