import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'match_call_view.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _neonPink = Color(0xFFF92B60);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _textSecondary = Color(0xFF8B9BB4);

class MatchDiscoveryView extends StatefulWidget {
  const MatchDiscoveryView({super.key});

  @override
  State<MatchDiscoveryView> createState() => _MatchDiscoveryViewState();
}

class _MatchDiscoveryViewState extends State<MatchDiscoveryView> {
  List<Map<String, dynamic>> _profiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLocationAndProfiles();
  }

  Future<void> _fetchLocationAndProfiles() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services are disabled.')));
      return _fetchProfiles(null); 
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return _fetchProfiles(null); 
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return _fetchProfiles(null); 
    } 

    final position = await Geolocator.getCurrentPosition();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      await FirebaseFirestore.instance.collection('users').doc(currentUid).update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'location_updated_at': FieldValue.serverTimestamp(),
      });
    }

    _fetchProfiles(position);
  }

  Future<void> _fetchProfiles(Position? myPosition) async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      // Fetch users who are not the current user
      final snapshot = await FirebaseFirestore.instance.collection('users')
        .limit(20)
        .get();

      final profiles = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .where((user) {
             final email = (user['email'] as String?)?.toLowerCase() ?? '';
             final roles = user['roles'] as List<dynamic>? ?? [];
             final isTestAccount = user['isTestAccount'] == true || email.contains('test') || roles.contains('test');
             return user['id'] != currentUid && !isTestAccount;
          })
          .toList();

      if (mounted) {
        setState(() {
          _profiles = profiles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSwipe(bool isRight) {
    if (_profiles.isEmpty) return;
    
    // In a real app, record the like/pass to Firestore here.
    setState(() {
      _profiles.removeAt(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Find Your Match', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _neonCyan),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchLocationAndProfiles();
            },
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: _neonPink))
        : _profiles.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search_off, color: _textSecondary, size: 64),
                    const SizedBox(height: 16),
                    const Text('No more profiles nearby!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Check back later for new matches.', style: TextStyle(color: _textSecondary)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _neonPink),
                      onPressed: () {
                        setState(() => _isLoading = true);
                        _fetchLocationAndProfiles();
                      },
                      child: const Text('Refresh', style: TextStyle(color: Colors.white)),
                    )
                  ],
                ),
              )
            : Stack(
                children: _profiles.reversed.map((profile) {
                  int index = _profiles.indexOf(profile);
                  bool isTop = index == 0;

                  Widget card = _buildProfileCard(profile);

                  if (isTop) {
                    return Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Draggable(
                          childWhenDragging: Container(),
                          feedback: Material(
                            color: Colors.transparent,
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width - 32,
                              height: MediaQuery.of(context).size.height * 0.7,
                              child: Transform.rotate(
                                angle: 0.05,
                                child: card,
                              ),
                            ),
                          ),
                          onDragEnd: (details) {
                            if (details.offset.dx > 100) {
                              _onSwipe(true); // Right swipe
                            } else if (details.offset.dx < -100) {
                              _onSwipe(false); // Left swipe
                            }
                          },
                          child: card,
                        ),
                      ),
                    );
                  }

                  return Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Transform.scale(
                        scale: 0.95,
                        child: card,
                      ),
                    ),
                  );
                }).toList(),
              ),
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> profile) {
    String name = profile['displayName'] ?? 'Student';
    String? imageUrl = profile['profileImageUrl'];
    String bio = profile['bio'] ?? 'Computer Science • Year 2';
    String phone = profile['phoneNumber'] ?? 'Hidden';
    String? calleeId = profile['id'] ?? profile['uid']; // Fallbacks for different schemas

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(imageUrl, fit: BoxFit.cover)
                : Container(color: Colors.grey.shade900, child: const Icon(Icons.person, size: 100, color: Colors.white24)),
            
            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),

            // Profile Info & Actions
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      const Icon(Icons.verified, color: _neonCyan, size: 24),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(bio, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 24),
                  
                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceEvenly,
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildActionButton(Icons.close, Colors.redAccent, () => _onSwipe(false)),
                        _buildActionButton(Icons.call, _neonCyan, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => MatchCallView(
                            userName: name,
                            userAvatar: imageUrl ?? '',
                            calleeId: calleeId,
                            isVideoCall: false,
                          )));
                        }, isSmall: true),
                        _buildActionButton(Icons.videocam, _neonCyan, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => MatchCallView(
                            userName: name,
                            userAvatar: imageUrl ?? '',
                            calleeId: calleeId,
                            isVideoCall: true,
                          )));
                        }, isSmall: true),
                        _buildActionButton(Icons.chat_bubble, Colors.blueAccent, () {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Starting chat with $name...')));
                        }, isSmall: true),
                        _buildActionButton(Icons.favorite, _neonPink, () => _onSwipe(true)),
                      ],
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap, {bool isSmall = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isSmall ? 12 : 16),
        decoration: BoxDecoration(
          color: _bgColor.withOpacity(0.8),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: isSmall ? 1 : 2),
        ),
        child: Icon(icon, color: color, size: isSmall ? 24 : 36),
      ),
    );
  }
}
