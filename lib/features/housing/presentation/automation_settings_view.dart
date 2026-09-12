import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonBlue = Color(0xFF00E5FF);
const Color _textSecondary = Color(0xFF8B9BB4);

class AutomationSettingsView extends StatefulWidget {
  const AutomationSettingsView({super.key});

  @override
  State<AutomationSettingsView> createState() => _AutomationSettingsViewState();
}

class _AutomationSettingsViewState extends State<AutomationSettingsView> {
  bool _autoReminders = true;
  bool _autoPenalties = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Automation Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Rent Collection Rules', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildToggleTile('Auto-Send Rent Reminders (5th of Month)', _autoReminders, (val) => setState(() => _autoReminders = val)),
          _buildToggleTile('Auto-Apply Late Penalties (10th of Month)', _autoPenalties, (val) => setState(() => _autoPenalties = val)),
          const SizedBox(height: 24),
          const Text('Lease Management', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildToggleTile('Auto-Generate Renewal Contracts', true, (val) {}),
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
        activeThumbColor: _neonBlue,
        value: val,
        onChanged: onChanged,
      ),
    );
  }
}
