import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonPurple = Color(0xFF9C27B0);
const Color _textSecondary = Color(0xFF8B9BB4);

class MatchCrushRadarView extends StatefulWidget {
  final Map<String, dynamic>? userModel;
  
  const MatchCrushRadarView({super.key, this.userModel});

  @override
  State<MatchCrushRadarView> createState() => _MatchCrushRadarViewState();
}

class _MatchCrushRadarViewState extends State<MatchCrushRadarView> with SingleTickerProviderStateMixin {
  late AnimationController _radarController;
  bool _isLoading = true;
  List<dynamic> _radarHits = [];

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _fetchRadarData();
  }

  Future<void> _fetchRadarData() async {
    final String uid = widget.userModel?['uid'] ?? 'guest';
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .limit(10)
          .get();
      
      final List<dynamic> hits = [];
      for (var doc in snapshot.docs) {
        if (doc.id != uid) {
          final data = doc.data();
          hits.add({
            'uid': doc.id,
            'name': data['firstName'] ?? data['username'] ?? 'Anonymous',
            'isVerified': data['isVerified'] ?? false,
          });
        }
      }
      
      if (mounted) {
        setState(() {
          _radarHits = hits;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Crush Radar 2.0', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Animated Radar Rings
                AnimatedBuilder(
                  animation: _radarController,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 250 * _radarController.value, 
                          height: 250 * _radarController.value, 
                          decoration: BoxDecoration(
                            shape: BoxShape.circle, 
                            border: Border.all(color: _neonPink.withOpacity(1.0 - _radarController.value), width: 2)
                          )
                        ),
                      ],
                    );
                  },
                ),
                Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _neonPink.withOpacity(0.2), width: 1))),
                Container(width: 140, height: 140, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _neonPink.withOpacity(0.5), width: 1))),
                Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _neonPink, width: 2))),
                const Icon(Icons.favorite, color: _neonPink, size: 40),
                
                // Draw dynamic blips based on hits
                if (!_isLoading) ..._buildDynamicBlips()
              ],
            ),
            const SizedBox(height: 40),
            
            if (_isLoading)
              const Text('Scanning campus...', style: TextStyle(color: _textSecondary, fontSize: 16))
            else ...[
              Text('${_radarHits.length} Potential Matches Nearby!', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_radarHits.isNotEmpty)
                const Text('They are currently at the Library & Student Center.', style: TextStyle(color: _textSecondary)),
              const SizedBox(height: 32),
              if (_radarHits.isNotEmpty)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _neonPurple, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16)),
                  onPressed: () {},
                  child: const Text('SEND VIBE CHECKS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
            ]
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDynamicBlips() {
    return List.generate(_radarHits.length, (index) {
      final hit = _radarHits[index];
      // Randomly position them on the radar
      final double angle = (index * (360 / _radarHits.length)) * (math.pi / 180);
      final double radius = 50.0 + (index * 20); // 50 to 150
      
      final dx = radius * math.cos(angle);
      final dy = radius * math.sin(angle);

      return Transform.translate(
        offset: Offset(dx, dy),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(color: Colors.cyanAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.cyanAccent, blurRadius: 10, spreadRadius: 2)]),
            ),
            const SizedBox(height: 4),
            Text(hit['name'], style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            if (hit['isVerified'])
              const Icon(Icons.verified, color: Colors.blueAccent, size: 10)
          ],
        ),
      );
    });
  }
}
