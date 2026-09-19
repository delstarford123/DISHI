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
const _neonPink = Color(0xFFF92B60);
const _neonGreen = Color(0xFF22C55E);
const _textSecondary = Color(0xFF8B9BB4);

// Campus centre fallback
const LatLng _campusCenter = LatLng(-1.2793, 36.8166);

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

enum _ServicesTab { dishi, swapeat, housing, reminders }

class _LocationReminder {
  final String id;
  final String message;
  final double triggerLat;
  final double triggerLng;
  final double radiusMeters;
  bool active;

  _LocationReminder({
    required this.id,
    required this.message,
    required this.triggerLat,
    required this.triggerLng,
    required this.radiusMeters,
    required this.active,
  });

  factory _LocationReminder.fromFirestore(
      String id, Map<String, dynamic> data) {
    return _LocationReminder(
      id: id,
      message: data['message'] as String? ?? '',
      triggerLat: (data['triggerLat'] as num?)?.toDouble() ?? 0,
      triggerLng: (data['triggerLng'] as num?)?.toDouble() ?? 0,
      radiusMeters: (data['radiusMeters'] as num?)?.toDouble() ?? 50,
      active: data['active'] as bool? ?? true,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VIEW
// ─────────────────────────────────────────────────────────────────────────────

/// Campus services map combining Dishi delivery tracking, Swapeat vendor
/// hotspots, House Hunters proximity, and location-based reminders.
class NearbyServicesMapView extends StatefulWidget {
  final String studentUid;
  final String? activeOrderId; // Pass if student has an active Dishi order

  const NearbyServicesMapView({
    super.key,
    required this.studentUid,
    this.activeOrderId,
  });

  @override
  State<NearbyServicesMapView> createState() => _NearbyServicesMapViewState();
}

class _NearbyServicesMapViewState extends State<NearbyServicesMapView> {
  GoogleMapController? _mapController;
  Position? _myPosition;
  StreamSubscription<Position>? _posSub;
  _ServicesTab _activeTab = _ServicesTab.dishi;
  bool _isCameraInitialized = false;

  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};

  // Reminders state
  List<_LocationReminder> _reminders = [];
  final _reminderMsgController = TextEditingController();
  double _reminderRadius = 50;

  @override
  void initState() {
    super.initState();
    _startPositionWatch();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _mapController?.dispose();
    _reminderMsgController.dispose();
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

    _posSub = LocationService.getLocationStream(distanceFilter: 15)
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
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Campus Services',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── TAB BAR ───────────────────────────────────────────────────────
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
                    _loadTabData();
                  },
                  markers: _markers,
                  circles: _circles,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  onTap: _activeTab == _ServicesTab.reminders
                      ? _onMapTapForReminder
                      : null,
                ),

                // My location FAB
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'services_locate',
                    backgroundColor: _cardColor,
                    onPressed: _centerOnMe,
                    child: const Icon(Icons.my_location, color: _neonCyan),
                  ),
                ),

                // Reminders tap-to-set instruction
                if (_activeTab == _ServicesTab.reminders)
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _neonBlue.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.touch_app, color: Colors.white, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tap the map to place a location reminder trigger.',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── BOTTOM CONTENT PANEL ──────────────────────────────────────────
          _buildBottomPanel(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB BAR
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    final tabs = [
      (_ServicesTab.dishi, '🍔 Delivery', _neonOrange),
      (_ServicesTab.swapeat, '🥘 DISHI', _neonCyan),
      (_ServicesTab.housing, '🏠 Housing', _neonBlue),
      (_ServicesTab.reminders, '📍 Reminders', _neonPink),
    ];
    return Container(
      color: _cardColor,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: tabs.map((t) {
            final isActive = _activeTab == t.$1;
            return GestureDetector(
              onTap: () {
                setState(() => _activeTab = t.$1);
                _loadTabData();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? t.$3 : _bgColor,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                      color: isActive ? t.$3 : Colors.white12),
                ),
                child: Text(
                  t.$2,
                  style: TextStyle(
                    color: isActive ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DATA LOADING PER TAB
  // ─────────────────────────────────────────────────────────────────────────

  void _loadTabData() {
    switch (_activeTab) {
      case _ServicesTab.dishi:
        _loadDeliveryTracking();
      case _ServicesTab.swapeat:
        _loadSwapeatVendors();
      case _ServicesTab.housing:
        _loadHousingProperties();
      case _ServicesTab.reminders:
        _loadReminders();
    }
  }

  // ── DISHI: Live delivery tracking ────────────────────────────────────────

  StreamSubscription<DocumentSnapshot>? _deliverySub;

  void _loadDeliveryTracking() {
    _deliverySub?.cancel();
    if (widget.activeOrderId == null) {
      setState(() {
        _markers.clear();
        _circles.clear();
      });
      return;
    }

    _deliverySub = FirebaseFirestore.instance
        .collection('deliveries')
        .doc(widget.activeOrderId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      final data = snap.data()!;
      final driverLat = (data['driverLat'] as num?)?.toDouble();
      final driverLng = (data['driverLng'] as num?)?.toDouble();
      if (driverLat == null || driverLng == null) return;

      final driverPos = LatLng(driverLat, driverLng);
      final driverName = data['driverName'] as String? ?? 'Driver';
      final etaMinutes = data['etaMinutes'] as int? ?? 0;

      final newMarkers = <Marker>{};
      newMarkers.add(Marker(
        markerId: const MarkerId('driver'),
        position: driverPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(
          title: '🛵 $driverName',
          snippet: 'ETA: $etaMinutes min',
        ),
      ));

      // Student position
      if (_myPosition != null) {
        newMarkers.add(Marker(
          markerId: const MarkerId('me'),
          position: LatLng(_myPosition!.latitude, _myPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: '📍 You'),
        ));
      }

      setState(() {
        _markers
          ..clear()
          ..addAll(newMarkers);
        _circles.clear();
      });

      _mapController?.animateCamera(CameraUpdate.newLatLng(driverPos));
    });
  }

  // ── SWAPEAT: Nearby open vendors ─────────────────────────────────────────

  void _loadSwapeatVendors() async {
    _deliverySub?.cancel();
    try {
      final snap = await FirebaseFirestore.instance
          .collection('vendors')
          .where('isOpen', isEqualTo: true)
          .get();

      final newMarkers = <Marker>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final lat = (data['lat'] as num?)?.toDouble();
        final lng = (data['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final name = data['businessName'] as String? ?? 'Vendor';
        final pos = LatLng(lat, lng);
        double distM = 0;
        if (_myPosition != null) {
          distM = LocationService.distanceMeters(
              _myPosition!.latitude, _myPosition!.longitude, lat, lng);
        }

        newMarkers.add(Marker(
          markerId: MarkerId('vendor_${doc.id}'),
          position: pos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          infoWindow: InfoWindow(
            title: '🥘 $name',
            snippet:
                '🟢 Open • ${distM > 0 ? "${distM.round()}m away" : ""}',
          ),
          onTap: () => _showVendorSheet(data, distM),
        ));
      }

      if (_myPosition != null) {
        newMarkers.add(Marker(
          markerId: const MarkerId('me'),
          position: LatLng(_myPosition!.latitude, _myPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: '📍 You'),
        ));
      }

      setState(() {
        _markers
          ..clear()
          ..addAll(newMarkers);
        _circles.clear();
      });
    } catch (e) {
      debugPrint('NearbyServicesMapView: Error loading vendors — $e');
    }
  }

  void _showVendorSheet(Map<String, dynamic> vendor, double distM) {
    final name = vendor['businessName'] as String? ?? 'Vendor';
    final categories = vendor['categories'] as List<dynamic>? ?? [];
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
                  backgroundColor: _neonCyan.withOpacity(0.15),
                  child: const Icon(Icons.restaurant, color: _neonCyan),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const Text('🟢 Open Now',
                          style: TextStyle(color: _neonGreen, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Distance',
                        style: TextStyle(color: _textSecondary, fontSize: 11)),
                    Text(
                      distM > 0 ? '${distM.round()}m' : '—',
                      style: const TextStyle(
                          color: _neonCyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                    if (distM > 0)
                      Text(
                        '~${(distM / 1000 / 5 * 60).round()} min walk',
                        style: const TextStyle(
                            color: _textSecondary, fontSize: 10),
                      ),
                  ],
                ),
              ],
            ),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: categories
                    .map((c) => Chip(
                          label: Text(c.toString(),
                              style: const TextStyle(fontSize: 11)),
                          backgroundColor: _neonCyan.withOpacity(0.1),
                          labelStyle: const TextStyle(color: _neonCyan),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── HOUSING: Nearby properties with commute time ──────────────────────────

  void _loadHousingProperties() async {
    _deliverySub?.cancel();
    try {
      final snap = await FirebaseFirestore.instance
          .collection('properties')
          .where('isAvailable', isEqualTo: true)
          .get();

      final newMarkers = <Marker>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final lat = (data['latitude'] as num?)?.toDouble() ??
            (data['lat'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble() ??
            (data['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final name = data['title'] as String? ?? 'Property';
        final rent = data['rentAmount'] ?? data['rent'] ?? 0;
        final pos = LatLng(lat, lng);

        // Walking commute to campus centre (≈5km/h avg walking)
        final distToCampusM = GeofenceService.haversineMeters(
            lat, lng, _campusCenter.latitude, _campusCenter.longitude);
        final walkMins = (distToCampusM / 1000 / 5 * 60).round();

        newMarkers.add(Marker(
          markerId: MarkerId('prop_${doc.id}'),
          position: pos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: '🏠 $name',
            snippet: 'KSH $rent/mo • $walkMins min to campus',
          ),
        ));
      }

      if (_myPosition != null) {
        newMarkers.add(Marker(
          markerId: const MarkerId('me'),
          position: LatLng(_myPosition!.latitude, _myPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: '📍 You'),
        ));
      }

      setState(() {
        _markers
          ..clear()
          ..addAll(newMarkers);
        _circles.clear();
      });
    } catch (e) {
      debugPrint('NearbyServicesMapView: Housing error — $e');
    }
  }

  // ── REMINDERS ─────────────────────────────────────────────────────────────

  Future<void> _loadReminders() async {
    _deliverySub?.cancel();
    try {
      final snap = await FirebaseFirestore.instance
          .collection('location_reminders')
          .doc(widget.studentUid)
          .collection('reminders')
          .get();

      final reminders = snap.docs
          .map((d) => _LocationReminder.fromFirestore(d.id, d.data()))
          .toList();

      final newMarkers = <Marker>{};
      final newCircles = <Circle>{};
      for (final r in reminders) {
        final pos = LatLng(r.triggerLat, r.triggerLng);
        newMarkers.add(Marker(
          markerId: MarkerId('reminder_${r.id}'),
          position: pos,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              r.active ? BitmapDescriptor.hueViolet : BitmapDescriptor.hueRose),
          infoWindow: InfoWindow(
            title: r.active ? '📍 ${r.message}' : '✅ ${r.message}',
            snippet: '${r.radiusMeters.round()}m trigger radius',
          ),
        ));
        newCircles.add(Circle(
          circleId: CircleId('reminder_zone_${r.id}'),
          center: pos,
          radius: r.radiusMeters,
          fillColor: _neonPink.withOpacity(0.1),
          strokeColor: r.active ? _neonPink : Colors.white24,
          strokeWidth: 1,
        ));
      }

      setState(() {
        _reminders = reminders;
        _markers
          ..clear()
          ..addAll(newMarkers);
        _circles
          ..clear()
          ..addAll(newCircles);
      });
    } catch (e) {
      debugPrint('NearbyServicesMapView: Reminders error — $e');
    }
  }

  LatLng? _pendingReminderPos;

  void _onMapTapForReminder(LatLng pos) {
    setState(() => _pendingReminderPos = pos);
    _showAddReminderSheet(pos);
  }

  void _showAddReminderSheet(LatLng pos) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New Location Reminder',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                '📍 ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
                style: const TextStyle(color: _textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _reminderMsgController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Reminder message',
                  hintStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: const Color(0xFF1A2235),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.radar, color: _neonPink, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Radius: ${_reminderRadius.round()}m',
                    style: const TextStyle(color: Colors.white),
                  ),
                  Expanded(
                    child: Slider(
                      value: _reminderRadius,
                      min: 20,
                      max: 500,
                      activeColor: _neonPink,
                      inactiveColor: _neonPink.withOpacity(0.2),
                      onChanged: (v) =>
                          setModalState(() => _reminderRadius = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (_reminderMsgController.text.isEmpty) return;
                    Navigator.pop(ctx);
                    await _saveReminder(
                        pos, _reminderMsgController.text, _reminderRadius);
                    _reminderMsgController.clear();
                    _loadReminders();
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Save Reminder'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonPink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveReminder(
      LatLng pos, String message, double radiusM) async {
    await FirebaseFirestore.instance
        .collection('location_reminders')
        .doc(widget.studentUid)
        .collection('reminders')
        .add({
      'message': message,
      'triggerLat': pos.latitude,
      'triggerLng': pos.longitude,
      'radiusMeters': radiusM,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOTTOM PANEL
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBottomPanel() {
    switch (_activeTab) {
      case _ServicesTab.dishi:
        return _dishiPanel();
      case _ServicesTab.swapeat:
        return _swapeatPanel();
      case _ServicesTab.housing:
        return _housingPanel();
      case _ServicesTab.reminders:
        return _remindersPanel();
    }
  }

  Widget _dishiPanel() {
    if (widget.activeOrderId == null) {
      return _infoPanel(
          Icons.delivery_dining,
          'No Active Order',
          'Your Dishi delivery driver will appear here when you have an active order.',
          _neonOrange);
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('deliveries')
          .doc(widget.activeOrderId)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return _infoPanel(Icons.delivery_dining, 'Loading delivery...',
              '', _neonOrange);
        }
        final data = snap.data!.data() as Map<String, dynamic>;
        final driver = data['driverName'] as String? ?? 'Your driver';
        final eta = data['etaMinutes'] as int? ?? 0;
        final status = data['status'] as String? ?? 'In transit';

        return Container(
          padding: const EdgeInsets.all(20),
          color: _cardColor,
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: _neonOrange.withOpacity(0.15),
                child: const Icon(Icons.delivery_dining, color: _neonOrange),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🛵 $driver',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    Text(status,
                        style: const TextStyle(
                            color: _textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$eta min',
                      style: const TextStyle(
                          color: _neonOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 22)),
                  const Text('ETA',
                      style: TextStyle(color: _textSecondary, fontSize: 11)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _swapeatPanel() {
    return _infoPanel(
        Icons.restaurant_menu,
        'Nearby Open Vendors',
        'Tap a marker to see vendor details and walking distance.',
        _neonCyan);
  }

  Widget _housingPanel() {
    return _infoPanel(
        Icons.home_work,
        'Available Properties',
        'Each pin shows walking commute time to campus centre.',
        _neonBlue);
  }

  Widget _remindersPanel() {
    if (_reminders.isEmpty) {
      return _infoPanel(
          Icons.location_on,
          'No Reminders Yet',
          'Tap anywhere on the map to add a location-based reminder.',
          _neonPink);
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      color: _cardColor,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _reminders.length,
        itemBuilder: (_, i) {
          final r = _reminders[i];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: _neonPink.withOpacity(0.12),
              child: Icon(Icons.notifications_active,
                  color: r.active ? _neonPink : Colors.white38, size: 18),
            ),
            title: Text(r.message,
                style: TextStyle(
                    color: r.active ? Colors.white : Colors.white38,
                    fontWeight: FontWeight.w600)),
            subtitle: Text('${r.radiusMeters.round()}m radius',
                style: const TextStyle(color: _textSecondary, fontSize: 11)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: _neonPink, size: 18),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('location_reminders')
                    .doc(widget.studentUid)
                    .collection('reminders')
                    .doc(r.id)
                    .delete();
                _loadReminders();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _infoPanel(
      IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: _cardColor,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style: const TextStyle(
                          color: _textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _centerOnMe() {
    if (_myPosition != null) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(
          target: LatLng(_myPosition!.latitude, _myPosition!.longitude),
          zoom: 16,
        )),
      );
    }
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
