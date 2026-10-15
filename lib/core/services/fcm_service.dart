import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'notification_service.dart';
import 'api_config.dart';

/// Callback type for handling FCM notification taps that require navigation.
/// Register this in your root widget/scaffold to react to taps.
typedef FcmTapCallback = void Function(RemoteMessage message);

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Optional callback invoked when user taps an FCM notification.
  static FcmTapCallback? onNotificationTap;

  static Future<void> initialize() async {
    try {
      // 0. Ensure local notification channels and plugins are initialized
      await NotificationService.initialize();

      // 1. Request permissions (required for iOS and Android 13+)
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true, // iOS critical alerts (SOS)
        provisional: false,
      );

      // Set foreground notification presentation for iOS
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('FCMService: User explicitly denied notification permission');
      } else {
        debugPrint('FCMService: Notification permission granted (${settings.authorizationStatus})');
      }

      // 2. Sync token for current user
      await syncToken();

      // 3. Token refresh listener
      _messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('FCM Token refreshed: $newToken');
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({'fcmToken': newToken, 'tokenUpdatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
            debugPrint('FCM Token updated in Firestore for ${user.uid}');
          } catch (e) {
            debugPrint('Failed to save refreshed token: $e');
          }
        }
      });

      // 4. Foreground messages listener (handles both notification & data-only payloads)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM foreground message received: ${message.data}');
        
        final title = message.notification?.title ?? 
                      message.data['title'] ?? 
                      (message.data['type'] == 'sos_alert' ? '🚨 SOS Alert' : 'DISHI Alert');
        final body = message.notification?.body ?? 
                     message.data['body'] ?? 
                     message.data['message'] ?? 
                     message.data['content'] ?? 
                     '';

        if (title.isNotEmpty || body.isNotEmpty) {
          final isSos = message.data['type'] == 'sos_alert' || 
                        message.data['alert_type'] == 'sos' ||
                        (message.notification?.title?.contains('SOS') ?? false);

          if (isSos) {
            NotificationService.showSosNotification(
              id: message.hashCode,
              title: title,
              body: body,
              payload: jsonEncode(message.data),
            );
          } else {
            NotificationService.showNotification(
              id: message.hashCode,
              title: title,
              body: body,
              payload: jsonEncode(message.data),
            );
          }
        }
      });

      // 5. Background tap: app was in background, user tapped notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM notification tapped (background): ${message.data}');
        onNotificationTap?.call(message);
      });

      // 6. Terminated state tap: app launched from a notification
      final RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('FCM launched from terminated state: ${initialMessage.data}');
        Future.delayed(const Duration(seconds: 1), () {
          onNotificationTap?.call(initialMessage);
        });
      }
    } catch (e) {
      debugPrint('FCMService initialization error: $e');
    }
  }

  /// Syncs current device's FCM token to Firestore for the logged-in user.
  static Future<void> syncToken([String? explicitUid]) async {
    try {
      final uid = explicitUid ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('FCMService.syncToken: $token for $uid');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({
              'fcmToken': token,
              'tokenUpdatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('FCMService.syncToken error: $e');
    }
  }

  // ─── SOS Helpers ──────────────────────────────────────────────────────────

  /// Called from the student dashboard when SOS is activated.
  /// Posts to the backend which sends FCM to all linked parents.
  /// Returns the Firestore alert_id on success, or null on failure.
  static Future<String?> sendSOSToParents({
    required String studentUid,
    required String studentName,
    double? lat,
    double? lng,
    String? existingAlertId,
  }) async {
    try {
      final body = jsonEncode({
        'student_uid':  studentUid,
        'student_name': studentName,
        'lat':          lat,
        'lng':          lng,
        if (existingAlertId != null && existingAlertId.isNotEmpty)
          'alert_id': existingAlertId,
      });

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/v1/notify/sos'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint(
            'SOS FCM sent to ${data['fcm_sent']} / ${data['parents_count']} parents');
        return data['alert_id'] as String?;
      } else {
        debugPrint('SOS backend error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('FCMService.sendSOSToParents failed: $e');
      return null;
    }
  }

  /// Called from the student dashboard when SOS is deactivated.
  static Future<void> sendSOSResolved({
    required String studentUid,
    required String studentName,
    String? alertId,
  }) async {
    try {
      final body = jsonEncode({
        'student_uid':  studentUid,
        'student_name': studentName,
        if (alertId != null && alertId.isNotEmpty) 'alert_id': alertId,
      });

      await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/v1/notify/sos/resolve'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('FCMService.sendSOSResolved failed: $e');
    }
  }

  // ─── Topic Helpers ─────────────────────────────────────────────────────────

  /// Subscribes the user to a topic (e.g. 'vendors_nairobi', 'driver_alerts').
  static Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}
