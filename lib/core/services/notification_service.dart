import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../main.dart' show appNavigatorKey;
import '../../features/match/presentation/match_incoming_call_screen.dart';
import '../../features/match/presentation/match_call_view.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _notificationTapBackground,
    );

    // Create Android notification channels up-front (Android 8+)
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      // General DISHI alerts channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'dishi_alerts',
          'DISHI Alerts',
          description: 'General notifications from DISHI platform',
          importance: Importance.high,
        ),
      );

      // SOS-specific high-priority channel
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          'dishi_sos_alerts',
          'DISHI SOS Alerts',
          description: 'Emergency SOS alerts from linked students',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 250, 500, 250, 500]),
          ledColor: const Color(0xFFF92B60),
          enableLights: true,
        ),
      );

      // WhatsApp-Style Full-Screen Incoming Call Channel
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          'dishi_calls',
          'DISHI Incoming Calls',
          description: 'High-priority voice and video calls from comrades and merchants',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 1000, 1000, 1000, 1000]),
          ledColor: const Color(0xFF05D5AA),
          enableLights: true,
        ),
      );
    }
  }

  @pragma('vm:entry-point')
  static void _notificationTapBackground(NotificationResponse response) {
    debugPrint('[NotificationService] Background action tapped: ${response.actionId}');
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        final callId = data['callId'] ?? '';
        if (response.actionId == 'action_decline' && callId.isNotEmpty) {
          FirebaseFirestore.instance.collection('active_calls').doc(callId).update({
            'status': 'declined',
          });
        }
      } catch (_) {}
    }
  }

  static void _handleNotificationResponse(NotificationResponse response) {
    debugPrint('[NotificationService] Notification tapped: ${response.actionId}');
    if (response.payload == null) return;

    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      final type = data['type'] ?? '';

      if (type == 'incoming_call') {
        final callId = data['callId'] ?? '';
        final callerName = data['callerName'] ?? 'Comrade';
        final callerAvatar = data['callerAvatar'] ?? '';
        final isVideo = data['isVideo'] == true || data['isVideo'] == 'true';

        if (response.actionId == 'action_decline') {
          if (callId.isNotEmpty) {
            FirebaseFirestore.instance.collection('active_calls').doc(callId).update({
              'status': 'declined',
            });
          }
          _notificationsPlugin.cancel(callId.hashCode);
          return;
        }

        if (response.actionId == 'action_answer') {
          if (callId.isNotEmpty) {
            FirebaseFirestore.instance.collection('active_calls').doc(callId).update({
              'status': 'answered',
            });
          }
          _notificationsPlugin.cancel(callId.hashCode);
          appNavigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => MatchCallView(
                userName: callerName,
                userAvatar: callerAvatar,
                isVideoCall: isVideo,
                isIncoming: true,
                roomId: callId,
              ),
            ),
          );
          return;
        }

        // Tapped notification body -> open full-screen incoming call UI
        appNavigatorKey.currentState?.push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => MatchIncomingCallScreen(
              callId: callId,
              callerName: callerName,
              callerAvatar: callerAvatar,
              isVideoCall: isVideo,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[NotificationService] Error parsing payload: $e');
    }
  }

  /// Displays high-priority incoming call heads-up notification & lockscreen pop (WhatsApp style)
  static Future<void> showIncomingCallNotification({
    required int id,
    required String callId,
    required String callerName,
    required String callerAvatar,
    required bool isVideo,
  }) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'dishi_calls',
      'DISHI Incoming Calls',
      channelDescription: 'High-priority incoming call alerts',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      color: const Color(0xFF05D5AA),
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 800, 1000, 800]),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'action_answer',
          'Answer 📞',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'action_decline',
          'Decline ❌',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );

    final payload = jsonEncode({
      'type': 'incoming_call',
      'callId': callId,
      'callerName': callerName,
      'callerAvatar': callerAvatar,
      'isVideo': isVideo,
    });

    await _notificationsPlugin.show(
      id,
      'Incoming ${isVideo ? "Video" : "Voice"} Call',
      '$callerName is calling you on DISHI...',
      platformDetails,
      payload: payload,
    );
  }

  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Displays a general notification (POS Sales, Preorders, Chat).
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'dishi_alerts',
      'DISHI Alerts',
      importance: Importance.max,
      priority: Priority.high,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(id, title, body, platformDetails,
        payload: payload);
  }

  /// Displays a high-priority SOS notification.
  static Future<void> showSosNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'dishi_sos_alerts',
      'DISHI SOS Alerts',
      importance: Importance.max,
      priority: Priority.max,
      color: Color(0xFFF92B60),
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.critical,
      ),
    );

    await _notificationsPlugin.show(id, title, body, platformDetails,
        payload: payload);
  }
}
