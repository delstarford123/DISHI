import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/utils/map_marker_helper.dart';

class DelivActiveRouteView extends StatefulWidget {
  final String? rideId;
  const DelivActiveRouteView({super.key, this.rideId});

  @override
  State<DelivActiveRouteView> createState() => _DelivActiveRouteViewState();
}

class _DelivActiveRouteViewState extends State<DelivActiveRouteView> {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionStream;
  LatLng? _currentLatLng;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _isTracking = false;
  bool _permissionDenied = false;
  final String _driverUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  MapType _currentMapType = MapType.normal;

  // Order Details from Firestore
  Map<String, dynamic>? _gigData;
  String _customerName = 'Campus Student';
  String? _customerPhotoUrl;
  String _customerPhone = '';
  String _pickupLocation = 'Campus Cafeteria';
  String _dropoffLocation = 'Student Hostel';
  String _deliveryStage = 'en_route_pickup'; // en_route_pickup, at_pickup, delivering, arrived
  double? _targetLat;
  double? _targetLng;

  static const _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 8, // update every 8 meters
  );

  @override
  void initState() {
    super.initState();
    _loadGigDetails();
    _startTracking();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  /// Load gig details from deliv_requests or deliv_rides
  Future<void> _loadGigDetails() async {
    if (widget.rideId == null) return;
    try {
      DocumentSnapshot snap = await FirebaseFirestore.instance
          .collection('deliv_requests')
          .doc(widget.rideId)
          .get();

      if (!snap.exists) {
        snap = await FirebaseFirestore.instance
            .collection('deliv_rides')
            .doc(widget.rideId)
            .get();
      }

      if (snap.exists && mounted) {
        final data = snap.data() as Map<String, dynamic>;
        setState(() {
          _gigData = data;
          _pickupLocation = data['pickup'] ?? data['pickup_location'] ?? 'Campus Cafeteria';
          _dropoffLocation = data['dropoff'] ?? data['delivery_location'] ?? 'Student Hostel';
          _deliveryStage = data['stage'] ?? 'en_route_pickup';
        });

        // Fetch customer details if postedBy or user_id exists
        final customerId = data['postedBy'] ?? data['user_id'] ?? data['requester_id'];
        if (customerId != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(customerId).get();
          if (userDoc.exists && mounted) {
            final uData = userDoc.data()!;
            setState(() {
              _customerName = uData['displayName'] ?? uData['name'] ?? uData['firstName'] ?? 'Student Customer';
              _customerPhone = uData['phoneNumber'] ?? uData['phone'] ?? '';
              _customerPhotoUrl = (uData['profileImageUrl'] ?? uData['photoUrl']) as String?;
            });
          }
        }

        _setupMapMarkers();
      }
    } catch (e) {
      debugPrint('Error loading gig details: $e');
    }
  }

  Future<void> _setupMapMarkers() async {
    if (!mounted) return;
    final Set<Marker> newMarkers = {};

    // 1. Current Driver Marker with custom Courier Pin
    if (_currentLatLng != null) {
      final driverIcon = await MapMarkerHelper.createCourierMarker(riderName: 'You');
      newMarkers.add(
        Marker(
          markerId: const MarkerId('driver_location'),
          position: _currentLatLng!,
          icon: driverIcon,
          zIndex: 10,
          infoWindow: const InfoWindow(title: 'You (DISHI Courier) 🛵', snippet: 'En route'),
        ),
      );
    }

    // 2. Pickup Cafeteria Marker (Estimated or actual coords)
    double pickupLat = _gigData?['pickup_lat']?.toDouble() ??
        (_currentLatLng != null ? _currentLatLng!.latitude + 0.0035 : -1.286389);
    double pickupLng = _gigData?['pickup_lng']?.toDouble() ??
        (_currentLatLng != null ? _currentLatLng!.longitude - 0.0020 : 36.817223);

    newMarkers.add(
      Marker(
        markerId: const MarkerId('pickup_cafeteria'),
        position: LatLng(pickupLat, pickupLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(
          title: 'Pickup: $_pickupLocation 🍔',
          snippet: 'Collect meal package at counter',
        ),
      ),
    );

    // 3. Dropoff Customer Marker with Student Avatar
    double dropoffLat = _gigData?['dropoff_lat']?.toDouble() ??
        (_currentLatLng != null ? _currentLatLng!.latitude + 0.0080 : -1.281000);
    double dropoffLng = _gigData?['dropoff_lng']?.toDouble() ??
        (_currentLatLng != null ? _currentLatLng!.longitude + 0.0040 : 36.822000);

    final customerAvatarIcon = await MapMarkerHelper.createStudentAvatarMarker(
      name: _customerName,
      profileImageUrl: _customerPhotoUrl,
      borderColor: const Color(0xFF38BDF8),
    );

    newMarkers.add(
      Marker(
        markerId: const MarkerId('dropoff_customer'),
        position: LatLng(dropoffLat, dropoffLng),
        icon: customerAvatarIcon,
        zIndex: 8,
        infoWindow: InfoWindow(
          title: 'Dropoff: $_customerName 📍',
          snippet: 'Destination: $_dropoffLocation',
        ),
      ),
    );

    // Target for navigation depends on current stage
    if (_deliveryStage == 'en_route_pickup' || _deliveryStage == 'at_pickup') {
      _targetLat = pickupLat;
      _targetLng = pickupLng;
    } else {
      _targetLat = dropoffLat;
      _targetLng = dropoffLng;
    }

    // Connect with polyline if driver location is available
    final Set<Polyline> newPolylines = {};
    if (_currentLatLng != null && _targetLat != null && _targetLng != null) {
      newPolylines.add(
        Polyline(
          polylineId: const PolylineId('delivery_route'),
          color: MPesaTheme.primaryGreen,
          width: 5,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          points: [
            _currentLatLng!,
            LatLng(_targetLat!, _targetLng!),
          ],
        ),
      );
    }

    if (mounted) {
      setState(() {
        _markers
          ..clear()
          ..addAll(newMarkers);
        _polylines
          ..clear()
          ..addAll(newPolylines);
      });
    }
  }

  Future<void> _startTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _permissionDenied = true);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      if (mounted) setState(() => _permissionDenied = true);
      return;
    }

    setState(() => _isTracking = true);

    // Get immediate position first
    try {
      Position initialPos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentLatLng = LatLng(initialPos.latitude, initialPos.longitude);
        });
        _setupMapMarkers();
      }
    } catch (_) {}

    _positionStream =
        Geolocator.getPositionStream(locationSettings: _locationSettings)
            .listen((Position pos) async {
      final latLng = LatLng(pos.latitude, pos.longitude);

      // Stream driver location to Firestore
      try {
        await FirebaseFirestore.instance
            .collection('deliv_drivers')
            .doc(_driverUid)
            .set({
          'location': GeoPoint(pos.latitude, pos.longitude),
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'lastUpdated': FieldValue.serverTimestamp(),
          'isOnline': true,
        }, SetOptions(merge: true));

        // Update ride doc
        if (widget.rideId != null) {
          await FirebaseFirestore.instance
              .collection('deliv_requests')
              .doc(widget.rideId)
              .set({
            'driver_location': GeoPoint(pos.latitude, pos.longitude),
            'last_driver_update': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _currentLatLng = latLng;
        });
        _setupMapMarkers();
        _mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
      }
    });
  }

  /// Launch Google Maps App with Turn-by-Turn Navigation
  Future<void> _openGoogleMapsNavigation() async {
    if (_targetLat == null || _targetLng == null) {
      if (_currentLatLng == null) return;
      _targetLat = _currentLatLng!.latitude + 0.005;
      _targetLng = _currentLatLng!.longitude + 0.005;
    }

    // Google Navigation URI (Android & iOS)
    final googleNavUrl = Uri.parse(
        'google.navigation:q=$_targetLat,$_targetLng&mode=d');
    final webMapsUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$_targetLat,$_targetLng&travelmode=two-wheeler');

    try {
      if (await canLaunchUrl(googleNavUrl)) {
        await launchUrl(googleNavUrl);
      } else if (await canLaunchUrl(webMapsUrl)) {
        await launchUrl(webMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open Google Maps navigation.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching maps: $e');
    }
  }

  Future<void> _callCustomer() async {
    if (_customerPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer phone number not available.')),
      );
      return;
    }
    final url = Uri.parse('tel:$_customerPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _whatsappCustomer() async {
    if (_customerPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer phone number not available.')),
      );
      return;
    }
    String cleanPhone = _customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '254${cleanPhone.substring(1)}';
    }
    final url = Uri.parse(
        'https://wa.me/$cleanPhone?text=Hello%20$_customerName%2C%20this%20is%20your%20DISHI%20DeLiv%20courier.%20I%20am%20on%20my%20way%20with%20your%20meal%20order%21');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  /// Advance delivery lifecycle stage
  Future<void> _advanceStage() async {
    String nextStage;
    String feedbackMsg;

    if (_deliveryStage == 'en_route_pickup') {
      nextStage = 'at_pickup';
      feedbackMsg = 'Arrived at Cafeteria! Collect the meal package.';
    } else if (_deliveryStage == 'at_pickup') {
      nextStage = 'delivering';
      feedbackMsg = 'Meal collected! Head to student dorm.';
    } else if (_deliveryStage == 'delivering') {
      nextStage = 'arrived';
      feedbackMsg = 'Arrived at destination! Hand over meal to student.';
    } else {
      await _finishDelivery();
      return;
    }

    setState(() => _deliveryStage = nextStage);

    if (widget.rideId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('deliv_requests')
            .doc(widget.rideId)
            .update({
          'stage': nextStage,
          'stageUpdatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }

    _setupMapMarkers();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(feedbackMsg),
          backgroundColor: MPesaTheme.primaryGreen,
        ),
      );
    }
  }

  Future<void> _finishDelivery() async {
    _positionStream?.cancel();
    try {
      if (widget.rideId != null) {
        await FirebaseFirestore.instance
            .collection('deliv_requests')
            .doc(widget.rideId)
            .update({
          'status': 'completed',
          'stage': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });
      }

      await FirebaseFirestore.instance
          .collection('deliv_drivers')
          .doc(_driverUid)
          .set({
        'isOnline': true,
        'active_ride': null,
        'completedDeliveries': FieldValue.increment(1),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery Completed! Escrow earnings credited.'),
            backgroundColor: MPesaTheme.primaryGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error finishing delivery: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  /// Calculate distance between current location and destination
  String _getDistanceAndEta() {
    if (_currentLatLng == null || _targetLat == null || _targetLng == null) {
      return 'Calculating ETA...';
    }
    const earthRadius = 6371.0; // km
    final dLat = (_targetLat! - _currentLatLng!.latitude) * (pi / 180.0);
    final dLon = (_targetLng! - _currentLatLng!.longitude) * (pi / 180.0);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_currentLatLng!.latitude * (pi / 180.0)) *
            cos(_targetLat! * (pi / 180.0)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distanceKm = earthRadius * c;

    if (distanceKm < 0.1) {
      return 'Arrived at Destination';
    }

    final minutes = (distanceKm / 15.0 * 60).round(); // Avg 15 km/h for bike/walking
    return '${distanceKm.toStringAsFixed(1)} km · ~${max(1, minutes)} mins';
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return Scaffold(
        backgroundColor: const Color(0xFF0C101B),
        appBar: AppBar(
          title: const Text('Live Delivery Tracker', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off, size: 80, color: Colors.white38),
              const SizedBox(height: 16),
              const Text('Location Permission Required',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Enable high-accuracy location in settings\nto track campus food delivery en route.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async => await Geolocator.openAppSettings(),
                icon: const Icon(Icons.settings, color: Colors.black),
                label: const Text('Open Settings', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      body: Stack(
        children: [
          // ── Google Map View ──
          _currentLatLng == null
              ? Container(
                  color: const Color(0xFF131A2A),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: MPesaTheme.primaryGreen),
                        SizedBox(height: 16),
                        Text('Connecting to Google Maps & GPS…',
                            style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                )
              : GoogleMap(
                  mapType: _currentMapType,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (_currentMapType == MapType.normal) {
                      _mapController?.setMapStyle(MapMarkerHelper.darkMapStyle);
                    }
                  },
                  initialCameraPosition: CameraPosition(
                    target: _currentLatLng!,
                    zoom: 16.5,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  mapToolbarEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                ),

          // ── Floating Map & Route Controls ──
          Positioned(
            right: 16,
            top: 90,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF131A2A).withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      _currentMapType == MapType.satellite ? Icons.map : Icons.satellite_alt,
                      color: const Color(0xFF05D5AA),
                      size: 20,
                    ),
                    tooltip: 'Switch Map View',
                    onPressed: () {
                      setState(() {
                        if (_currentMapType == MapType.normal) {
                          _currentMapType = MapType.satellite;
                          _mapController?.setMapStyle(null);
                        } else {
                          _currentMapType = MapType.normal;
                          _mapController?.setMapStyle(MapMarkerHelper.darkMapStyle);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF131A2A).withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.my_location, color: MPesaTheme.primaryGreen, size: 20),
                    tooltip: 'Recenter on My Location',
                    onPressed: () {
                      if (_currentLatLng != null) {
                        _mapController?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
                          target: _currentLatLng!,
                          zoom: 17,
                        )));
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Top Navigation & Live Header ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF131A2A).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 16, offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _deliveryStage == 'en_route_pickup'
                                    ? 'Head to Cafeteria 🍔'
                                    : _deliveryStage == 'at_pickup'
                                        ? 'Pick Up Meal 📦'
                                        : 'Deliver to Hostel 🚪',
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              if (_isTracking)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: MPesaTheme.primaryGreen,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getDistanceAndEta(),
                            style: const TextStyle(color: MPesaTheme.primaryGreen, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    // External Google Maps Directions Button
                    ElevatedButton.icon(
                      onPressed: _openGoogleMapsNavigation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4285F4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.navigation, color: Colors.white, size: 16),
                      label: const Text('Maps', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom Order Details & Actions Card ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF131A2A),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: Colors.white12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.7), blurRadius: 30, offset: const Offset(0, -5))
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stage progress indicator
                    Row(
                      children: [
                        _buildStageDot('Cafeteria', _deliveryStage == 'en_route_pickup' || _deliveryStage == 'at_pickup'),
                        Expanded(child: Container(height: 2, color: (_deliveryStage == 'delivering' || _deliveryStage == 'arrived') ? MPesaTheme.primaryGreen : Colors.white24)),
                        _buildStageDot('In Transit', _deliveryStage == 'delivering'),
                        Expanded(child: Container(height: 2, color: _deliveryStage == 'arrived' ? MPesaTheme.primaryGreen : Colors.white24)),
                        _buildStageDot('Doorstep', _deliveryStage == 'arrived'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Customer and Payment summary
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _customerName,
                                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.verified, color: MPesaTheme.primaryGreen, size: 14),
                                  const SizedBox(width: 4),
                                  const Text('DISHI Escrow Secured', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Action buttons: Phone Call & WhatsApp
                        Row(
                          children: [
                            IconButton(
                              onPressed: _callCustomer,
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), shape: BoxShape.circle),
                                child: const Icon(Icons.phone, color: Colors.blue, size: 18),
                              ),
                            ),
                            IconButton(
                              onPressed: _whatsappCustomer,
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: const Color(0xFF25D366).withOpacity(0.2), shape: BoxShape.circle),
                                child: const Icon(Icons.chat, color: Color(0xFF25D366), size: 18),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 24),

                    // Route Summary
                    Row(
                      children: [
                        const Icon(Icons.storefront, color: Colors.orangeAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'From: $_pickupLocation',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: MPesaTheme.primaryGreen, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'To: $_dropoffLocation',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Primary Stage Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _deliveryStage == 'arrived'
                              ? MPesaTheme.primaryGreen
                              : const Color(0xFF38BDF8),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                        ),
                        onPressed: _advanceStage,
                        child: Text(
                          _deliveryStage == 'en_route_pickup'
                              ? 'I Have Arrived at Cafeteria 🏪'
                              : _deliveryStage == 'at_pickup'
                                  ? 'Meal Picked Up — Start Delivery 🛵'
                                  : _deliveryStage == 'delivering'
                                      ? 'Arrived at Student Hostel 🚪'
                                      : 'Confirm Handover & Complete (Release Escrow) 💰',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageDot(String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? MPesaTheme.primaryGreen : Colors.white24,
            border: Border.all(color: isActive ? Colors.white : Colors.transparent, width: 2),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? MPesaTheme.primaryGreen : Colors.white38,
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
