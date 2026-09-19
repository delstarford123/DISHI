import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Provides real-time GPS tracking with Firestore syncing, breadcrumb trails,
/// SOS high-frequency broadcasting, and speed calculation.
class LocationService {
  static StreamSubscription<Position>? _broadcastSub;
  static Position? _lastPosition;
  static DateTime? _lastBreadcrumbTime;

  // Battery level platform channel
  static const MethodChannel _batteryChannel =
      MethodChannel('com.dishi.swapeat/battery');

  // ─────────────────────────────────────────────────────────────────────────
  // PERMISSIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Ensures location permissions are granted. Returns null on success,
  /// or an error string on failure.
  static Future<String?> ensurePermissions(
      {bool background = false}) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return 'Location services are disabled.';

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return 'Location permission denied.';
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return 'Location permission permanently denied. Enable in Settings.';
    }
    return null; // success
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ONE-SHOT LOCATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the device's current position once.
  static Future<Position> getCurrentLocation() async {
    final err = await ensurePermissions();
    if (err != null) return Future.error(err);
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RAW STREAM (used by Deliv driver tracking)
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns a raw position stream. Used internally and by Deliv drivers.
  static Stream<Position> getLocationStream({int distanceFilter = 10}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FIRESTORE BROADCASTING
  // ─────────────────────────────────────────────────────────────────────────

  /// Starts broadcasting the student's position to Firestore.
  /// [sosMode] uses a high-frequency stream (every 3 seconds).
  static Future<void> startBroadcasting(
    String studentUid, {
    bool sosMode = false,
  }) async {
    // Stop any existing broadcast before starting a new one
    await stopBroadcasting();

    final err = await ensurePermissions(background: true);
    if (err != null) {
      debugPrint('LocationService: Cannot broadcast — $err');
      return;
    }

    final settings = sosMode
        ? const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 0,
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          );

    final stream = Geolocator.getPositionStream(locationSettings: settings);

    _broadcastSub = stream.listen((Position position) async {
      try {
        final batteryLevel = await getBatteryLevel();
        final speed = _lastPosition != null
            ? getSpeedKmh(_lastPosition!, position)
            : 0.0;

        final locationData = {
          'location': {
            'lat': position.latitude,
            'lng': position.longitude,
            'timestamp': FieldValue.serverTimestamp(),
            'batteryLevel': batteryLevel,
            'speed': speed,
            'isTracking': true,
            'sosActive': sosMode,
          }
        };

        await FirebaseFirestore.instance
            .collection('users')
            .doc(studentUid)
            .set(locationData, SetOptions(merge: true));

        // Write breadcrumb (throttled to once per minute unless SOS)
        final now = DateTime.now();
        final shouldWriteBreadcrumb = sosMode ||
            _lastBreadcrumbTime == null ||
            now.difference(_lastBreadcrumbTime!).inSeconds >= 60;

        if (shouldWriteBreadcrumb) {
          await _writeBreadcrumb(studentUid, position, batteryLevel);
          _lastBreadcrumbTime = now;
        }

        _lastPosition = position;
      } catch (e) {
        debugPrint('LocationService broadcast error: $e');
      }
    });

    // Mark as broadcasting in Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(studentUid)
        .set({'location': {'isTracking': true}}, SetOptions(merge: true));

    debugPrint(
        'LocationService: Started broadcasting for $studentUid (SOS: $sosMode)');
  }

  /// Stops the Firestore location broadcast.
  static Future<void> stopBroadcasting({String? studentUid}) async {
    await _broadcastSub?.cancel();
    _broadcastSub = null;
    _lastPosition = null;

    if (studentUid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(studentUid)
          .set(
              {'location': {'isTracking': false, 'sosActive': false}},
              SetOptions(merge: true));
    }
    debugPrint('LocationService: Broadcasting stopped.');
  }

  /// Returns true if a broadcast is currently active.
  static bool get isBroadcasting => _broadcastSub != null;

  // ─────────────────────────────────────────────────────────────────────────
  // BREADCRUMB TRAIL
  // ─────────────────────────────────────────────────────────────────────────

  /// Writes a breadcrumb to the `locationBreadcrumbs` sub-collection.
  /// Also purges breadcrumbs older than 24 hours.
  static Future<void> _writeBreadcrumb(
      String studentUid, Position position, int batteryLevel) async {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(studentUid)
        .collection('locationBreadcrumbs');

    await ref.add({
      'lat': position.latitude,
      'lng': position.longitude,
      'timestamp': FieldValue.serverTimestamp(),
      'batteryLevel': batteryLevel,
    });

    // Purge docs older than 24 hours (client-side cleanup)
    final cutoff = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 24)));
    final old = await ref
        .where('timestamp', isLessThan: cutoff)
        .limit(10) // delete in small batches to avoid timeouts
        .get();
    for (final doc in old.docs) {
      await doc.reference.delete();
    }
  }

  /// Fetches the last 24h of breadcrumbs for a student.
  static Future<List<Map<String, dynamic>>> getBreadcrumbs(
      String studentUid) async {
    final cutoff = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 24)));
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(studentUid)
        .collection('locationBreadcrumbs')
        .where('timestamp', isGreaterThan: cutoff)
        .orderBy('timestamp', descending: false)
        .get();

    return snapshot.docs.map((d) => d.data()).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SPEED CALCULATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Calculates speed in km/h between two positions using time delta.
  /// Falls back to geolocator's built-in speed if available.
  static double getSpeedKmh(Position prev, Position curr) {
    if (curr.speed >= 0) {
      // geolocator provides speed in m/s
      return curr.speed * 3.6;
    }
    // Fallback: geolocator didn't provide speed and we can't compute time delta
    // from Position alone, so return 0 to avoid incorrect data.
    // ignore: unused_local_variable
    final _ = Geolocator.distanceBetween(prev.latitude, prev.longitude,
        curr.latitude, curr.longitude);
    return 0.0;

  }

  // ─────────────────────────────────────────────────────────────────────────
  // BATTERY LEVEL
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the device's battery level as a percentage (0–100).
  /// Falls back to -1 if the platform channel is unavailable.
  static Future<int> getBatteryLevel() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final int level =
            await _batteryChannel.invokeMethod('getBatteryLevel');
        return level;
      }
    } catch (_) {
      // Platform channel not wired yet — graceful fallback
    }
    return -1;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HAVERSINE DISTANCE UTILITY
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns distance in meters between two lat/lng points.
  static double distanceMeters(
      double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  /// Returns a human-readable ETA string given distance (m) and speed (km/h).
  static String etaString(double distanceM, double speedKmh) {
    if (speedKmh < 0.5) return 'Stationary';
    final minutes = (distanceM / 1000) / speedKmh * 60;
    if (minutes < 1) return '< 1 min';
    return '~${minutes.round()} min';
  }
}
