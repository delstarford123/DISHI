import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'notification_service.dart';

/// Handles all geofence math, proximity alerts, and location-based reminders.
class GeofenceService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────────────────
  // HAVERSINE MATH
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the great-circle distance in meters between two lat/lng points.
  static double haversineMeters(
      double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0; // Earth radius in metres
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final dPhi = (lat2 - lat1) * math.pi / 180;
    final dLambda = (lng2 - lng1) * math.pi / 180;

    final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(dLambda / 2) *
            math.sin(dLambda / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  /// Returns true if a point is inside a circular geofence.
  static bool isInsideCircle(
    double lat,
    double lng,
    double centerLat,
    double centerLng,
    double radiusMeters,
  ) {
    return haversineMeters(lat, lng, centerLat, centerLng) <= radiusMeters;
  }

  /// Returns true if a point is inside a polygon (ray-casting algorithm).
  static bool isInsidePolygon(
      double lat, double lng, List<Map<String, double>> polygon) {
    int intersections = 0;
    final n = polygon.length;
    for (int i = 0; i < n; i++) {
      final j = (i + 1) % n;
      final xi = polygon[i]['lat']!;
      final yi = polygon[i]['lng']!;
      final xj = polygon[j]['lat']!;
      final yj = polygon[j]['lng']!;

      if (((yi > lng) != (yj > lng)) &&
          (lat < (xj - xi) * (lng - yi) / (yj - yi) + xi)) {
        intersections++;
      }
    }
    return intersections.isOdd;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PARENT GEOFENCE CHECKING
  // ─────────────────────────────────────────────────────────────────────────

  // Tracks which zones the student was last known to be inside
  static final Map<String, bool> _lastGeofenceState = {};

  /// Checks all parent-defined geofences for [studentUid] against [position].
  /// Triggers a push notification to the parent's device when the student
  /// exits a zone.
  static Future<void> checkParentGeofences(
    String studentUid,
    Position position,
  ) async {
    try {
      // Find which parents have this student linked
      final parentQuery = await _db
          .collection('users')
          .where('role', isEqualTo: 'parent')
          .where('linkedStudents', arrayContains: studentUid)
          .get();

      for (final parentDoc in parentQuery.docs) {
        final parentUid = parentDoc.id;
        final zonesSnap = await _db
            .collection('geofences')
            .doc(parentUid)
            .collection('zones')
            .where('studentUid', isEqualTo: studentUid)
            .get();

        for (final zoneDoc in zonesSnap.docs) {
          final data = zoneDoc.data();
          final zoneId = zoneDoc.id;
          final centerLat = (data['centerLat'] as num).toDouble();
          final centerLng = (data['centerLng'] as num).toDouble();
          final radiusM = (data['radiusMeters'] as num).toDouble();
          final zoneName = data['name'] as String? ?? 'Safe Zone';

          final isInside = isInsideCircle(
            position.latitude,
            position.longitude,
            centerLat,
            centerLng,
            radiusM,
          );

          final stateKey = '${parentUid}_$zoneId';
          final wasInside = _lastGeofenceState[stateKey] ?? true;

          if (wasInside && !isInside) {
            // Student just exited the zone
            debugPrint(
                'GeofenceService: Student $studentUid exited zone "$zoneName"');
            await _notifyParentGeofenceBreach(
                parentDoc.data(), zoneName, studentUid);
          }

          _lastGeofenceState[stateKey] = isInside;
        }
      }
    } catch (e) {
      debugPrint('GeofenceService.checkParentGeofences error: $e');
    }
  }

  static Future<void> _notifyParentGeofenceBreach(
    Map<String, dynamic> parentData,
    String zoneName,
    String studentUid,
  ) async {
    // Local notification on the student's device (SOS-style alert)
    await NotificationService.showNotification(
      id: studentUid.hashCode,
      title: '📍 Geofence Alert',
      body: 'You have left "$zoneName". Your parent has been notified.',
    );

    // Write a Firestore alert so the parent's StreamBuilder picks it up
    await _db
        .collection('users')
        .doc(parentData['uid'] as String? ?? '')
        .collection('geofence_alerts')
        .add({
      'studentUid': studentUid,
      'zoneName': zoneName,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOCATION-BASED REMINDERS
  // ─────────────────────────────────────────────────────────────────────────

  static final Set<String> _firedReminders = {};

  /// Checks all active location reminders for [uid] against [position].
  /// Fires a local notification when the student enters the trigger radius.
  static Future<void> checkProximityReminders(
    String uid,
    Position position,
  ) async {
    try {
      final remindersSnap = await _db
          .collection('location_reminders')
          .doc(uid)
          .collection('reminders')
          .where('active', isEqualTo: true)
          .get();

      for (final doc in remindersSnap.docs) {
        final data = doc.data();
        final reminderId = doc.id;
        if (_firedReminders.contains(reminderId)) continue;

        final triggerLat = (data['triggerLat'] as num).toDouble();
        final triggerLng = (data['triggerLng'] as num).toDouble();
        final radiusM = (data['radiusMeters'] as num).toDouble();
        final message = data['message'] as String? ?? 'Reminder';

        if (isInsideCircle(
          position.latitude,
          position.longitude,
          triggerLat,
          triggerLng,
          radiusM,
        )) {
          await NotificationService.showNotification(
            id: reminderId.hashCode,
            title: '📍 Location Reminder',
            body: message,
          );
          _firedReminders.add(reminderId);
          // Mark reminder as triggered in Firestore
          await doc.reference.update({'active': false});
        }
      }
    } catch (e) {
      debugPrint('GeofenceService.checkProximityReminders error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MEETUP PROXIMITY ALERTS
  // ─────────────────────────────────────────────────────────────────────────

  static const double _meetupProximityMeters = 100.0;
  static final Set<String> _notifiedMeetupPeers = {};

  /// Checks if any mutual connections are within [_meetupProximityMeters] of
  /// [position]. Fires a local notification once per session per peer.
  static Future<void> checkMeetupProximity(
    String uid,
    Position position,
  ) async {
    try {
      // Get mutual connections (uses existing match feature data structure)
      final connectionsSnap = await _db
          .collection('match_connections')
          .where('participants', arrayContains: uid)
          .get();

      for (final connDoc in connectionsSnap.docs) {
        final data = connDoc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        final peerUid = participants.firstWhere((p) => p != uid,
            orElse: () => '');
        if (peerUid.isEmpty) continue;
        if (_notifiedMeetupPeers.contains(peerUid)) continue;

        // Check if proximity sharing is enabled for this peer
        final peerDoc = await _db.collection('users').doc(peerUid).get();
        if (!peerDoc.exists) continue;
        final peerData = peerDoc.data()!;

        if (!(peerData['proximityAlertsEnabled'] ?? false)) continue;

        final peerLoc = peerData['location'] as Map<String, dynamic>?;
        if (peerLoc == null) continue;

        final peerLat = (peerLoc['lat'] as num?)?.toDouble();
        final peerLng = (peerLoc['lng'] as num?)?.toDouble();
        if (peerLat == null || peerLng == null) continue;

        // Check if peer location is recent (within 5 minutes)
        final peerTimestamp = peerLoc['timestamp'] as Timestamp?;
        if (peerTimestamp != null) {
          final age = DateTime.now().difference(peerTimestamp.toDate());
          if (age.inMinutes > 5) continue;
        }

        final distance = haversineMeters(
            position.latitude, position.longitude, peerLat, peerLng);

        if (distance <= _meetupProximityMeters) {
          final peerName = peerData['name'] as String? ?? 'Someone';
          await NotificationService.showNotification(
            id: peerUid.hashCode,
            title: '👋 Study Buddy Nearby!',
            body: '$peerName is within 100m of you on campus.',
          );
          _notifiedMeetupPeers.add(peerUid);
        }
      }
    } catch (e) {
      debugPrint('GeofenceService.checkMeetupProximity error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DANGER ZONE CHECKING
  // ─────────────────────────────────────────────────────────────────────────

  static final Set<String> _notifiedDangerZones = {};

  /// Checks if [position] is inside any Firestore-configured danger zone.
  /// Zones are stored in `danger_zones/{zoneId}` as polygon vertex arrays.
  static Future<bool> checkDangerZones(Position position) async {
    try {
      final zonesSnap = await _db.collection('danger_zones').get();
      for (final doc in zonesSnap.docs) {
        final data = doc.data();
        final zoneId = doc.id;
              final zoneName = data['name'] as String? ?? 'Restricted Area';
              final _ = zoneName; // acknowledged: used only in future push notification
        final vertices = (data['polygon'] as List<dynamic>? ?? [])
            .map((v) => {
                  'lat': (v['lat'] as num).toDouble(),
                  'lng': (v['lng'] as num).toDouble(),
                })
            .toList();

        if (vertices.length < 3) continue;

        if (isInsidePolygon(
            position.latitude, position.longitude, vertices)) {
          if (!_notifiedDangerZones.contains(zoneId)) {
            _notifiedDangerZones.add(zoneId);
            return true; // caller should show the warning dialog
          }
        } else {
          _notifiedDangerZones.remove(zoneId);
        }
      }
    } catch (e) {
      debugPrint('GeofenceService.checkDangerZones error: $e');
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MEETUP SHARE
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates a 30-minute temporary meetup share session.
  /// Returns the share document ID.
  static Future<String> createMeetupShare(
      String studentUid, String targetUid, Position position) async {
    final expiresAt =
        Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 30)));
    final doc = await _db.collection('meetup_shares').add({
      'studentUid': studentUid,
      'targetUid': targetUid,
      'lat': position.latitude,
      'lng': position.longitude,
      'expiresAt': expiresAt,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Updates the live position in an existing meetup share document.
  static Future<void> updateMeetupShare(
      String shareId, Position position) async {
    await _db.collection('meetup_shares').doc(shareId).update({
      'lat': position.latitude,
      'lng': position.longitude,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes an expired or cancelled meetup share.
  static Future<void> cancelMeetupShare(String shareId) async {
    await _db.collection('meetup_shares').doc(shareId).delete();
  }

  /// Checks if a meetup share is still valid (not expired).
  static bool isMeetupShareValid(Map<String, dynamic> shareData) {
    final expiresAt = shareData['expiresAt'] as Timestamp?;
    if (expiresAt == null) return false;
    return expiresAt.toDate().isAfter(DateTime.now());
  }
}
