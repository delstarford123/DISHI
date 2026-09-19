import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/services/location_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────
const _bgColor = Color(0xFF0C101B);
const _cardColor = Color(0xFF131A2A);
const _neonCyan = Color(0xFF05D5AA);
const _neonBlue = Color(0xFF3B82F6);
const _neonOrange = Color(0xFFFF6F00);
const _neonRed = Color(0xFFF92B60);
const _textSecondary = Color(0xFF8B9BB4);

/// Full-featured parent live tracking screen powered by google_maps_flutter.
///
/// Features:
///  • Real-time student marker from Firestore stream
///  • 24-hour location breadcrumb polyline
///  • Battery & signal status on the marker info window
///  • Live speed with vehicle-alert banner
///  • Dynamic ETA to parent's "Home" zone
///  • Offline "Last Known Location" with greyed map
///  • "Pick Me Up" — launches Google Maps routing to student
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

  // Current student state
  LatLng? _studentPosition;
  double _speedKmh = 0;
  int _batteryLevel = -1;
  bool _isTracking = false;
  DateTime? _lastSeen;
  bool _signalLost = false;
  bool _vehicleAlertShown = false;

  // Breadcrumbs
  List<LatLng> _breadcrumbs = [];

  // Map objects
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // Firestore stream
  StreamSubscription<DocumentSnapshot>? _locationSub;
  StreamSubscription<QuerySnapshot>? _breadcrumbSub;

  // Animation for signal-lost overlay
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
          _parentLocation = LatLng((widget.homeZone!['lat'] as num).toDouble(), (widget.homeZone!['lng'] as num).toDouble());
          _parentLocationLoaded = true;
        });
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

  void _onLocationUpdate(DocumentSnapshot snap) {
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

    setState(() {
      _studentPosition = newPos;
      _speedKmh = speed;
      _batteryLevel = battery;
      _isTracking = isTracking;
      _lastSeen = ts?.toDate() ?? DateTime.now();
      _signalLost = false;
    });

    _updateMarker(newPos, battery, speed, isTracking);

    // Animate camera to follow student
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(newPos),
      );
      _isCameraInitialized = true;
    }

    // Vehicle alert
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
          color: _neonCyan.withOpacity(0.8),
          width: 3,
          patterns: [PatternItem.dot, PatternItem.gap(8)],
        ));
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SIGNAL TIMEOUT
  // ─────────────────────────────────────────────────────────────────────────

  Timer? _signalTimer;

  void _subscribeToSignalTimeout() {
    // Check every 30 seconds if we've had an update in the last 2 minutes
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
    // Add a "signal lost" marker
    if (_studentPosition != null) {
      _updateMarkerSignalLost(_studentPosition!);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MARKERS
  // ─────────────────────────────────────────────────────────────────────────

  void _updateMarker(
      LatLng pos, int battery, double speed, bool isTracking) {
    final batteryEmoji = battery < 0
        ? '🔋?'
        : battery <= 20
            ? '🪫 ${battery}%'
            : battery <= 50
                ? '🔋 ${battery}%'
                : '🔋 ${battery}%';

    final speedText =
        speed < 0.5 ? 'Stationary' : '${speed.toStringAsFixed(1)} km/h';

    final lastSeenText = _lastSeen != null
        ? _formatTime(_lastSeen!)
        : 'Unknown';

    setState(() {
      _markers
        ..removeWhere((m) => m.markerId.value == 'student')
        ..add(Marker(
          markerId: const MarkerId('student'),
          position: pos,
          icon: isTracking
              ? BitmapDescriptor.defaultMarkerWithHue(
                  battery <= 20
                      ? BitmapDescriptor.hueRed
                      : battery <= 50
                          ? BitmapDescriptor.hueYellow
                          : BitmapDescriptor.hueGreen)
              : BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueViolet),
          infoWindow: InfoWindow(
            title: '📍 ${widget.studentName}',
            snippet: '$batteryEmoji • $speedText • $lastSeenText',
          ),
        ));
    });
  }

  void _updateMarkerSignalLost(LatLng pos) {
    final timeText = _lastSeen != null ? _formatTime(_lastSeen!) : 'Unknown';
    setState(() {
      _markers
        ..removeWhere((m) => m.markerId.value == 'student')
        ..add(Marker(
          markerId: const MarkerId('student'),
          position: pos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(
            title: '📵 Signal Lost',
            snippet: 'Last seen at $timeText',
          ),
        ));
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTIONS
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
                '⚠️ ${widget.studentName} may be in a vehicle (${_speedKmh.toStringAsFixed(0)} km/h)',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> _launchPickMeUpRouting() async {
    if (_studentPosition == null) return;
    final lat = _studentPosition!.latitude;
    final lng = _studentPosition!.longitude;
    final name = Uri.encodeComponent(widget.studentName);

    // Try Google Maps app first, fall back to browser
    final Uri geoUri = Uri.parse(
        'google.navigation:q=$lat,$lng&mode=d');
    final Uri fallbackUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$name&travelmode=driving');

    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri);
    } else {
      await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
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

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          '📍 ${widget.studentName}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _bgColor.withOpacity(0.85),
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          if (_isTracking)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) => Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _neonCyan.withOpacity(0.4 + 0.6 * _pulseController.value),
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
              // Greyscale filter when signal is lost
              colorFilter: _signalLost
                  ? const ColorFilter.matrix([
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0,      0,      0,      1, 0,
                    ])
                  : const ColorFilter.mode(
                      Colors.transparent, BlendMode.multiply),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _studentPosition ?? _parentLocation,
                  zoom: 16,
                ),
                onMapCreated: (ctrl) {
                  _mapController = ctrl;
                  // Apply dark style JSON for night mode feel
                  _mapController?.setMapStyle(_darkMapStyle);
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
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: true,
                mapToolbarEnabled: false,
              ),
            ),
          ),

          // ── SIGNAL LOST OVERLAY ──────────────────────────────────────────
          if (_signalLost)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _neonRed.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    '📵 Signal Lost — Last seen ${_lastSeen != null ? _formatTime(_lastSeen!) : 'unknown'}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
              ),
            ),

          // ── BOTTOM SHEET ────────────────────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Student info row
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _isTracking
                            ? _neonCyan.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.2),
                        radius: 24,
                        child: Icon(Icons.school,
                            color: _isTracking ? _neonCyan : Colors.grey),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.studentName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _isTracking
                                  ? '🟢 Live tracking active'
                                  : '🔴 Tracking paused',
                              style: TextStyle(
                                  color: _isTracking
                                      ? _neonCyan
                                      : Colors.redAccent,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      // Battery icon
                      if (_batteryLevel >= 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _batteryLevel <= 20
                                ? _neonRed.withOpacity(0.15)
                                : _neonCyan.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _batteryLevel <= 20
                                  ? _neonRed
                                  : _neonCyan,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _batteryLevel <= 20
                                    ? Icons.battery_alert
                                    : Icons.battery_full,
                                color: _batteryLevel <= 20
                                    ? _neonRed
                                    : _neonCyan,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$_batteryLevel%',
                                style: TextStyle(
                                  color: _batteryLevel <= 20
                                      ? _neonRed
                                      : _neonCyan,
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
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 12),

                  // Stats row
                  Row(
                    children: [
                      _statChip(
                        icon: Icons.speed,
                        label: 'Speed',
                        value: _speedKmh < 0.5
                            ? 'Still'
                            : '${_speedKmh.toStringAsFixed(1)} km/h',
                        color: _speedKmh > 25 ? _neonOrange : _neonCyan,
                      ),
                      const SizedBox(width: 8),
                      _statChip(
                        icon: Icons.home,
                        label: 'ETA Home',
                        value: _getEtaText(),
                        color: _neonBlue,
                      ),
                      const SizedBox(width: 8),
                      _statChip(
                        icon: Icons.timeline,
                        label: 'Trail',
                        value: '${_breadcrumbs.length} pts',
                        color: _neonCyan,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _actionButton(
                          icon: Icons.directions_car,
                          label: 'Pick Me Up',
                          color: MPesaTheme.primaryGreen,
                          onTap: _launchPickMeUpRouting,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _actionButton(
                          icon: Icons.my_location,
                          label: 'Center Map',
                          color: _neonBlue,
                          onTap: () {
                            if (_studentPosition != null) {
                              _mapController?.animateCamera(
                                CameraUpdate.newCameraPosition(CameraPosition(
                                  target: _studentPosition!,
                                  zoom: 17,
                                )),
                              );
                            }
                          },
                        ),
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

  Widget _statChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            Text(label,
                style:
                    const TextStyle(color: _textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ],
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
  {"featureType":"administrative.country","elementType":"geometry.stroke","stylers":[{"color":"#4b6878"}]},
  {"featureType":"administrative.land_parcel","elementType":"labels.text.fill","stylers":[{"color":"#64779e"}]},
  {"featureType":"administrative.province","elementType":"geometry.stroke","stylers":[{"color":"#4b6878"}]},
  {"featureType":"landscape.man_made","elementType":"geometry.stroke","stylers":[{"color":"#334e87"}]},
  {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#023e58"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#283d6a"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#6f9ba5"}]},
  {"featureType":"poi","elementType":"labels.text.stroke","stylers":[{"color":"#1d2c4d"}]},
  {"featureType":"poi.park","elementType":"geometry.fill","stylers":[{"color":"#023e58"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#3C7680"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#304a7d"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#98a5be"}]},
  {"featureType":"road","elementType":"labels.text.stroke","stylers":[{"color":"#1d2c4d"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2c6675"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#255763"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#b0d5ce"}]},
  {"featureType":"road.highway","elementType":"labels.text.stroke","stylers":[{"color":"#023747"}]},
  {"featureType":"transit","elementType":"labels.text.fill","stylers":[{"color":"#98a5be"}]},
  {"featureType":"transit","elementType":"labels.text.stroke","stylers":[{"color":"#1d2c4d"}]},
  {"featureType":"transit.line","elementType":"geometry.fill","stylers":[{"color":"#283d6a"}]},
  {"featureType":"transit.station","elementType":"geometry","stylers":[{"color":"#3a4762"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0e1626"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#4e6d70"}]}
]
''';
