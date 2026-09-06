import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MatchStudyBuddyView extends StatefulWidget {
  final Map<String, dynamic>? userModel;
  
  const MatchStudyBuddyView({super.key, this.userModel});

  @override
  State<MatchStudyBuddyView> createState() => _MatchStudyBuddyViewState();
}

class _MatchStudyBuddyViewState extends State<MatchStudyBuddyView> {
  bool _isAcademicMode = false;
  bool _isToggling = false;
  List<Map<String, dynamic>> _buddies = [];

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    final String uid = widget.userModel?['uid'] ?? 'guest';
    if (uid == 'guest') return;
    
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists && doc.data()?['isAcademicMode'] == true) {
      setState(() => _isAcademicMode = true);
      _fetchBuddies();
    }
  }

  Future<void> _fetchBuddies() async {
    final String uid = widget.userModel?['uid'] ?? 'guest';
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('isAcademicMode', isEqualTo: true)
          .limit(10)
          .get();
      
      final List<Map<String, dynamic>> list = [];
      for (var doc in snapshot.docs) {
        if (doc.id != uid) {
          final data = doc.data();
          list.add({
            'name': data['firstName'] ?? data['username'] ?? 'Anonymous',
            'units': data['study_units'] ?? 'CSC 311', // Placeholder if they don't have study units array
            'status': 'Available',
          });
        }
      }
      
      if (mounted) {
        setState(() {
          _buddies = list;
        });
      }
    } catch (e) {
      debugPrint('Error fetching buddies: $e');
    }
  }

  Future<void> _toggleAcademicMode(bool value) async {
    setState(() {
      _isToggling = true;
    });

    final String uid = widget.userModel?['uid'] ?? 'guest';
    if (uid == 'guest') {
      setState(() => _isToggling = false);
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isAcademicMode': value,
      });

      if (mounted) {
        setState(() {
          _isAcademicMode = value;
          _isToggling = false;
        });
        
        if (value) {
          _fetchBuddies();
        } else {
          setState(() => _buddies = []);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(value ? 'Academic Mode Activated! 📚' : 'Academic Mode Deactivated.'))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isToggling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic Theme colors based on mode
    final Color bgColor = _isAcademicMode ? const Color(0xFF0F172A) : const Color(0xFF0C101B);
    final Color cardColor = _isAcademicMode ? const Color(0xFF1E293B) : const Color(0xFF131A2A);
    final Color accentColor = _isAcademicMode ? Colors.blueAccent : const Color(0xFF9C27B0);
    
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Study Buddies', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // The Toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentColor.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Academic Mode', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 4),
                    const Text('Switch algorithm to academic matching.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
                _isToggling 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator())
                    : Switch(
                        value: _isAcademicMode,
                        activeColor: accentColor,
                        onChanged: _toggleAcademicMode,
                      )
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          if (_isAcademicMode) ...[
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by Unit Code (e.g. CSC 311)...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            if (_buddies.isEmpty)
              const Center(child: Text('No study buddies found yet.', style: TextStyle(color: Colors.white54)))
            else
              ..._buddies.map((b) => _buildBuddyCard(b['name'], b['units'], b['status'], cardColor, accentColor)),
          ] else ...[
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('Toggle Academic Mode to view your study buddy matches.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildBuddyCard(String name, String units, String status, Color cardColor, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const CircleAvatar(backgroundColor: Colors.white12, child: Icon(Icons.person, color: Colors.white54)),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(units, style: TextStyle(color: accentColor, fontSize: 12)),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(status, style: const TextStyle(color: Colors.white, fontSize: 12)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(20)),
                child: const Text('INVITE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
              )
            ],
          )
        ],
      ),
    );
  }
}
