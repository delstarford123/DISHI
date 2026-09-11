import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'match_vibe_check_dialog.dart';
import 'match_chat_view.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonPurple = Color(0xFF9C27B0);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _textSecondary = Color(0xFF8B9BB4);

class MatchCrushRadarView extends StatefulWidget {
  final Map<String, dynamic>? userModel;
  
  const MatchCrushRadarView({super.key, this.userModel});

  @override
  State<MatchCrushRadarView> createState() => _MatchCrushRadarViewState();
}

class _MatchCrushRadarViewState extends State<MatchCrushRadarView> with TickerProviderStateMixin {
  late AnimationController _radarController;
  late AnimationController _blipController;
  bool _isLoading = true;
  List<dynamic> _radarHits = [];
  
  double _radarRange = 5.0; // km
  bool _ghostMode = false;
  String _selectedFaculty = 'All';
  final List<String> _faculties = ['All', 'Engineering', 'Law', 'Business', 'Arts', 'Science', 'Med'];

  String get currentUid => FirebaseAuth.instance.currentUser?.uid ?? 'guest';

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _blipController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _fetchRadarData();
  }

  Future<void> _fetchRadarData() async {
    setState(() => _isLoading = true);
    try {
      // Get current user's gender to filter for opposite gender
      String myGender = 'male';
      try {
        final myDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .get();
        myGender = (myDoc.data()?['gender'] ?? 'male').toString().toLowerCase();
      } catch (_) {}
      final oppositeGender = myGender == 'male' ? 'female' : 'male';

      Query query = FirebaseFirestore.instance
          .collection('users')
          .where('gender', isEqualTo: oppositeGender)
          .limit(20);

      if (_selectedFaculty != 'All') {
        query = query.where('faculty', isEqualTo: _selectedFaculty);
      }

      final snapshot = await query.get();
      final random = math.Random();

      final List<dynamic> hits = snapshot.docs
          .where((doc) => doc.id != currentUid)
          .map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final distance = (random.nextDouble() * _radarRange).toStringAsFixed(1);
        final compatibility = 60 + random.nextInt(39);
        final locations = ['Library', 'Student Center', 'Mess Hall', 'Dorms', 'Cafe'];
        return {
          'uid': doc.id,
          'name': data['displayName'] ?? data['firstName'] ?? 'Anonymous',
          'profileImageUrl': data['profileImageUrl'],
          'isVerified': data['isVerified'] ?? false,
          'distance': distance,
          'location': locations[random.nextInt(locations.length)],
          'compatibility': compatibility,
          'faculty': data['faculty'] ?? 'Unknown',
          'lastActive': DateTime.now().subtract(Duration(minutes: random.nextInt(60))),
        };
      }).toList();

      if (mounted) {
        setState(() {
          _radarHits = hits;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sendPing(Map<String, dynamic> hit) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pinged ${hit['name']}! 📍', style: const TextStyle(color: Colors.white)), backgroundColor: _neonPurple));
  }

  void _directDM(Map<String, dynamic> hit) {
    final sortedUids = [currentUid, hit['uid']]..sort();
    final realChatId = sortedUids.join('_');
    
    Navigator.push(context, MaterialPageRoute(builder: (_) => MatchChatView(
      chatId: realChatId,
      myUid: currentUid,
      matchName: hit['name'],
      matchAvatar: hit['profileImageUrl'],
      matchId: hit['uid'],
    )));
  }

  void _mutualCrushCheck(Map<String, dynamic> hit) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildTargetSheet(hit),
    );
  }

  Widget _buildTargetSheet(Map<String, dynamic> hit) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(hit['name'], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  if (hit['isVerified']) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, color: Colors.blueAccent, size: 20)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _neonPink.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Text('${hit['compatibility']}% Match', style: const TextStyle(color: _neonPink, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on, color: _neonCyan, size: 16),
              const SizedBox(width: 4),
              Text('${hit['distance']}km away • Last seen at ${hit['location']}', style: const TextStyle(color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.school, color: _neonPurple, size: 16),
              const SizedBox(width: 4),
              Text('Faculty of ${hit['faculty']}', style: const TextStyle(color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionBtn(Icons.wifi_tethering, 'Ping', Colors.orange, () { Navigator.pop(context); _sendPing(hit); }),
              _buildActionBtn(Icons.favorite, 'Vibe Check', _neonPink, () {
                Navigator.pop(context);
                showDialog(context: context, builder: (context) => MatchVibeCheckDialog(receiverId: hit['uid'], receiverName: hit['name']));
              }),
              _buildActionBtn(Icons.chat_bubble, 'Direct DM', _neonCyan, () { Navigator.pop(context); _directDM(hit); }),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _radarController.dispose();
    _blipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Crush Radar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(_ghostMode ? Icons.visibility_off : Icons.visibility, color: _ghostMode ? Colors.grey : _neonCyan),
            tooltip: 'Ghost Mode',
            onPressed: () {
              setState(() => _ghostMode = !_ghostMode);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_ghostMode ? 'Ghost Mode ON: You are hidden from the radar.' : 'Ghost Mode OFF: You are visible on the radar.')));
            },
          )
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Stack(
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
                                width: 300 * _radarController.value,
                                height: 300 * _radarController.value,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: _neonPink.withOpacity(
                                            1.0 - _radarController.value),
                                        width: 2))),
                          ],
                        );
                      },
                    ),
                    Container(width: 240, height: 240, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _neonPink.withOpacity(0.2), width: 1))),
                    Container(width: 160, height: 160, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _neonPink.withOpacity(0.5), width: 1))),
                    Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _neonPink, width: 2))),
                    Icon(Icons.radar, color: _ghostMode ? Colors.grey : _neonPink, size: 40),

                    if (!_isLoading) ..._buildDynamicBlips()
                  ],
                ),
              ),
            ),
          ),
          
          if (_isLoading)
            const Padding(padding: EdgeInsets.all(24), child: Text('Scanning campus...', style: TextStyle(color: _textSecondary, fontSize: 16)))
          else
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF131A2A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Text('${_radarHits.length} Crushes Found within ${_radarRange.toInt()}km', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Tap a blip to view their profile, ping them, or send a vibe check!', style: TextStyle(color: _textSecondary, fontSize: 12), textAlign: TextAlign.center),
                ],
              ),
            )
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows, color: Colors.white54, size: 16),
              const SizedBox(width: 8),
              Text('Range: ${_radarRange.toInt()}km', style: const TextStyle(color: Colors.white)),
              Expanded(
                child: Slider(
                  value: _radarRange,
                  min: 1,
                  max: 10,
                  divisions: 9,
                  activeColor: _neonPink,
                  onChanged: (v) {
                    setState(() => _radarRange = v);
                  },
                  onChangeEnd: (v) => _fetchRadarData(),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _faculties.length,
              itemBuilder: (context, index) {
                final f = _faculties[index];
                final isSel = f == _selectedFaculty;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f, style: TextStyle(fontSize: 12, color: isSel ? Colors.black : Colors.white)),
                    selected: isSel,
                    selectedColor: _neonCyan,
                    backgroundColor: Colors.white10,
                    onSelected: (val) {
                      setState(() => _selectedFaculty = f);
                      _fetchRadarData();
                    },
                  ),
                );
              }
            ),
          )
        ],
      ),
    );
  }

  List<Widget> _buildDynamicBlips() {
    return List.generate(_radarHits.length, (index) {
      final hit = _radarHits[index];
      // Distribute based on distance
      final double angle = (index * (360 / _radarHits.length)) * (math.pi / 180);
      
      // Calculate radius based on their distance vs radar range (max radius ~140)
      final double distanceRatio = double.parse(hit['distance']) / _radarRange;
      final double radius = 50.0 + (90.0 * distanceRatio.clamp(0.0, 1.0)); 
      
      final dx = radius * math.cos(angle);
      final dy = radius * math.sin(angle);

      return Transform.translate(
        offset: Offset(dx, dy),
        child: GestureDetector(
          onTap: () => _mutualCrushCheck(hit),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _blipController,
                builder: (context, child) {
                  return Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _neonCyan, 
                      shape: BoxShape.circle, 
                      boxShadow: [BoxShadow(color: _neonCyan.withOpacity(_blipController.value), blurRadius: 10, spreadRadius: 3)]
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                child: Text('${hit['name']}\n${hit['compatibility']}%', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      );
    });
  }
}
