import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/mpesa_theme.dart';

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
  bool _isTracking = false;
  bool _permissionDenied = false;
  final String _driverUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  static const _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10, // update every 10m
  );

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapController?.dispose();
    super.dispose();
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

    _positionStream =
        Geolocator.getPositionStream(locationSettings: _locationSettings)
            .listen((Position pos) async {
      final latLng = LatLng(pos.latitude, pos.longitude);

      // Update Firestore driver location
      try {
        await FirebaseFirestore.instance
            .collection('deliv_drivers')
            .doc(_driverUid)
            .set({
          'location': GeoPoint(pos.latitude, pos.longitude),
          'lastUpdated': FieldValue.serverTimestamp(),
          'isOnline': true,
        }, SetOptions(merge: true));

        // Also update the active ride if rideId provided
        if (widget.rideId != null) {
          await FirebaseFirestore.instance
              .collection('deliv_rides')
              .doc(widget.rideId)
              .update({
            'driver_location': GeoPoint(pos.latitude, pos.longitude),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _currentLatLng = latLng;
          _markers
            ..removeWhere((m) => m.markerId.value == 'driver')
            ..add(Marker(
              markerId: const MarkerId('driver'),
              position: latLng,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen),
              infoWindow: const InfoWindow(title: 'Your Location'),
            ));
        });
        _mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
      }
    });
  }

  Future<void> _finishGig() async {
    _positionStream?.cancel();
    // Mark driver offline
    try {
      await FirebaseFirestore.instance
          .collection('deliv_drivers')
          .doc(_driverUid)
          .update({'isOnline': false, 'lastUpdated': FieldValue.serverTimestamp()});
      if (widget.rideId != null) {
        await FirebaseFirestore.instance
            .collection('deliv_rides')
            .doc(widget.rideId)
            .update({'status': 'completed', 'completedAt': FieldValue.serverTimestamp()});
      }
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return Scaffold(
        backgroundColor: const Color(0xFF0C101B),
        appBar: AppBar(
          title: const Text('Live Tracker',
              style: TextStyle(color: Colors.white)),
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
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Enable location in your device settings\nto use the live tracker.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  await Geolocator.openAppSettings();
                },
                icon: const Icon(Icons.settings),
                label: const Text('Open Settings'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: MPesaTheme.primaryGreen),
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
          // Map — shows placeholder until GPS is ready
          _currentLatLng == null
              ? Container(
                  color: const Color(0xFF1A2235),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: MPesaTheme.primaryGreen),
                        SizedBox(height: 16),
                        Text('Getting your location…',
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                )
              : GoogleMap(
                  onMapCreated: (c) => _mapController = c,
                  initialCameraPosition: CameraPosition(
                    target: _currentLatLng!,
                    zoom: 16,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  mapToolbarEnabled: false,
                  zoomControlsEnabled: false,
                ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF131A2A).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Live Tracker',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          Text('Location streaming to Firestore',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isTracking
                            ? MPesaTheme.primaryGreen.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isTracking
                                  ? MPesaTheme.primaryGreen
                                  : Colors.red,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isTracking ? 'LIVE' : 'OFF',
                            style: TextStyle(
                                color: _isTracking
                                    ? MPesaTheme.primaryGreen
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom finish button
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: ElevatedButton.icon(
              onPressed: _finishGig,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16))),
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: const Text('Finish Gig',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
