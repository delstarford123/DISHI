import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:uuid/uuid.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF161B29);
const Color _neonPink = Color(0xFFFF2A5F);
const Color _textSecondary = Color(0xFF8B9BB4);

class SecuritySettings extends StatefulWidget {
  final String studentUid;
  final String studentName;
  final String parentUid;

  const SecuritySettings({super.key, required this.studentUid, required this.studentName, required this.parentUid});

  @override
  State<SecuritySettings> createState() => _SecuritySettingsState();
}

class _SecuritySettingsState extends State<SecuritySettings> {
  bool _isLoading = false;
  
  // Whitelisting
  final List<Map<String, String>> _mockVendors = [
    {'id': 'vendor_canteen_1', 'name': 'Main Canteen'},
    {'id': 'vendor_stationery_1', 'name': 'Stationery Shop'},
    {'id': 'vendor_kiosk_outside', 'name': 'Street Kiosk'},
  ];
  List<String> _whitelistedVendors = [];

  // Time Windows
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  List<Map<String, String>> _timeWindows = [];
  
  // Data
  String? _dishiId;
  String? _studentImageUrl;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.studentUid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _whitelistedVendors = List<String>.from(data['whitelistedVendors'] ?? []);
          _dishiId = data['dishiId'];
          _studentImageUrl = data['studentImageUrl'];
          
          if (data['allowedTimeWindows'] != null) {
            _timeWindows = List<Map<String, String>>.from(
              (data['allowedTimeWindows'] as List).map((e) => Map<String, String>.from(e))
            );
          }
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.studentUid).update({
        'whitelistedVendors': _whitelistedVendors,
        'allowedTimeWindows': _timeWindows,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Security settings saved'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _generateTempPin() async {
    final pin = (1000 + Random().nextInt(9000)).toString(); // 4 digits
    final expiresAt = DateTime.now().add(const Duration(minutes: 5));
    
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.studentUid).update({
        'tempPin': {
          'pin': pin,
          'expiresAt': Timestamp.fromDate(expiresAt),
        }
      });
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _cardColor,
            title: const Text('Temp PIN Generated', style: TextStyle(color: _neonPink)),
            content: Text('Temporary PIN: $pin\n\nThis PIN is valid for exactly 5 minutes.', style: const TextStyle(color: Colors.white, fontSize: 18)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))
            ],
          )
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _voidAndReissue() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Void & Reissue Tag', style: TextStyle(color: Colors.red)),
        content: const Text('This will instantly invalidate the current QR tag and generate a new one. Proceed?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Void', style: TextStyle(color: Colors.white))
          ),
        ],
      )
    );

    if (confirm != true) return;

    final newDishiId = const Uuid().v4();
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.studentUid).update({
        'dishiId': newDishiId
      });
      setState(() {
        _dishiId = newDishiId;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tag successfully reissued. Provide new QR to admin.'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _mockImageUpload() async {
    // In a real app, this would use image_picker and firebase_storage.
    // For prototype, we set a mock image.
    final mockUrl = 'https://i.pravatar.cc/150?u=${widget.studentUid}';
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.studentUid).update({
        'studentImageUrl': mockUrl
      });
      setState(() {
        _studentImageUrl = mockUrl;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image successfully enrolled for biometric verification.'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startTime = picked;
        else _endTime = picked;
      });
    }
  }

  void _addTimeWindow() {
    if (_startTime != null && _endTime != null) {
      final startStr = '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}';
      final endStr = '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}';
      setState(() {
        _timeWindows.add({'start': startStr, 'end': endStr});
        _startTime = null;
        _endTime = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text('Security - ${widget.studentName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: _neonPink))
        : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // BIOMETRICS
          const Text('Biometric & Visual Verification', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Upload student photo. This appears on the vendor POS when verifying identity (Biometric/QR scan).', style: TextStyle(color: _textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: _cardColor,
                  backgroundImage: _studentImageUrl != null ? NetworkImage(_studentImageUrl!) : null,
                  child: _studentImageUrl == null ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _mockImageUpload,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Capture Biometric / Photo'),
                  style: ElevatedButton.styleFrom(backgroundColor: _neonPink, foregroundColor: Colors.white),
                )
              ],
            ),
          ),
          
          const Divider(color: _cardColor, height: 48),

          // VENDOR WHITELISTING
          const Text('Vendor Whitelisting', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Select approved vendors. Transactions elsewhere will be blocked.', style: TextStyle(color: _textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _mockVendors.map((vendor) {
              final isSelected = _whitelistedVendors.contains(vendor['id']);
              return FilterChip(
                label: Text(vendor['name']!),
                selected: isSelected,
                selectedColor: _neonPink.withOpacity(0.3),
                checkmarkColor: _neonPink,
                backgroundColor: _cardColor,
                labelStyle: TextStyle(color: isSelected ? _neonPink : Colors.white),
                onSelected: (val) {
                  setState(() {
                    if (val) _whitelistedVendors.add(vendor['id']!);
                    else _whitelistedVendors.remove(vendor['id']);
                  });
                },
              );
            }).toList(),
          ),

          const Divider(color: _cardColor, height: 48),

          // TIME WINDOWS
          const Text('Restricted Time Windows', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Lock tag to specific hours (e.g. Break time). Empty list means allowed 24/7.', style: TextStyle(color: _textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: ElevatedButton(onPressed: () => _selectTime(context, true), style: ElevatedButton.styleFrom(backgroundColor: _cardColor), child: Text(_startTime?.format(context) ?? 'Start Time'))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton(onPressed: () => _selectTime(context, false), style: ElevatedButton.styleFrom(backgroundColor: _cardColor), child: Text(_endTime?.format(context) ?? 'End Time'))),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.add_circle, color: _neonPink), onPressed: _addTimeWindow),
            ],
          ),
          const SizedBox(height: 8),
          ..._timeWindows.map((tw) => ListTile(
            title: Text('${tw['start']} to ${tw['end']}', style: const TextStyle(color: Colors.white)),
            trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _timeWindows.remove(tw))),
          )),

          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonPink, padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: _saveSettings,
            child: const Text('SAVE SECURITY SETTINGS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),

          const Divider(color: _cardColor, height: 48),
          
          // EMERGENCY ACTIONS
          const Text('Emergency Actions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _generateTempPin,
                  icon: const Icon(Icons.pin),
                  label: const Text('Temp PIN'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _voidAndReissue,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Void Tag'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
