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
const _neonOrange = Color(0xFFFF6F00);
const _neonRed = Color(0xFFF92B60);
const _neonGreen = Color(0xFF22C55E);
const _textSecondary = Color(0xFF8B9BB4);

// Campus centre (University of Nairobi — replace with real coords)
const LatLng _campusCenter = LatLng(-1.2793, 36.8166);
const double _campusRadius = 600.0;

// ─────────────────────────────────────────────────────────────────────────────
// STATIC CAMPUS DATA
// ─────────────────────────────────────────────────────────────────────────────

/// Campus buildings — replace lat/lng with actual campus building coords
final List<_CampusBuilding> _campusBuildings = [
  _CampusBuilding('Main Library', LatLng(-1.2793, 36.8166),
      Icons.library_books, _neonCyan, 'Central campus library'),
  _CampusBuilding('Lecture Hall A', LatLng(-1.2800, 36.8170),
      Icons.school, _neonBlue, 'Main lecture hall block'),
  _CampusBuilding('Science Lab', LatLng(-1.2785, 36.8155),
      Icons.science, _neonOrange, 'Chemistry & Physics labs'),
  _CampusBuilding('Student Centre', LatLng(-1.2810, 36.8160),
      Icons.people, MPesaTheme.primaryGreen, 'Student union & lounge'),
  _CampusBuilding('Admin Block', LatLng(-1.2770, 36.8175),
      Icons.business, _neonBlue, 'Administration offices'),
  _CampusBuilding('Engineering Block', LatLng(-1.2795, 36.8180),
      Icons.engineering, _neonOrange, 'Engineering faculty'),
];

/// Emergency assets — replace with real coordinates
final List<_EmergencyAsset> _emergencyAssets = [
  _EmergencyAsset('Security Booth A', LatLng(-1.2790, 36.8162),
      Icons.security, Colors.deepOrange, 'security'),
  _EmergencyAsset('First Aid Station', LatLng(-1.2800, 36.8155),
      Icons.medical_services, Colors.red, 'medical'),
  _EmergencyAsset('Blue Light Phone', LatLng(-1.2788, 36.8178),
      Icons.phone_in_talk, _neonBlue, 'phone'),
  _EmergencyAsset('Security Booth B', LatLng(-1.2815, 36.8170),
      Icons.security, Colors.deepOrange, 'security'),
];

/// Night-time safe walk corridors (pairs of LatLng points)
final List<List<LatLng>> _safeWalkCorridors = [
  [LatLng(-1.2793, 36.8166), LatLng(-1.2800, 36.8170), LatLng(-1.2810, 36.8160)],
  [LatLng(-1.2793, 36.8166), LatLng(-1.2785, 36.8155), LatLng(-1.2790, 36.8145)],
];

class _CampusBuilding {
  final String name;
  final LatLng position;
  final IconData icon;
  final Color color;
  final String description;
  _CampusBuilding(this.name, this.position, this.icon, this.color, this.description);
}

class _EmergencyAsset {
  final String name;
  final LatLng position;
  final IconData icon;
  final Color color;
  final String type;
  _EmergencyAsset(this.name, this.position, this.icon, this.color, this.type);
}

// ─────────────────────────────────────────────────────────────────────────────
// VIEW
// ─────────────────────────────────────────────────────────────────────────────

enum _MapFilter { all, buildings, emergency, safewalk, events }

/// Full-featured campus navigation map for students.
///
/// Features:
///  • Campus Building Navigator with search
///  • Night-Time Safe Walk Corridor overlays
///  • Danger Zone polygon warnings
///  • Emergency Asset Mapping (security, first-aid, blue-light)
///  • Automated Event Check-In via geofencing
class CampusMapView extends StatefulWidget {
  final String studentUid;

  const CampusMapView({super.key, required this.studentUid});

  @override
  State<CampusMapView> createState() => _CampusMapViewState();
}

class _CampusMapViewState extends State<CampusMapView> {
  GoogleMapController? _mapController;
  Position? _myPosition;
  StreamSubscription<Position>? _positionSub;
  _MapFilter _activeFilter = _MapFilter.all;
  bool _isCameraInitialized = false;

  // Map objects
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Set<Polygon> _polygons = {};
  final Set<Circle> _circles = {};

  // Search
  final TextEditingController _searchController = TextEditingController();
  List<_CampusBuilding> _searchResults = [];
  bool _searchActive = false;

  // Events
  List<Map<String, dynamic>> _campusEvents = [];

  // Night mode
  bool get _isNightTime {
    final hour = DateTime.now().hour;
    return hour >= 18 || hour < 6;
  }

  // Danger zone warning
  bool _showDangerWarning = false;
  String _dangerZoneName = '';

  @override
  void initState() {
    super.initState();
    _startLocationWatch();
    _loadCampusEvents();
    _loadDangerZones();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOCATION STREAM
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _startLocationWatch() async {
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

    _positionSub = LocationService.getLocationStream(distanceFilter: 5)
        .listen((pos) async {
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

      // Check danger zones
      final inDanger = await GeofenceService.checkDangerZones(pos);
      if (inDanger && mounted) {
        setState(() {
          _showDangerWarning = true;
        });
      }

      // Check proximity reminders
      await GeofenceService.checkProximityReminders(widget.studentUid, pos);

      // Auto event check-in
      await _checkEventCheckIn(pos);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CAMPUS EVENTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadCampusEvents() async {
    try {
      final now = Timestamp.now();
      final snap = await FirebaseFirestore.instance
          .collection('campus_events')
          .where('endTime', isGreaterThan: now)
          .get();
      setState(() {
        _campusEvents = snap.docs.map((d) {
          final data = d.data();
          return {...data, 'id': d.id};
        }).toList();
      });
    } catch (e) {
      debugPrint('CampusMapView: Error loading events — $e');
    }
    _rebuildMap();
  }

  Future<void> _checkEventCheckIn(Position pos) async {
    for (final event in _campusEvents) {
      final eventLat = (event['lat'] as num?)?.toDouble();
      final eventLng = (event['lng'] as num?)?.toDouble();
      final radiusM = (event['radiusMeters'] as num?)?.toDouble() ?? 50.0;
      final eventId = event['id'] as String;
      final eventName = event['name'] as String? ?? 'Event';
      if (eventLat == null || eventLng == null) continue;

      if (GeofenceService.isInsideCircle(
          pos.latitude, pos.longitude, eventLat, eventLng, radiusM)) {
        // Auto check in
        try {
          await FirebaseFirestore.instance
              .collection('campus_events')
              .doc(eventId)
              .collection('checkins')
              .doc(widget.studentUid)
              .set({
            'uid': widget.studentUid,
            'checkedInAt': FieldValue.serverTimestamp(),
            'auto': true,
          }, SetOptions(merge: true));

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              backgroundColor: MPesaTheme.primaryGreen,
              content: Text('✅ Auto checked in to "$eventName"!',
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
              duration: const Duration(seconds: 4),
            ));
          }
        } catch (_) {}
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DANGER ZONES
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadDangerZones() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('danger_zones')
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final name = data['name'] as String? ?? 'Restricted';
        final vertices = (data['polygon'] as List<dynamic>? ?? [])
            .map((v) => LatLng(
                  (v['lat'] as num).toDouble(),
                  (v['lng'] as num).toDouble(),
                ))
            .toList();
        if (vertices.length < 3) continue;
        _polygons.add(Polygon(
          polygonId: PolygonId(doc.id),
          points: vertices,
          fillColor: _neonRed.withOpacity(0.15),
          strokeColor: _neonRed,
          strokeWidth: 2,
        ));
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('CampusMapView: Error loading danger zones — $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MAP OBJECT BUILDER
  // ─────────────────────────────────────────────────────────────────────────

  void _rebuildMap() {
    final newMarkers = <Marker>{};
    final newPolylines = <Polyline>{};
    final newCircles = <Circle>{};

    final showBuildings =
        _activeFilter == _MapFilter.all || _activeFilter == _MapFilter.buildings;
    final showEmergency =
        _activeFilter == _MapFilter.all || _activeFilter == _MapFilter.emergency;
    final showSafeWalk =
        _activeFilter == _MapFilter.all || _activeFilter == _MapFilter.safewalk;
    final showEvents =
        _activeFilter == _MapFilter.all || _activeFilter == _MapFilter.events;

    // Buildings
    if (showBuildings) {
      for (final b in _campusBuildings) {
        newMarkers.add(Marker(
          markerId: MarkerId('bldg_${b.name}'),
          position: b.position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(
            title: '🏛️ ${b.name}',
            snippet: b.description,
          ),
          onTap: () => _showBuildingSheet(b),
        ));
      }
    }

    // Emergency assets
    if (showEmergency) {
      for (final a in _emergencyAssets) {
        newMarkers.add(Marker(
          markerId: MarkerId('asset_${a.name}'),
          position: a.position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            a.type == 'medical'
                ? BitmapDescriptor.hueRed
                : a.type == 'phone'
                    ? BitmapDescriptor.hueBlue
                    : BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(title: '🚨 ${a.name}'),
        ));
      }
    }

    // Safe walk corridors (only at night or always in safe-walk filter)
    if (showSafeWalk && (_isNightTime || _activeFilter == _MapFilter.safewalk)) {
      for (int i = 0; i < _safeWalkCorridors.length; i++) {
        newPolylines.add(Polyline(
          polylineId: PolylineId('safewalk_$i'),
          points: _safeWalkCorridors[i],
          color: _neonGreen,
          width: 5,
          patterns: [PatternItem.dash(20), PatternItem.gap(8)],
        ));
      }
    }

    // Campus boundary circle
    newCircles.add(Circle(
      circleId: const CircleId('campus_boundary'),
      center: _myPosition != null 
          ? LatLng(_myPosition!.latitude, _myPosition!.longitude) 
          : _campusCenter,
      radius: _campusRadius,
      fillColor: _neonCyan.withOpacity(0.04),
      strokeColor: _neonCyan.withOpacity(0.3),
      strokeWidth: 1,
    ));

    // Events
    if (showEvents) {
      for (final event in _campusEvents) {
        final lat = (event['lat'] as num?)?.toDouble();
        final lng = (event['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final name = event['name'] as String? ?? 'Event';
        newMarkers.add(Marker(
          markerId: MarkerId('event_${event['id']}'),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueViolet),
          infoWindow: InfoWindow(title: '🎉 $name'),
        ));
        newCircles.add(Circle(
          circleId: CircleId('event_zone_${event['id']}'),
          center: LatLng(lat, lng),
          radius: (event['radiusMeters'] as num?)?.toDouble() ?? 50,
          fillColor: Colors.purple.withOpacity(0.12),
          strokeColor: Colors.purple,
          strokeWidth: 1,
        ));
      }
    }

    // My position marker
    if (_myPosition != null) {
      newMarkers.add(Marker(
        markerId: const MarkerId('me'),
        position: LatLng(_myPosition!.latitude, _myPosition!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: '📍 You are here'),
      ));
    }

    setState(() {
      _markers
        ..clear()
        ..addAll(newMarkers);
      _polylines
        ..clear()
        ..addAll(newPolylines);
      _circles
        ..clear()
        ..addAll(newCircles);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SEARCH
  // ─────────────────────────────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchActive = false;
      });
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _searchActive = true;
      _searchResults = _campusBuildings
          .where((b) =>
              b.name.toLowerCase().contains(q) ||
              b.description.toLowerCase().contains(q))
          .toList();
    });
  }

  void _navigateToBuilding(_CampusBuilding b) {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _searchActive = false;
    });
    _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(b.position, 18));
    _showBuildingSheet(b);
  }

  void _showBuildingSheet(_CampusBuilding b) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: b.color.withOpacity(0.15),
                  child: Icon(b.icon, color: b.color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      Text(b.description,
                          style: const TextStyle(color: _textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_myPosition != null) ...[
              Text(
                'Distance: ${LocationService.distanceMeters(_myPosition!.latitude, _myPosition!.longitude, b.position.latitude, b.position.longitude).round()}m',
                style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _drawWalkingRoute(b.position);
                },
                icon: const Icon(Icons.directions_walk),
                label: const Text('Show Walking Route'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _neonCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _drawWalkingRoute(LatLng destination) {
    if (_myPosition == null) return;
    final origin =
        LatLng(_myPosition!.latitude, _myPosition!.longitude);
    setState(() {
      _polylines
        ..removeWhere((p) => p.polylineId.value == 'walking_route')
        ..add(Polyline(
          polylineId: const PolylineId('walking_route'),
          points: [origin, destination], // straight line; swap for Directions API
          color: MPesaTheme.primaryGreen,
          width: 4,
          patterns: [PatternItem.dot, PatternItem.gap(10)],
        ));
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            origin.latitude < destination.latitude
                ? origin.latitude
                : destination.latitude,
            origin.longitude < destination.longitude
                ? origin.longitude
                : destination.longitude,
          ),
          northeast: LatLng(
            origin.latitude > destination.latitude
                ? origin.latitude
                : destination.latitude,
            origin.longitude > destination.longitude
                ? origin.longitude
                : destination.longitude,
          ),
        ),
        80,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Rebuild map when filter changes
    _rebuildMap();

    return Scaffold(
      backgroundColor: _bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search buildings, labs, library...',
            hintStyle: TextStyle(color: _textSecondary),
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search, color: _textSecondary),
          ),
        ),
        backgroundColor: _bgColor.withOpacity(0.92),
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // ── GOOGLE MAP ────────────────────────────────────────────────────
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
            },
            markers: _markers,
            polylines: _polylines,
            polygons: _polygons,
            circles: _circles,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // ── SEARCH RESULTS OVERLAY ────────────────────────────────────────
          if (_searchActive && _searchResults.isNotEmpty)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Material(
                color: _cardColor,
                borderRadius: BorderRadius.circular(16),
                elevation: 8,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (_, i) {
                    final b = _searchResults[i];
                    return ListTile(
                      leading:
                          CircleAvatar(
                            backgroundColor: b.color.withOpacity(0.15),
                            child: Icon(b.icon, color: b.color, size: 18)),
                      title: Text(b.name,
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(b.description,
                          style: const TextStyle(
                              color: _textSecondary, fontSize: 11)),
                      onTap: () => _navigateToBuilding(b),
                    );
                  },
                ),
              ),
            ),

          // ── FILTER PILLS ─────────────────────────────────────────────────
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _filterPill(_MapFilter.all, '🗺️ All'),
                  _filterPill(_MapFilter.buildings, '🏛️ Buildings'),
                  _filterPill(_MapFilter.emergency, '🚨 Emergency'),
                  _filterPill(_MapFilter.safewalk, '🌙 Safe Walk'),
                  _filterPill(_MapFilter.events, '🎉 Events'),
                ],
              ),
            ),
          ),

          // ── MY LOCATION BUTTON ────────────────────────────────────────────
          Positioned(
            bottom: 160,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'campus_locate',
              backgroundColor: _cardColor,
              onPressed: () {
                if (_myPosition != null) {
                  _mapController?.animateCamera(
                    CameraUpdate.newCameraPosition(CameraPosition(
                      target: LatLng(
                          _myPosition!.latitude, _myPosition!.longitude),
                      zoom: 17,
                    )),
                  );
                }
              },
              child: const Icon(Icons.my_location, color: _neonCyan),
            ),
          ),

          // ── NIGHT SAFE WALK BANNER ────────────────────────────────────────
          if (_isNightTime || _activeFilter == _MapFilter.safewalk)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _neonGreen.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_moon, color: Colors.black, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '🌙 Night Mode: Safe-walk corridors active. Follow green paths.',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── DANGER ZONE WARNING ────────────────────────────────────────────
          if (_showDangerWarning)
            Positioned(
              top: _isNightTime ? 154 : 100,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => setState(() => _showDangerWarning = false),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _neonRed.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          '⚠️ You are near a restricted area. Please proceed with caution.',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ),
                      const Icon(Icons.close, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterPill(_MapFilter filter, String label) {
    final isActive = _activeFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? _neonCyan : _cardColor,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
              color: isActive ? _neonCyan : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
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
