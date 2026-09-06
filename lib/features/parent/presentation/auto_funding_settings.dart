import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _textSecondary = Color(0xFF8B9BB4);

class AutoFundingSettings extends StatefulWidget {
  final String studentUid;
  final String studentName;
  const AutoFundingSettings({super.key, required this.studentUid, required this.studentName});

  @override
  State<AutoFundingSettings> createState() => _AutoFundingSettingsState();
}

class _AutoFundingSettingsState extends State<AutoFundingSettings> {
  bool _autoTopup = false;
  final _thresholdController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.studentUid).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        if (data['autoTopUpThreshold'] != null && data['autoTopUpAmount'] != null) {
          _autoTopup = true;
          _thresholdController.text = data['autoTopUpThreshold'].toString();
          _amountController.text = data['autoTopUpAmount'].toString();
        }
      });
    }
  }

  void _saveSettings() async {
    if (!_autoTopup) {
      await FirebaseFirestore.instance.collection('users').doc(widget.studentUid).update({
        'autoTopUpThreshold': FieldValue.delete(),
        'autoTopUpAmount': FieldValue.delete(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Auto-funding disabled')));
      return;
    }
    
    final threshold = double.tryParse(_thresholdController.text);
    final amount = double.tryParse(_amountController.text);
    
    if (threshold == null || amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid numbers')));
      return;
    }
    
    await FirebaseFirestore.instance.collection('users').doc(widget.studentUid).update({
      'autoTopUpThreshold': threshold,
      'autoTopUpAmount': amount,
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Auto-funding settings saved')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text('Auto Funding - ${widget.studentName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Enable Auto-Topup', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Fund automatically from Vault', style: TextStyle(color: _textSecondary, fontSize: 12)),
                  ],
                ),
                Switch(
                  value: _autoTopup,
                  activeColor: _neonCyan,
                  onChanged: (val) {
                    setState(() => _autoTopup = val);
                    if (!val) _saveSettings();
                  },
                )
              ],
            ),
          ),
          if (_autoTopup) ...[
            const SizedBox(height: 24),
            _buildInputTile('When Balance Falls Below (KES)', _thresholdController),
            _buildInputTile('Topup Amount (KES)', _amountController),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _saveSettings,
              child: const Text('SAVE SETTINGS', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildInputTile(String label, TextEditingController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: _textSecondary),
          filled: true,
          fillColor: _surfaceLight,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}
