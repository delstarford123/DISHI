import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/geofence_service.dart';
import '../../../core/theme/mpesa_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────
const _bgColor = Color(0xFF0C101B);
const _cardColor = Color(0xFF131A2A);
const _neonCyan = Color(0xFF05D5AA);
const _neonBlue = Color(0xFF3B82F6);
const _neonPink = Color(0xFFF92B60);
const _neonGreen = Color(0xFF22C55E);
const _textSecondary = Color(0xFF8B9BB4);

// Campus centre fallback
const LatLng _campusCenter = LatLng(-1.2793, 36.8166);

enum _SocialMapTab { meetup, heatmap }

/// Social map view combining:
///  • Temporary 30-minute "Meet Up" live share
///  • Study Group Heatmaps (circle density overlays from Firestore)
///  • Proximity Alerts toggle
class MeetupShareView extends StatefulWidget {
  final String studentUid;
  final String studentName;

  const MeetupShareView({
    super.key,
    required this.studentUid,
    required this.studentName,
  });

  @override
  State<MeetupShareView> createState() => _MeetupShareViewState();
}

class _MeetupShareViewState extends State<MeetupShareView> {
  GoogleMapController? _mapController;
  Position? _myPosition;
  StreamSubscription<Position>? _posSub;
  _SocialMapTab _activeTab = _SocialMapTab.meetup;
  bool _isCameraInitialized = false;

  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};
  final Set<Polyline> _polylines = {};

  // Meetup share state
  String? _activeMeetupShareId;
  Timer? _meetupTimer;
  int _meetupSecondsLeft = 0;
  StreamSubscription<DocumentSnapshot>? _meetupSub;

  // Proximity alerts
  bool _proximityAlertsEnabled = false;

  // Study zones
  List<Map<String, dynamic>> _studyZones = [];

  @override
  void initState() {
    super.initState();
    _startPositionWatch();
    _loadProximitySettings();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _meetupSub?.cancel();
    _meetupTimer?.cancel();
    _mapController?.dispose();
    if (_activeMeetupShareId != null) {
      GeofenceService.cancelMeetupShare(_activeMeetupShareId!);
    }
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOCATION
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _startPositionWatch() async {
    final err = await LocationService.ensurePermissions();
    if (err != null) return;
    
    try {
      final pos = await LocationService.getCurrentLocation();
      if (mounted) {
        setState(() => _myPosition = pos);
        if (_mapController != null && !_isCameraInitialized) {
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(CameraPosition(
              target: LatLng(pos.latitude, pos.longitude),
              zoom: 15,
            )),
          );
          _isCameraInitialized = true;
        }
      }
    } catch (_) {}

    _posSub = LocationService.getLocationStream(distanceFilter: 10)
        .listen((pos) {
      setState(() => _myPosition = pos);
      
      if (!_isCameraInitialized && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(CameraPosition(
            target: LatLng(pos.latitude, pos.longitude),
            zoom: 15,
          )),
        );
        _isCameraInitialized = true;
      }
      
      // Update active meetup share
      if (_activeMeetupShareId != null) {
        GeofenceService.updateMeetupShare(_activeMeetupShareId!, pos);
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PROXIMITY ALERTS SETTINGS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadProximitySettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.studentUid)
          .get();
      if (doc.exists) {
        setState(() {
          _proximityAlertsEnabled =
              doc.data()?['proximityAlertsEnabled'] as bool? ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleProximityAlerts(bool value) async {
    setState(() => _proximityAlertsEnabled = value);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.studentUid)
        .set({'proximityAlertsEnabled': value}, SetOptions(merge: true));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MEETUP SHARE
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _startMeetupShare(String targetUid) async {
    if (_myPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Waiting for GPS fix...'),
          backgroundColor: _neonBlue,
        ),
      );
      return;
    }

    final shareId = await GeofenceService.createMeetupShare(
        widget.studentUid, targetUid, _myPosition!);
    setState(() {
      _activeMeetupShareId = shareId;
      _meetupSecondsLeft = 1800; // 30 minutes
    });

    // Subscribe to peer's view of the share
    _meetupSub = FirebaseFirestore.instance
        .collection('meetup_shares')
        .doc(shareId)
        .snapshots()
        .listen(_onMeetupShareUpdate);

    // Countdown timer
    _meetupTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _meetupSecondsLeft--);
      if (_meetupSecondsLeft <= 0) {
        t.cancel();
        _stopMeetupShare();
      }
    });

    _rebuildMeetupLayer();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _neonGreen,
        content: const Text(
          '📡 Live share started for 30 minutes',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        action: SnackBarAction(
          label: 'Stop',
          textColor: Colors.black,
          onPressed: _stopMeetupShare,
        ),
      ),
    );
  }

  void _onMeetupShareUpdate(DocumentSnapshot snap) {
    if (!snap.exists) return;
    final data = snap.data() as Map<String, dynamic>;
    if (!GeofenceService.isMeetupShareValid(data)) {
      _stopMeetupShare();
      return;
    }
    _rebuildMeetupLayer();
  }

  Future<void> _stopMeetupShare() async {
    if (_activeMeetupShareId == null) return;
    await GeofenceService.cancelMeetupShare(_activeMeetupShareId!);
    _meetupTimer?.cancel();
    _meetupSub?.cancel();
    setState(() {
      _activeMeetupShareId = null;
      _meetupSecondsLeft = 0;
    });
    _rebuildMeetupLayer();
  }

  void _rebuildMeetupLayer() {
    final newMarkers = <Marker>{};
    final newCircles = <Circle>{};

    if (_myPosition != null) {
      newMarkers.add(Marker(
        markerId: const MarkerId('me'),
        position: LatLng(_myPosition!.latitude, _myPosition!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: '📍 ${widget.studentName} (You)'),
      ));

      if (_activeMeetupShareId != null) {
        // Pulsing share radius circle
        newCircles.add(Circle(
          circleId: const CircleId('share_radius'),
          center: LatLng(_myPosition!.latitude, _myPosition!.longitude),
          radius: 100,
          fillColor: _neonCyan.withOpacity(0.1),
          strokeColor: _neonCyan,
          strokeWidth: 2,
        ));
      }
    }

    setState(() {
      _markers
        ..clear()
        ..addAll(newMarkers);
      _circles
        ..clear()
        ..addAll(newCircles);
    });
  }

  String _formatCountdown(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STUDY HEATMAP
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadStudyHeatmap() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('study_zones')
          .get();

      final zones = snap.docs.map((d) {
        final data = d.data();
        return {...data, 'id': d.id};
      }).toList();

      final newCircles = <Circle>{};
      for (final zone in zones) {
        final lat = (zone['lat'] as num?)?.toDouble();
        final lng = (zone['lng'] as num?)?.toDouble();
        final occupancy = (zone['occupancyCount'] as num?)?.toInt() ?? 0;
        final name = zone['name'] as String? ?? 'Zone';
        if (lat == null || lng == null) continue;

        // Scale radius and color by occupancy
        final radius = 30.0 + (occupancy * 2).clamp(0, 100);
        final Color heatColor = occupancy <= 5
            ? _neonGreen
            : occupancy <= 15
                ? const Color(0xFFEAB308) // yellow
                : const Color(0xFFEF4444); // red

        newCircles.add(Circle(
          circleId: CircleId('study_${zone['id']}'),
          center: LatLng(lat, lng),
          radius: radius,
          fillColor: heatColor.withOpacity(0.3),
          strokeColor: heatColor,
          strokeWidth: 2,
        ));
        _markers.add(Marker(
          markerId: MarkerId('study_label_${zone['id']}'),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            occupancy <= 5
                ? BitmapDescriptor.hueGreen
                : occupancy <= 15
                    ? BitmapDescriptor.hueYellow
                    : BitmapDescriptor.hueRed,
          ),
          infoWindow: InfoWindow(
            title: name,
            snippet: occupancy <= 5
                ? '🟢 Quiet ($occupancy people)'
                : occupancy <= 15
                    ? '🟡 Moderate ($occupancy people)'
                    : '🔴 Crowded ($occupancy people)',
          ),
        ));
      }

      setState(() {
        _studyZones = zones;
        _circles
          ..clear()
          ..addAll(newCircles);
      });
    } catch (e) {
      debugPrint('MeetupShareView: Study heatmap error — $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PICK A PEER TO SHARE WITH
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _showPeerPicker() async {
    try {
      // Fetch mutual match connections
      final snap = await FirebaseFirestore.instance
          .collection('match_connections')
          .where('participants', arrayContains: widget.studentUid)
          .get();

      if (!mounted) return;

      if (snap.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No connections found. Connect with peers in Find Your Match!'),
            backgroundColor: _neonBlue,
          ),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        backgroundColor: _cardColor,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Share Location With',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
            ...snap.docs.map((doc) {
              final data = doc.data();
              final participants =
                  List<String>.from(data['participants'] ?? []);
              final peerUid = participants
                  .firstWhere((p) => p != widget.studentUid, orElse: () => '');
              if (peerUid.isEmpty) return const SizedBox.shrink();

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(peerUid)
                    .get(),
                builder: (_, peerSnap) {
                  if (!peerSnap.hasData) return const SizedBox.shrink();
                  final peerData =
                      peerSnap.data!.data() as Map<String, dynamic>?;
                  final peerName =
                      peerData?['name'] as String? ?? 'Peer';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _neonCyan.withOpacity(0.15),
                      child:
                          const Icon(Icons.person, color: _neonCyan, size: 18),
                    ),
                    title: Text(peerName,
                        style: const TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.share_location,
                        color: _neonCyan, size: 18),
                    onTap: () {
                      Navigator.pop(context);
                      _startMeetupShare(peerUid);
                    },
                  );
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      );
    } catch (e) {
      debugPrint('MeetupShareView: Peer picker error — $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Social Map',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── TABS ─────────────────────────────────────────────────────────
          _buildTabBar(),

          // ── MAP ───────────────────────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _myPosition != null
                        ? LatLng(_myPosition!.latitude, _myPosition!.longitude)
                        : _campusCenter,
                    zoom: 15,
                  ),
                  onMapCreated: (ctrl) {
                    _mapController = ctrl;
                    _mapController?.setMapStyle(_darkMapStyle);
                    if (_myPosition != null && !_isCameraInitialized) {
                      _mapController!.animateCamera(
                        CameraUpdate.newCameraPosition(CameraPosition(
                          target: LatLng(_myPosition!.latitude, _myPosition!.longitude),
                          zoom: 15,
                        )),
                      );
                      _isCameraInitialized = true;
                    }
                    if (_activeTab == _SocialMapTab.heatmap) {
                      _loadStudyHeatmap();
                    } else {
                      _rebuildMeetupLayer();
                    }
                  },
                  markers: _markers,
                  circles: _circles,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),

                // My location button
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'social_locate',
                    backgroundColor: _cardColor,
                    onPressed: () {
                      if (_myPosition != null) {
                        _mapController?.animateCamera(
                          CameraUpdate.newLatLngZoom(
                            LatLng(_myPosition!.latitude, _myPosition!.longitude),
                            16,
                          ),
                        );
                      }
                    },
                    child: const Icon(Icons.my_location, color: _neonCyan),
                  ),
                ),

                // Active share countdown badge
                if (_activeMeetupShareId != null)
                  Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: _neonGreen.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: _neonGreen.withOpacity(0.4),
                              blurRadius: 16,
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.share_location,
                                color: Colors.black, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              '📡 Live Share: ${_formatCountdown(_meetupSecondsLeft)}',
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _stopMeetupShare,
                              child: const Icon(Icons.stop_circle,
                                  color: Colors.black, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── BOTTOM PANEL ──────────────────────────────────────────────────
          _buildBottomPanel(),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: _cardColor,
      child: Row(
        children: [
          _tabButton(_SocialMapTab.meetup, '🤝 Meet Up'),
          _tabButton(_SocialMapTab.heatmap, '🔥 Study Spots'),
        ],
      ),
    );
  }

  Widget _tabButton(_SocialMapTab tab, String label) {
    final isActive = _activeTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeTab = tab;
            _markers.clear();
            _circles.clear();
          });
          if (tab == _SocialMapTab.heatmap) {
            _loadStudyHeatmap();
          } else {
            _rebuildMeetupLayer();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? _neonCyan : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? _neonCyan : _textSecondary,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    if (_activeTab == _SocialMapTab.meetup) {
      return _meetupPanel();
    } else {
      return _heatmapPanel();
    }
  }

  Widget _meetupPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: _cardColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Proximity alerts toggle
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2235),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_alt_outlined,
                    color: _neonBlue, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Proximity Alerts',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      const Text(
                        'Notify when a study buddy is within 100m',
                        style: TextStyle(color: _textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _proximityAlertsEnabled,
                  onChanged: _toggleProximityAlerts,
                  activeColor: _neonCyan,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Share button
          SizedBox(
            width: double.infinity,
            child: _activeMeetupShareId == null
                ? ElevatedButton.icon(
                    onPressed: _showPeerPicker,
                    icon: const Icon(Icons.share_location),
                    label: const Text('Share Live Location (30 min)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: _stopMeetupShare,
                    icon: const Icon(Icons.stop_circle,
                        color: _neonPink),
                    label: const Text('Stop Sharing',
                        style: TextStyle(color: _neonPink)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _neonPink),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _heatmapPanel() {
    // Legend
    return Container(
      padding: const EdgeInsets.all(16),
      color: _cardColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Study Zone Legend',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            children: [
              _legendDot(_neonGreen, 'Quiet (≤5)'),
              const SizedBox(width: 16),
              _legendDot(const Color(0xFFEAB308), 'Moderate (6–15)'),
              const SizedBox(width: 16),
              _legendDot(const Color(0xFFEF4444), 'Crowded (>15)'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_studyZones.length} study zones loaded • Data refreshes every 5 min',
            style: const TextStyle(color: _textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: _textSecondary, fontSize: 11)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DARK MAP STYLE
// ─────────────────────────────────────────────────────────────────────────────
const String _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1d2c4d"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8ec3b9"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1a3646"}]},
  {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#023e58"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#283d6a"}]},
  {"featureType":"poi.park","elementType":"geometry.fill","stylers":[{"color":"#023e58"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#304a7d"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2c6675"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0e1626"}]}
]
''';
