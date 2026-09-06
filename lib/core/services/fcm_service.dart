import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    // 1. Request permissions (especially needed for iOS)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('FCMService: User granted permission');
    } else {
      debugPrint('FCMService: User declined or has not accepted permission');
      return;
    }

    // 2. Get the token
    final String? token = await _messaging.getToken();
    debugPrint('FCM Token: $token');
    
    // Save to Firestore if user is logged in
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && token != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).set(
          {'fcmToken': token},
          SetOptions(merge: true),
        );
        debugPrint('FCM Token saved to Firestore for user: ${currentUser.uid}');
      } catch (e) {
        debugPrint('Failed to save FCM token: $e');
      }
    }

    // 3. Handle messages while app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: \${message.data}');

      if (message.notification != null) {
        NotificationService.showNotification(
          id: message.hashCode,
          title: message.notification!.title ?? 'New Alert',
          body: message.notification!.body ?? '',
        );
      }
    });
  }

  /// Subscribes the user to a topic (e.g. 'vendors_nairobi', 'driver_alerts')
  static Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}
