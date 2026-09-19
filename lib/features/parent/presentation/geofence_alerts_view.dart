import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/services/geofence_service.dart';
import '../../../core/services/location_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS — match the parent dashboard dark palette
// ─────────────────────────────────────────────────────────────────────────────
const _bgColor = Color(0xFF0C101B);
const _cardColor = Color(0xFF131A2A);
const _neonCyan = Color(0xFF05D5AA);
const _neonBlue = Color(0xFF3B82F6);
const _neonOrange = Color(0xFFFF6F00);
const _neonRed = Color(0xFFF92B60);
const _textSecondary = Color(0xFF8B9BB4);

// Default campus centre (University of Nairobi — swap for real coords)
const LatLng _campusDefault = LatLng(-1.2793, 36.8166);
const double _defaultRadiusM = 500.0;

/// Upgraded geofence view with a real GoogleMap, draw-your-own-zone mode,
/// live student marker inside/outside the circle, and multi-zone management.
class GeofenceAlertsView extends StatefulWidget {
  final Map<String, dynamic> parentUser;
  final String? selectedStudentUid;

  const GeofenceAlertsView({
    super.key,
    required this.parentUser,
    this.selectedStudentUid,
  });

  @override
  State<GeofenceAlertsView> createState() => _GeofenceAlertsViewState();
}

class _GeofenceAlertsViewState extends State<GeofenceAlertsView> {
  GoogleMapController? _mapController;

  // Current zone being drawn
  LatLng _zoneCenter = _campusDefault;
  double _zoneRadius = _defaultRadiusM;
  String _zoneName = 'Campus Zone';
  bool _isDrawingMode = false;

  // Student position from Firestore
  LatLng? _studentPosition;
  bool _isOnCampus = false;
  bool _locationShared = false;

  // Saved zones from Firestore
  List<Map<String, dynamic>> _savedZones = [];

  final Set<Circle> _circles = {};
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _loadSavedZones();
    _fetchParentLocation();
  }

  LatLng _parentLocation = _campusDefault;
  bool _parentLocationLoaded = false;
  bool _isCameraInitialized = false;

  Future<void> _fetchParentLocation() async {
    final err = await LocationService.ensurePermissions();
    if (err == null) {
      try {
        final pos = await LocationService.getCurrentLocation();
        if (mounted) {
          setState(() {
            _parentLocation = LatLng(pos.latitude, pos.longitude);
            _parentLocationLoaded = true;
            if (_zoneCenter == _campusDefault) {
              _zoneCenter = _parentLocation;
            }
          });
          if (_mapController != null && _studentPosition == null && !_isCameraInitialized) {
            _mapController!.animateCamera(CameraUpdate.newLatLngZoom(_parentLocation, 15));
            _isCameraInitialized = true;
          }
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DATA LOADING
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadSavedZones() async {
    final parentUid = widget.parentUser['uid'] as String?;
    if (parentUid == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('geofences')
          .doc(parentUid)
          .collection('zones')
          .get();

      setState(() {
        _savedZones = snap.docs.map((d) {
          final data = d.data();
          return {...data, 'id': d.id};
        }).toList();
      });

      _rebuildMapObjects();
    } catch (e) {
      debugPrint('GeofenceAlertsView: Error loading zones — $e');
    }
  }

  void _rebuildMapObjects() {
    final newCircles = <Circle>{};
    final newMarkers = <Marker>{};

    // Draw all saved zones
    for (final zone in _savedZones) {
      final cLat = (zone['centerLat'] as num?)?.toDouble() ?? 0;
      final cLng = (zone['centerLng'] as num?)?.toDouble() ?? 0;
      final radius = (zone['radiusMeters'] as num?)?.toDouble() ?? 300;
      final name = zone['name'] as String? ?? 'Zone';
      final zoneId = zone['id'] as String;

      newCircles.add(Circle(
        circleId: CircleId(zoneId),
        center: LatLng(cLat, cLng),
        radius: radius,
        fillColor: _neonCyan.withOpacity(0.12),
        strokeColor: _neonCyan,
        strokeWidth: 2,
      ));

      newMarkers.add(Marker(
        markerId: MarkerId('zone_$zoneId'),
        position: LatLng(cLat, cLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        infoWindow: InfoWindow(title: '🛡️ $name', snippet: '${radius.round()}m radius'),
      ));
    }

    // Draw the in-progress zone if in draw mode
    if (_isDrawingMode) {
      newCircles.add(Circle(
        circleId: const CircleId('draft'),
        center: _zoneCenter,
        radius: _zoneRadius,
        fillColor: _neonBlue.withOpacity(0.15),
        strokeColor: _neonBlue,
        strokeWidth: 2,
      ));
      newMarkers.add(Marker(
        markerId: const MarkerId('draft_center'),
        position: _zoneCenter,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        draggable: true,
        onDragEnd: (pos) => setState(() => _zoneCenter = pos),
        infoWindow: InfoWindow(title: '📍 Drag to reposition', snippet: _zoneName),
      ));
    }

    // Student marker
    if (_studentPosition != null && _locationShared) {
      newMarkers.add(Marker(
        markerId: const MarkerId('student'),
        position: _studentPosition!,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _isOnCampus ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
        ),
        infoWindow: InfoWindow(
          title: _isOnCampus ? '✅ Inside Safe Zone' : '⚠️ Outside Safe Zone',
        ),
      ));
    }

    setState(() {
      _circles
        ..clear()
        ..addAll(newCircles);
      _markers
        ..clear()
        ..addAll(newMarkers);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SAVE ZONE
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _saveZone() async {
    final parentUid = widget.parentUser['uid'] as String?;
    if (parentUid == null) return;
    final studentUid = widget.selectedStudentUid;

    try {
      await FirebaseFirestore.instance
          .collection('geofences')
          .doc(parentUid)
          .collection('zones')
          .add({
        'name': _zoneName,
        'centerLat': _zoneCenter.latitude,
        'centerLng': _zoneCenter.longitude,
        'radiusMeters': _zoneRadius,
        'studentUid': studentUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _neonCyan,
            content: Text(
              '✅ Zone "$_zoneName" saved!',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }

      setState(() => _isDrawingMode = false);
      await _loadSavedZones();
    } catch (e) {
      debugPrint('GeofenceAlertsView: Error saving zone — $e');
    }
  }

  Future<void> _deleteZone(String zoneId) async {
    final parentUid = widget.parentUser['uid'] as String?;
    if (parentUid == null) return;
    await FirebaseFirestore.instance
        .collection('geofences')
        .doc(parentUid)
        .collection('zones')
        .doc(zoneId)
        .delete();
    await _loadSavedZones();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CHECK STUDENT STATUS vs saved zones
  // ─────────────────────────────────────────────────────────────────────────

  void _evaluateStudentPosition(LatLng pos) {
    bool inside = false;
    for (final zone in _savedZones) {
      final cLat = (zone['centerLat'] as num?)?.toDouble() ?? 0;
      final cLng = (zone['centerLng'] as num?)?.toDouble() ?? 0;
      final radius = (zone['radiusMeters'] as num?)?.toDouble() ?? 300;
      if (GeofenceService.isInsideCircle(
          pos.latitude, pos.longitude, cLat, cLng, radius)) {
        inside = true;
        break;
      }
    }
    setState(() => _isOnCampus = inside);
    _rebuildMapObjects();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Campus Geofence',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: () {
              setState(() {
                _isDrawingMode = !_isDrawingMode;
                _zoneCenter = _parentLocationLoaded ? _parentLocation : _campusDefault;
                _zoneRadius = _defaultRadiusM;
              });
              _rebuildMapObjects();
            },
            icon: Icon(
              _isDrawingMode ? Icons.close : Icons.add_circle_outline,
              color: _neonCyan,
            ),
            label: Text(
              _isDrawingMode ? 'Cancel' : 'New Zone',
              style: const TextStyle(color: _neonCyan),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── MAP ───────────────────────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                // Student stream + map
                widget.selectedStudentUid == null
                    ? _noStudentPlaceholder()
                    : StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.selectedStudentUid)
                            .snapshots(),
                        builder: (context, snap) {
                          if (snap.hasData && snap.data!.exists) {
                            final data =
                                snap.data!.data() as Map<String, dynamic>;
                            _locationShared =
                                data['shareLocationWithParents'] ?? false;
                            final locData =
                                data['location'] as Map<String, dynamic>?;
                            if (locData != null && _locationShared) {
                              final lat =
                                  (locData['lat'] as num?)?.toDouble();
                              final lng =
                                  (locData['lng'] as num?)?.toDouble();
                              if (lat != null && lng != null) {
                                final pos = LatLng(lat, lng);
                                  // Update only if position changed
                                  if (_studentPosition != pos) {
                                    final isFirstTime = _studentPosition == null;
                                    _studentPosition = pos;
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      _evaluateStudentPosition(pos);
                                      if (isFirstTime && _mapController != null && !_isCameraInitialized) {
                                        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(pos, 15));
                                        _isCameraInitialized = true;
                                      }
                                    });
                                  }
                              }
                            }
                          }

                          return GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: _studentPosition ?? _parentLocation,
                              zoom: 15,
                            ),
                            onMapCreated: (ctrl) {
                              _mapController = ctrl;
                              _mapController?.setMapStyle(_darkMapStyle);
                              if (!_isCameraInitialized) {
                                final target = _studentPosition ?? (_parentLocationLoaded ? _parentLocation : null);
                                if (target != null) {
                                  _mapController!.animateCamera(CameraUpdate.newLatLngZoom(target, 15));
                                  _isCameraInitialized = true;
                                }
                              }
                            },
                            onTap: _isDrawingMode
                                ? (pos) {
                                    setState(() => _zoneCenter = pos);
                                    _rebuildMapObjects();
                                  }
                                : null,
                            circles: _circles,
                            markers: _markers,
                            zoomControlsEnabled: false,
                            mapToolbarEnabled: false,
                          );
                        },
                      ),

                // No-location-consent banner
                if (widget.selectedStudentUid != null && !_locationShared)
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _neonOrange.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.location_off, color: Colors.white),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Student has not enabled location sharing.',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Status badge (inside / outside)
                if (_locationShared && _studentPosition != null)
                  Positioned(
                    bottom: 12,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _isOnCampus
                            ? MPesaTheme.primaryGreen.withOpacity(0.9)
                            : _neonRed.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: (_isOnCampus
                                    ? MPesaTheme.primaryGreen
                                    : _neonRed)
                                .withOpacity(0.4),
                            blurRadius: 12,
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isOnCampus
                                ? Icons.verified_user
                                : Icons.warning_amber,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isOnCampus
                                ? '✅ Inside Safe Zone'
                                : '⚠️ Outside Safe Zone',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── DRAW MODE PANEL ────────────────────────────────────────────────
          if (_isDrawingMode) _buildDrawPanel(),

          // ── SAVED ZONES LIST ───────────────────────────────────────────────
          if (!_isDrawingMode && _savedZones.isNotEmpty)
            _buildZonesList(),
        ],
      ),
    );
  }

  Widget _buildDrawPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: _cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Draw New Safe Zone',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Tap the map to set the zone center.',
              style: TextStyle(color: _textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          // Zone name input
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Zone name (e.g. Campus, Home)',
              hintStyle: const TextStyle(color: _textSecondary),
              filled: true,
              fillColor: const Color(0xFF1A2235),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _zoneName = v),
            controller: TextEditingController(text: _zoneName),
          ),
          const SizedBox(height: 12),
          // Radius slider
          Row(
            children: [
              const Icon(Icons.radar, color: _neonBlue, size: 18),
              const SizedBox(width: 8),
              Text(
                'Radius: ${_zoneRadius.round()}m',
                style: const TextStyle(color: Colors.white),
              ),
              Expanded(
                child: Slider(
                  value: _zoneRadius,
                  min: 50,
                  max: 2000,
                  activeColor: _neonBlue,
                  inactiveColor: _neonBlue.withOpacity(0.2),
                  onChanged: (v) {
                    setState(() => _zoneRadius = v);
                    _rebuildMapObjects();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveZone,
              icon: const Icon(Icons.save),
              label: const Text('Save Zone'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _neonCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZonesList() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      color: _cardColor,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _savedZones.length,
        separatorBuilder: (_, __) =>
            const Divider(color: Colors.white12, height: 1),
        itemBuilder: (context, i) {
          final zone = _savedZones[i];
          final name = zone['name'] as String? ?? 'Zone';
          final radius = (zone['radiusMeters'] as num?)?.round() ?? 0;
          final zoneId = zone['id'] as String;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading:
                const CircleAvatar(
                  backgroundColor: Color(0xFF1A2235),
                  child: Icon(Icons.radar, color: _neonCyan, size: 18)),
            title: Text(name,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text('${radius}m radius',
                style: const TextStyle(color: _textSecondary, fontSize: 12)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: _neonRed),
              onPressed: () => _deleteZone(zoneId),
            ),
            onTap: () {
              final cLat =
                  (zone['centerLat'] as num?)?.toDouble() ?? 0;
              final cLng =
                  (zone['centerLng'] as num?)?.toDouble() ?? 0;
              _mapController?.animateCamera(
                CameraUpdate.newLatLngZoom(LatLng(cLat, cLng), 15),
              );
            },
          );
        },
      ),
    );
  }

  Widget _noStudentPlaceholder() {
    return Container(
      color: _bgColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search,
                size: 64, color: _neonCyan.withOpacity(0.4)),
            const SizedBox(height: 16),
            const Text(
              'No student selected',
              style: TextStyle(color: _textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select a student in the Dependents tab.',
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
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
  {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#023e58"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#283d6a"}]},
  {"featureType":"poi.park","elementType":"geometry.fill","stylers":[{"color":"#023e58"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#304a7d"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2c6675"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0e1626"}]}
]
''';
