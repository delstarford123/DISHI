import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _textSecondary = Color(0xFF8B9BB4);

class SafetySettingsView extends StatefulWidget {
  const SafetySettingsView({super.key});

  @override
  State<SafetySettingsView> createState() => _SafetySettingsViewState();
}

class _SafetySettingsViewState extends State<SafetySettingsView> {
  bool _killSwitch = false;
  bool _blockJunkFood = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Safety & Dietary Config', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _neonPink.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: _neonPink)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Emergency Kill Switch', style: TextStyle(color: _neonPink, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Instantly freeze student wallet', style: TextStyle(color: _textSecondary, fontSize: 12)),
                  ],
                ),
                Switch(
                  value: _killSwitch,
                  activeThumbColor: _neonPink,
                  onChanged: (val) => setState(() => _killSwitch = val),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Dietary Blocks', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildToggleTile('Block Junk Food / Soda', _blockJunkFood, (val) => setState(() => _blockJunkFood = val)),
          _buildToggleTile('Peanut Allergy Alert', true, (val) {}),
          _buildToggleTile('Lactose Intolerance Alert', false, (val) {}),
        ],
      ),
    );
  }

  Widget _buildToggleTile(String title, bool val, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        activeThumbColor: _neonCyan,
        value: val,
        onChanged: onChanged,
      ),
    );
  }
}
