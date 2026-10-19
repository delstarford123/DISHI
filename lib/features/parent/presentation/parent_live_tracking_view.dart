import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/map_marker_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────
const _bgColor = Color(0xFF0C101B);
const _cardColor = Color(0xFF131A2A);
const _surfaceLight = Color(0xFF1A2235);
const _neonCyan = Color(0xFF05D5AA);
const _neonBlue = Color(0xFF3B82F6);
const _neonOrange = Color(0xFFFF6F00);
const _neonRed = Color(0xFFF92B60);
const _textSecondary = Color(0xFF8B9BB4);

/// Full-featured parent live tracking screen powered by google_maps_flutter.
///
/// Features:
///  • Real-time custom student avatar marker with profile image, battery & speed
///  • Parent Home / Safe Zone marker with geofence boundary circle
///  • Pulsing GPS accuracy radius halo
///  • Map Type Switcher (Cyber Dark, Satellite, Standard)
///  • 24-hour location breadcrumb polyline
///  • Live speed with vehicle-alert banner
///  • Dynamic ETA to parent's "Home" zone
///  • Offline "Last Known Location" with timestamp
///  • "Pick Me Up" Google Maps turn-by-turn navigation, direct call & SMS
class ParentLiveTrackingView extends StatefulWidget {
  final String studentUid;
  final String studentName;
  final Map<String, dynamic>? homeZone; // {lat, lng} of parent's home geofence

  const ParentLiveTrackingView({
    super.key,
    required this.studentUid,
    required this.studentName,
    this.homeZone,
  });

  @override
  State<ParentLiveTrackingView> createState() => _ParentLiveTrackingViewState();
}

class _ParentLiveTrackingViewState extends State<ParentLiveTrackingView>
    with SingleTickerProviderStateMixin {
  // Map controller
  GoogleMapController? _mapController;
  MapType _currentMapType = MapType.normal;
  bool _isDarkStyleActive = true;

  // Current student state
  LatLng? _studentPosition;
  double _speedKmh = 0;
  int _batteryLevel = -1;
  bool _isTracking = false;
  DateTime? _lastSeen;
  bool _signalLost = false;
  bool _vehicleAlertShown = false;
  bool _sosActive = false;
  String? _studentProfileUrl;
  String? _studentPhone;

  // Breadcrumbs
  List<LatLng> _breadcrumbs = [];

  // Map objects
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Set<Circle> _circles = {};

  // Firestore stream
  StreamSubscription<DocumentSnapshot>? _locationSub;
  StreamSubscription<QuerySnapshot>? _breadcrumbSub;

  // Animation for signal-lost & pulse
  late AnimationController _pulseController;

  LatLng _parentLocation = const LatLng(-1.2840, 36.8172);
  bool _parentLocationLoaded = false;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _fetchParentLocation();
    _subscribeToLocation();
    _subscribeToSignalTimeout();
  }

  Future<void> _fetchParentLocation() async {
    if (widget.homeZone != null) {
      if (mounted) {
        setState(() {
          _parentLocation = LatLng(
            (widget.homeZone!['lat'] as num).toDouble(),
            (widget.homeZone!['lng'] as num).toDouble(),
          );
          _parentLocationLoaded = true;
        });
        _updateHomeMarker();
      }
    } else {
      final err = await LocationService.ensurePermissions();
      if (err == null) {
        try {
          final pos = await LocationService.getCurrentLocation();
          if (mounted) {
            setState(() {
              _parentLocation = LatLng(pos.latitude, pos.longitude);
              _parentLocationLoaded = true;
            });
            _updateHomeMarker();
            if (_mapController != null && _studentPosition == null && !_isCameraInitialized) {
              _mapController!.animateCamera(CameraUpdate.newLatLngZoom(_parentLocation, 16));
              _isCameraInitialized = true;
            }
          }
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _breadcrumbSub?.cancel();
    _signalTimer?.cancel();
    _pulseController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FIRESTORE SUBSCRIPTIONS
  // ─────────────────────────────────────────────────────────────────────────

  void _subscribeToLocation() {
    _locationSub = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.studentUid)
        .snapshots()
        .listen(_onLocationUpdate, onError: (_) => _onSignalLost());

    // Breadcrumbs sub-collection
    final cutoff = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 24)));
    _breadcrumbSub = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.studentUid)
        .collection('locationBreadcrumbs')
        .where('timestamp', isGreaterThan: cutoff)
        .orderBy('timestamp')
        .snapshots()
        .listen(_onBreadcrumbUpdate);
  }

  Future<void> _onLocationUpdate(DocumentSnapshot snap) async {
    if (!snap.exists) return;
    final data = snap.data() as Map<String, dynamic>;
    
    final locData = data['location'] as Map<String, dynamic>?;
    if (locData == null) return;

    final lat = (locData['lat'] as num?)?.toDouble();
    final lng = (locData['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;

    final newPos = LatLng(lat, lng);
    final speed = (locData['speed'] as num?)?.toDouble() ?? 0.0;
    final battery = (locData['batteryLevel'] as num?)?.toInt() ?? -1;
    final isTracking = locData['isTracking'] as bool? ?? false;
    final ts = locData['timestamp'] as Timestamp?;
    final sosActive = data['sosActive'] as bool? ?? false;
    final profileUrl = (data['profileImageUrl'] ?? data['photoUrl']) as String?;
    final phone = (data['phoneNumber'] ?? data['phone']) as String?;

    if (mounted) {
      setState(() {
        _studentPosition = newPos;
        _speedKmh = speed;
        _batteryLevel = battery;
        _isTracking = isTracking;
        _lastSeen = ts?.toDate() ?? DateTime.now();
        _signalLost = false;
        _sosActive = sosActive;
        _studentProfileUrl = profileUrl;
        _studentPhone = phone;
      });
    }

    await _updateStudentMarker(newPos, battery, speed, isTracking, sosActive, profileUrl);
    _updateAccuracyAndGeofenceCircles(newPos);

    // Initial camera movement or follow
    if (_mapController != null && !_isCameraInitialized) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(newPos, 16.5));
      _isCameraInitialized = true;
    }

    // Vehicle alert (>25 km/h)
    if (speed > 25 && !_vehicleAlertShown) {
      _vehicleAlertShown = true;
      _showVehicleAlert();
    } else if (speed < 25) {
      _vehicleAlertShown = false;
    }
  }

  void _onBreadcrumbUpdate(QuerySnapshot snap) {
    final crumbs = snap.docs.map((doc) {
      final d = doc.data() as Map<String, dynamic>;
      return LatLng(
        (d['lat'] as num).toDouble(),
        (d['lng'] as num).toDouble(),
      );
    }).toList();

    setState(() {
      _breadcrumbs = crumbs;
      _polylines
        ..clear()
        ..add(Polyline(
          polylineId: const PolylineId('breadcrumbs'),
          points: crumbs,
          color: _neonCyan.withValues(alpha: 0.8),
          width: 4,
          patterns: [PatternItem.dash(14), PatternItem.gap(6)],
        ));
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SIGNAL TIMEOUT
  // ─────────────────────────────────────────────────────────────────────────

  Timer? _signalTimer;

  void _subscribeToSignalTimeout() {
    _signalTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_lastSeen != null &&
          DateTime.now().difference(_lastSeen!).inMinutes >= 2) {
        _onSignalLost();
      }
    });
  }

  void _onSignalLost() {
    if (!mounted) return;
    setState(() => _signalLost = true);
    if (_studentPosition != null) {
      _updateStudentMarker(
        _studentPosition!,
        _batteryLevel,
        _speedKmh,
        false,
        _sosActive,
        _studentProfileUrl,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CUSTOM MARKERS & CIRCLES
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _updateStudentMarker(
    LatLng pos,
    int battery,
    double speed,
    bool isTracking,
    bool isSOS,
    String? profileUrl,
  ) async {
    final avatarMarkerIcon = await MapMarkerHelper.createStudentAvatarMarker(
      name: widget.studentName,
      profileImageUrl: profileUrl,
      borderColor: isSOS ? _neonRed : (speed > 25 ? _neonOrange : _neonCyan),
      batteryLevel: battery >= 0 ? battery : null,
      isSOS: isSOS,
      speedKmh: speed,
      isOnline: !_signalLost && isTracking,
    );

    final speedText = speed < 0.5 ? 'Stationary' : '${speed.toStringAsFixed(1)} km/h';
    final lastSeenText = _lastSeen != null ? _formatTime(_lastSeen!) : 'Just now';

    if (mounted) {
      setState(() {
        _markers
          ..removeWhere((m) => m.markerId.value == 'student')
          ..add(Marker(
            markerId: const MarkerId('student'),
            position: pos,
            icon: avatarMarkerIcon,
            zIndex: 10,
            infoWindow: InfoWindow(
              title: isSOS ? '🚨 ${widget.studentName} (SOS ACTIVE!)' : '📍 ${widget.studentName}',
              snippet: '$speedText • $lastSeenText • Battery: ${battery >= 0 ? '$battery%' : 'N/A'}',
            ),
          ));
      });
    }
  }

  Future<void> _updateHomeMarker() async {
    final homeIcon = await MapMarkerHelper.createParentHomeMarker(
      label: widget.homeZone != null ? 'Safe Zone' : 'Home Base',
    );

    if (mounted) {
      setState(() {
        _markers
          ..removeWhere((m) => m.markerId.value == 'home')
          ..add(Marker(
            markerId: const MarkerId('home'),
            position: _parentLocation,
            icon: homeIcon,
            zIndex: 5,
            infoWindow: InfoWindow(
              title: widget.homeZone != null ? '🏡 Safe Home Zone' : '📍 Parent Position',
              snippet: 'Designated Family Base',
            ),
          ));
      });
    }
  }

  void _updateAccuracyAndGeofenceCircles(LatLng studentPos) {
    setState(() {
      _circles.clear();

      // 1. Pulsing live accuracy circle around student
      _circles.add(Circle(
        circleId: const CircleId('student_accuracy_halo'),
        center: studentPos,
        radius: 35.0,
        fillColor: (_sosActive ? _neonRed : _neonCyan).withValues(alpha: 0.16),
        strokeColor: (_sosActive ? _neonRed : _neonCyan).withValues(alpha: 0.7),
        strokeWidth: 2,
      ));

      // 2. Geofence Safe Zone circle around home if defined
      if (widget.homeZone != null) {
        final radius = (widget.homeZone!['radius'] as num?)?.toDouble() ?? 250.0;
        _circles.add(Circle(
          circleId: const CircleId('home_geofence_zone'),
          center: _parentLocation,
          radius: radius,
          fillColor: _neonBlue.withValues(alpha: 0.12),
          strokeColor: _neonBlue.withValues(alpha: 0.6),
          strokeWidth: 2,
        ));
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CAMERA CONTROLS
  // ─────────────────────────────────────────────────────────────────────────

  void _centerOnStudent() {
    if (_studentPosition != null && _mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: _studentPosition!,
        zoom: 17.5,
        tilt: 30,
      )));
    }
  }

  void _centerOnHome() {
    if (_mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: _parentLocation,
        zoom: 16.5,
      )));
    }
  }

  void _fitBothInView() {
    if (_studentPosition == null || _mapController == null) return;

    final southwest = LatLng(
      _studentPosition!.latitude < _parentLocation.latitude ? _studentPosition!.latitude : _parentLocation.latitude,
      _studentPosition!.longitude < _parentLocation.longitude ? _studentPosition!.longitude : _parentLocation.longitude,
    );
    final northeast = LatLng(
      _studentPosition!.latitude > _parentLocation.latitude ? _studentPosition!.latitude : _parentLocation.latitude,
      _studentPosition!.longitude > _parentLocation.longitude ? _studentPosition!.longitude : _parentLocation.longitude,
    );

    final bounds = LatLngBounds(southwest: southwest, northeast: northeast);
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 90));
  }

  void _toggleMapType() {
    setState(() {
      if (_currentMapType == MapType.normal) {
        _currentMapType = MapType.satellite;
        _isDarkStyleActive = false;
        _mapController?.setMapStyle(null);
      } else {
        _currentMapType = MapType.normal;
        _isDarkStyleActive = true;
        _mapController?.setMapStyle(MapMarkerHelper.darkMapStyle);
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTIONS & ROUTING
  // ─────────────────────────────────────────────────────────────────────────

  void _showVehicleAlert() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _neonOrange,
        content: Row(
          children: [
            const Icon(Icons.directions_car, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '⚠️ ${widget.studentName} is moving in a vehicle (${_speedKmh.toStringAsFixed(0)} km/h)',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _launchPickMeUpRouting() async {
    if (_studentPosition == null) return;
    final lat = _studentPosition!.latitude;
    final lng = _studentPosition!.longitude;
    final name = Uri.encodeComponent(widget.studentName);

    final Uri geoUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final Uri fallbackUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$name&travelmode=driving');

    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri);
      } else {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _callStudent() async {
    if (_studentPhone != null && _studentPhone!.isNotEmpty) {
      final uri = Uri.parse('tel:$_studentPhone');
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student phone number not found')),
      );
    }
  }

  Future<void> _smsStudent() async {
    if (_studentPhone != null && _studentPhone!.isNotEmpty) {
      final uri = Uri.parse('sms:$_studentPhone');
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student phone number not found')),
      );
    }
  }

  String _getEtaText() {
    if (_studentPosition == null || widget.homeZone == null) return '—';
    final homeLat = (widget.homeZone!['lat'] as num?)?.toDouble();
    final homeLng = (widget.homeZone!['lng'] as num?)?.toDouble();
    if (homeLat == null || homeLng == null) return '—';

    final distM = LocationService.distanceMeters(
      _studentPosition!.latitude,
      _studentPosition!.longitude,
      homeLat,
      homeLng,
    );
    return LocationService.etaString(distM, _speedKmh);
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: _neonCyan.withValues(alpha: 0.2),
              backgroundImage: _studentProfileUrl != null ? NetworkImage(_studentProfileUrl!) : null,
              child: _studentProfileUrl == null
                  ? Text(
                      widget.studentName.isNotEmpty ? widget.studentName[0].toUpperCase() : 'S',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.studentName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    _sosActive
                        ? '🚨 SOS EMERGENCY TRIGGERED'
                        : (_signalLost
                            ? 'Last seen ${_lastSeen != null ? _formatTime(_lastSeen!) : 'offline'}'
                            : (_isTracking ? 'Live GPS Satellite Tracking' : 'Standby')),
                    style: TextStyle(
                      color: _sosActive ? _neonRed : (_signalLost ? Colors.white60 : _neonCyan),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: _bgColor.withValues(alpha: 0.9),
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          // Map Type Switcher (Cyber Dark vs Satellite)
          IconButton(
            tooltip: 'Switch Map View',
            icon: Icon(
              _currentMapType == MapType.satellite ? Icons.map : Icons.satellite_alt,
              color: _neonCyan,
            ),
            onPressed: _toggleMapType,
          ),
          if (_isTracking && !_signalLost)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, __) => Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (_sosActive ? _neonRed : _neonCyan).withValues(alpha: 0.4 + 0.6 * _pulseController.value),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // ── GOOGLE MAP ──────────────────────────────────────────────────
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: _signalLost
                  ? const ColorFilter.matrix([
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0,      0,      0,      1, 0,
                    ])
                  : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
              child: GoogleMap(
                mapType: _currentMapType,
                initialCameraPosition: CameraPosition(
                  target: _studentPosition ?? _parentLocation,
                  zoom: 16,
                ),
                onMapCreated: (ctrl) {
                  _mapController = ctrl;
                  if (_isDarkStyleActive) {
                    _mapController?.setMapStyle(MapMarkerHelper.darkMapStyle);
                  }
                  if (!_isCameraInitialized) {
                    final target = _studentPosition ?? (_parentLocationLoaded ? _parentLocation : null);
                    if (target != null) {
                      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
                      _isCameraInitialized = true;
                    }
                  }
                },
                markers: _markers,
                polylines: _polylines,
                circles: _circles,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: true,
                mapToolbarEnabled: false,
              ),
            ),
          ),

          // ── SOS ALERT OVERLAY BANNER ─────────────────────────────────────
          if (_sosActive)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _neonRed,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: _neonRed.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🚨 STUDENT TRIGGERED SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Live high-frequency GPS stream active. Tap Call or Pick Me Up immediately.', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── FLOATING CAMERA & MAP CONTROLS ──────────────────────────────
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 70,
            child: Column(
              children: [
                _buildMapActionButton(
                  icon: Icons.person_pin_circle,
                  tooltip: 'Focus on Student',
                  color: _neonCyan,
                  onTap: _centerOnStudent,
                ),
                const SizedBox(height: 10),
                _buildMapActionButton(
                  icon: Icons.home,
                  tooltip: 'Focus on Home',
                  color: _neonBlue,
                  onTap: _centerOnHome,
                ),
                const SizedBox(height: 10),
                _buildMapActionButton(
                  icon: Icons.crop_free,
                  tooltip: 'Fit Both in View',
                  color: Colors.white,
                  onTap: _fitBothInView,
                ),
              ],
            ),
          ),

          // ── SIGNAL LOST BADGE ───────────────────────────────────────────
          if (_signalLost && !_sosActive)
            Positioned(
              top: MediaQuery.of(context).padding.top + 64,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: _surfaceLight.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.signal_cellular_connected_no_internet_0_bar, color: Colors.orangeAccent, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Signal Delayed — Last seen ${_lastSeen != null ? _formatTime(_lastSeen!) : 'recently'}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── BOTTOM TRACKING CONTROL SHEET ───────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 16),

                  // Student identity & battery row
                  Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: _neonCyan.withValues(alpha: 0.2),
                            backgroundImage: _studentProfileUrl != null ? NetworkImage(_studentProfileUrl!) : null,
                            child: _studentProfileUrl == null
                                ? Text(
                                    widget.studentName.isNotEmpty ? widget.studentName[0].toUpperCase() : 'S',
                                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: _signalLost ? Colors.grey : (_sosActive ? _neonRed : const Color(0xFF22C55E)),
                                shape: BoxShape.circle,
                                border: Border.all(color: _cardColor, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.studentName,
                              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _sosActive
                                  ? '🔴 SOS Triggered — Immediate response needed'
                                  : (_signalLost
                                      ? 'Offline — Displaying last known coordinate'
                                      : (_speedKmh > 25 ? '🚗 In Vehicle (${_speedKmh.toStringAsFixed(0)} km/h)' : '🟢 Active & Broadcasting')),
                              style: TextStyle(
                                color: _sosActive ? _neonRed : (_signalLost ? Colors.white60 : (_speedKmh > 25 ? _neonOrange : _neonCyan)),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Battery Badge
                      if (_batteryLevel >= 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _batteryLevel <= 20 ? _neonRed.withValues(alpha: 0.15) : _neonCyan.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _batteryLevel <= 20 ? _neonRed : _neonCyan),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _batteryLevel <= 20 ? Icons.battery_alert : Icons.battery_charging_full,
                                color: _batteryLevel <= 20 ? _neonRed : _neonCyan,
                                size: 15,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$_batteryLevel%',
                                style: TextStyle(
                                  color: _batteryLevel <= 20 ? _neonRed : _neonCyan,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 14),

                  // Stats Row
                  Row(
                    children: [
                      _statChip(
                        icon: Icons.speed,
                        label: 'Speed',
                        value: _speedKmh < 0.8 ? 'Walking' : '${_speedKmh.toStringAsFixed(1)} km/h',
                        color: _speedKmh > 25 ? _neonOrange : _neonCyan,
                      ),
                      const SizedBox(width: 8),
                      _statChip(
                        icon: Icons.home_work,
                        label: 'ETA Home',
                        value: _getEtaText(),
                        color: _neonBlue,
                      ),
                      const SizedBox(width: 8),
                      _statChip(
                        icon: Icons.route,
                        label: 'Breadcrumbs',
                        value: '${_breadcrumbs.length} pts',
                        color: Colors.purpleAccent,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Primary Action Buttons Row
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _neonCyan,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.directions, size: 20),
                          label: const Text('Pick Me Up (Nav)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: _launchPickMeUpRouting,
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(14),
                        ),
                        icon: const Icon(Icons.phone, size: 20),
                        tooltip: 'Call Student',
                        onPressed: _callStudent,
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(14),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline, size: 20),
                        tooltip: 'Message Student',
                        onPressed: _smsStudent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapActionButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131A2A).withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 22),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }

  Widget _statChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 3),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            Text(label, style: const TextStyle(color: _textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
