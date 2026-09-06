import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonPurple = Color(0xFF9C27B0);
const Color _surfaceLight = Color(0xFF1A2235);

class MatchSafeWalkView extends StatefulWidget {
  final Map<String, dynamic>? userModel;
  final String targetUid;
  
  const MatchSafeWalkView({super.key, this.userModel, this.targetUid = 'trusted_friend'});

  @override
  State<MatchSafeWalkView> createState() => _MatchSafeWalkViewState();
}

class _MatchSafeWalkViewState extends State<MatchSafeWalkView> with SingleTickerProviderStateMixin {
  bool _isTracking = false;
  late AnimationController _pulseController;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleSafeWalk() async {
    final String uid = widget.userModel?['uid'] ?? 'guest';
    
    if (_isTracking) {
      // Arrived Safely
      setState(() => _isTracking = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Arrived safely! Tracking data purged.')));
      // In a real app, hit backend to delete the session
    } else {
      // Start Tracking
      setState(() => _isTracking = true);
      try {
        final docRef = await FirebaseFirestore.instance.collection('safe_walk_sessions').add({
          'uid': uid,
          'targetMatchUid': widget.targetUid,
          'status': 'active',
          'startedAt': FieldValue.serverTimestamp(),
        });
        
        _sessionId = docRef.id;
        debugPrint('Started safe walk session: $_sessionId');
      } catch (e) {
        debugPrint('Safe walk start failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Safe Walk Home', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, color: _neonPurple, size: 80),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Walking back to your dorm late? Activate Safe Walk to share your live GPS exclusively with your trusted match.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
            const SizedBox(height: 60),
            
            if (_isTracking)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.1),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.5 * (1 - _pulseController.value)),
                            blurRadius: 30 * _pulseController.value,
                            spreadRadius: 15 * _pulseController.value,
                          )
                        ],
                      ),
                      child: child,
                    ),
                  );
                },
                child: GestureDetector(
                  onTap: _toggleSafeWalk,
                  child: const CircleAvatar(
                    radius: 80,
                    backgroundColor: Colors.red,
                    child: Text('ARRIVED SAFELY', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: _toggleSafeWalk,
                child: const CircleAvatar(
                  radius: 80,
                  backgroundColor: _neonPurple,
                  child: Text('START TRACKING', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              ),
              
            const SizedBox(height: 40),
            if (_isTracking)
              const Text('Broadcasting Live Location...', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
