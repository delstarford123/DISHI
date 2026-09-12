import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _neonPink = Color(0xFFF92B60);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonYellow = Color(0xFFFFD700);

class MatchDiscoveryView extends StatefulWidget {
  // Optional user map — used to read current user's gender for filtering.
  final Map<String, dynamic>? currentUser;
  const MatchDiscoveryView({super.key, this.currentUser});

  @override
  State<MatchDiscoveryView> createState() => _MatchDiscoveryViewState();
}

class _MatchDiscoveryViewState extends State<MatchDiscoveryView> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _profiles = [];
  Map<String, dynamic>? _lastSwipedProfile;
  bool _isLoading = true;
  
  // Animation for "IT'S A MATCH" overlay
  late AnimationController _matchAnimController;
  bool _showMatchOverlay = false;
  String _matchedName = '';

  @override
  void initState() {
    super.initState();
    _matchAnimController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _fetchLocationAndProfiles();
  }

  @override
  void dispose() {
    _matchAnimController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocationAndProfiles() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return _fetchProfiles(null); 

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return _fetchProfiles(null); 
    }
    if (permission == LocationPermission.deniedForever) return _fetchProfiles(null); 

    final position = await Geolocator.getCurrentPosition();
    _fetchProfiles(position);
  }

  Future<void> _fetchProfiles(Position? myPosition) async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;

      // --- Gender filtering ---
      // Determine the current user's gender from Firestore or the passed widget map.
      String myGender = widget.currentUser?['gender'] as String? ?? '';
      if (myGender.isEmpty && currentUid != null) {
        final myDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .get();
        myGender = (myDoc.data()?['gender'] as String? ?? '').toLowerCase();
      } else {
        myGender = myGender.toLowerCase();
      }
      // Opposite gender to show: male sees female, female sees male, others see all
      final oppositeGender = myGender == 'male'
          ? 'female'
          : myGender == 'female'
              ? 'male'
              : '';

      Query query = FirebaseFirestore.instance
          .collection('users')
          .limit(50);

      // Apply gender filter only when we know the opposite gender
      if (oppositeGender.isNotEmpty) {
        query = query.where('gender', isEqualTo: oppositeGender);
      }

      final snapshot = await query.get();

      final profiles = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            // Use real photos from profile; fall back to a placeholder
            final avatar = data['profileImageUrl'] as String?;
            data['photos'] = avatar != null
                ? [avatar]
                : ['https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=300&q=80'];
            // Use real interests if stored, else empty
            data['interests'] =
                (data['interests'] as List?)?.cast<String>() ?? [];
            // Compute distance if location available
            if (myPosition != null &&
                data['latitude'] != null &&
                data['longitude'] != null) {
              final dist = Geolocator.distanceBetween(
                    myPosition.latitude,
                    myPosition.longitude,
                    (data['latitude'] as num).toDouble(),
                    (data['longitude'] as num).toDouble(),
                  ) /
                  1000;
              data['distance'] = dist.toStringAsFixed(1);
            } else {
              data['distance'] = '?';
            }
            data['isOnline'] = data['isOnline'] ?? false;
            return {'id': doc.id, ...data};
          })
          .where((user) => user['id'] != currentUid && user['id'] != null)
          .toList();

      if (mounted) setState(() { _profiles = profiles; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSwipe(bool isRight, bool isSuperLike) {
    if (_profiles.isEmpty) return;
    
    final profile = _profiles.first;
    setState(() {
      _lastSwipedProfile = profile;
      _profiles.removeAt(0);
    });
    
    if (isSuperLike) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Super Liked ${profile['displayName']}! ⭐', style: const TextStyle(color: Colors.black)), backgroundColor: _neonYellow));
    }
    
    // Simulate a 20% match chance on right swipe
    if (isRight && math.Random().nextDouble() > 0.8) {
      setState(() {
        _showMatchOverlay = true;
        _matchedName = profile['displayName'] ?? 'Someone';
      });
      _matchAnimController.forward().then((_) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() => _showMatchOverlay = false);
            _matchAnimController.reset();
          }
        });
      });
    }
  }
  
  void _rewind() {
    if (_lastSwipedProfile != null) {
      setState(() {
        _profiles.insert(0, _lastSwipedProfile!);
        _lastSwipedProfile = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rewound last profile! ⏪')));
    }
  }

  void _openExpandedProfile(Map<String, dynamic> profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExpandedProfileSheet(profile: profile),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Match Deck', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: _neonPink))
          else if (_profiles.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, color: Colors.white54, size: 64),
                  const SizedBox(height: 16),
                  const Text('No more profiles nearby!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _neonPink),
                    onPressed: () { setState(() => _isLoading = true); _fetchLocationAndProfiles(); },
                    child: const Text('Refresh', style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
            )
          else
            Stack(
              children: _profiles.reversed.map((profile) {
                int index = _profiles.indexOf(profile);
                bool isTop = index == 0;
                return Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: isTop ? _SwipeableCard(
                      profile: profile,
                      onSwipe: _onSwipe,
                      onTapUp: () => _openExpandedProfile(profile),
                    ) : Transform.scale(
                      scale: 0.95,
                      child: _SwipeableCard(profile: profile, isBackground: true),
                    ),
                  ),
                );
              }).toList(),
            ),
            
          // Floating Action Buttons (Rewind, Super Like)
          if (!_isLoading && _profiles.isNotEmpty)
            Positioned(
              bottom: 40, left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFab(Icons.replay, Colors.orangeAccent, _rewind, isSmall: true),
                  _buildFab(Icons.close, Colors.redAccent, () => _onSwipe(false, false)),
                  _buildFab(Icons.star, _neonYellow, () => _onSwipe(true, true), isSmall: true),
                  _buildFab(Icons.favorite, _neonCyan, () => _onSwipe(true, false)),
                ],
              ),
            ),
            
          // Match Overlay Animation
          if (_showMatchOverlay)
            IgnorePointer(
              child: Container(
                color: Colors.black87,
                child: Center(
                  child: FadeTransition(
                    opacity: _matchAnimController,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('IT\'S A MATCH!', style: TextStyle(color: _neonPink, fontSize: 48, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                        const SizedBox(height: 16),
                        Text('You and $_matchedName liked each other.', style: const TextStyle(color: Colors.white, fontSize: 18)),
                      ],
                    ),
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildFab(IconData icon, Color color, VoidCallback onTap, {bool isSmall = false}) {
    return FloatingActionButton(
      heroTag: icon.toString(),
      backgroundColor: _bgColor,
      shape: CircleBorder(side: BorderSide(color: color, width: 2)),
      mini: isSmall,
      onPressed: onTap,
      child: Icon(icon, color: color, size: isSmall ? 24 : 32),
    );
  }
}

class _SwipeableCard extends StatefulWidget {
  final Map<String, dynamic> profile;
  final Function(bool isRight, bool isSuper)? onSwipe;
  final VoidCallback? onTapUp;
  final bool isBackground;

  const _SwipeableCard({required this.profile, this.onSwipe, this.onTapUp, this.isBackground = false});

  @override
  State<_SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<_SwipeableCard> {
  int _currentPhotoIndex = 0;
  Offset _dragOffset = Offset.zero;

  void _nextPhoto() {
    final photos = widget.profile['photos'] as List;
    if (_currentPhotoIndex < photos.length - 1) setState(() => _currentPhotoIndex++);
  }

  void _prevPhoto() {
    if (_currentPhotoIndex > 0) setState(() => _currentPhotoIndex--);
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.profile['photos'] as List;
    final imageUrl = photos[_currentPhotoIndex];
    final bool isOnline = widget.profile['isOnline'] ?? false;
    
    // Calculate stamp opacity based on drag
    final double nopeOpacity = (_dragOffset.dx < 0 ? -_dragOffset.dx / 100 : 0.0).clamp(0.0, 1.0);
    final double likeOpacity = (_dragOffset.dx > 0 ? _dragOffset.dx / 100 : 0.0).clamp(0.0, 1.0);
    final double superOpacity = (_dragOffset.dy < 0 ? -_dragOffset.dy / 100 : 0.0).clamp(0.0, 1.0);

    Widget cardContent = Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 15, spreadRadius: 2)],
        image: DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Gradient
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black54, Colors.transparent, Colors.black87], stops: const [0.0, 0.4, 1.0]),
            ),
          ),
          
          // Photo Indicators
          Positioned(
            top: 12, left: 12, right: 12,
            child: Row(
              children: List.generate(photos.length, (i) => Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 4,
                  decoration: BoxDecoration(color: _currentPhotoIndex == i ? Colors.white : Colors.white38, borderRadius: BorderRadius.circular(2)),
                ),
              )),
            ),
          ),
          
          // Photo tap zones
          if (!widget.isBackground)
            Row(
              children: [
                Expanded(child: GestureDetector(onTap: _prevPhoto, behavior: HitTestBehavior.opaque)),
                Expanded(child: GestureDetector(onTap: _nextPhoto, behavior: HitTestBehavior.opaque)),
              ],
            ),
            
          // Profile Info (Tappable to expand)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: GestureDetector(
              onTap: widget.onTapUp,
              child: Container(
                padding: const EdgeInsets.all(20),
                color: Colors.transparent, // To catch taps
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(widget.profile['displayName'] ?? 'Student', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))),
                        if (isOnline) Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${widget.profile['distance']}km away', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 8),
                    // Spotify Anthem
                    Row(
                      children: [
                        const Icon(Icons.album, color: Colors.greenAccent, size: 16),
                        const SizedBox(width: 4),
                        Text(widget.profile['spotify'] ?? '', style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 80), // Space for FABs
                  ],
                ),
              ),
            ),
          ),
          
          // DRAG STAMPS
          if (likeOpacity > 0.1) Positioned(top: 60, left: 20, child: Transform.rotate(angle: -0.2, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: _neonCyan, width: 4), borderRadius: BorderRadius.circular(12)), child: Text('LIKE', style: TextStyle(color: _neonCyan.withOpacity(likeOpacity), fontSize: 40, fontWeight: FontWeight.bold))))),
          if (nopeOpacity > 0.1) Positioned(top: 60, right: 20, child: Transform.rotate(angle: 0.2, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: Colors.redAccent, width: 4), borderRadius: BorderRadius.circular(12)), child: Text('NOPE', style: TextStyle(color: Colors.redAccent.withOpacity(nopeOpacity), fontSize: 40, fontWeight: FontWeight.bold))))),
          if (superOpacity > 0.1) Positioned(bottom: 160, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: _neonYellow, width: 4), borderRadius: BorderRadius.circular(12)), child: Text('SUPER', style: TextStyle(color: _neonYellow.withOpacity(superOpacity), fontSize: 40, fontWeight: FontWeight.bold))))),
        ],
      ),
    );

    if (widget.isBackground) return cardContent;

    return GestureDetector(
      onPanUpdate: (details) {
        setState(() => _dragOffset += details.delta);
      },
      onPanEnd: (details) {
        if (_dragOffset.dy < -150) {
          widget.onSwipe?.call(true, true); // Super Like
        } else if (_dragOffset.dx > 100) {
          widget.onSwipe?.call(true, false); // Right
        } else if (_dragOffset.dx < -100) {
          widget.onSwipe?.call(false, false); // Left
        } else {
          setState(() => _dragOffset = Offset.zero); // Snap back
        }
      },
      child: Transform.translate(
        offset: _dragOffset,
        child: Transform.rotate(
          angle: _dragOffset.dx / 1000,
          child: cardContent,
        ),
      ),
    );
  }
}

class _ExpandedProfileSheet extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _ExpandedProfileSheet({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(color: Color(0xFF0F172A), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Image
                Image.network(profile['photos'][0], height: 400, width: double.infinity, fit: BoxFit.cover),
                
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile['displayName'] ?? 'Student', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(profile['bio'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                      const SizedBox(height: 24),
                      
                      const Text('Interests', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: (profile['interests'] as List).map((i) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: i == 'Gym' ? Colors.greenAccent.withOpacity(0.2) : Colors.white10, borderRadius: BorderRadius.circular(16), border: Border.all(color: i == 'Gym' ? Colors.greenAccent : Colors.transparent)),
                          child: Text(i, style: TextStyle(color: i == 'Gym' ? Colors.greenAccent : Colors.white)),
                        )).toList(),
                      ),
                      const SizedBox(height: 32),
                      
                      _buildPrompt(profile['prompt1']),
                      const SizedBox(height: 16),
                      _buildPrompt(profile['prompt2']),
                      
                      const SizedBox(height: 100), // Space for bottom buttons
                    ],
                  ),
                )
              ],
            ),
          ),
          
          Positioned(
            top: 16, right: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white), onPressed: () => Navigator.pop(context)),
            ),
          )
        ],
      ),
    );
  }
  
  Widget _buildPrompt(Map<String, dynamic> prompt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(prompt['q'], style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 8),
          Text(prompt['a'], style: const TextStyle(color: Colors.white, fontSize: 20, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}
