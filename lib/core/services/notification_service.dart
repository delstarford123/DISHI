import 'dart:typed_data';
import 'dart:ui' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';


class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initSettings);

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
    }
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

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(id, title, body, platformDetails,
        payload: payload);
  }

  /// Displays a high-priority SOS notification with red icon, max sound/vibration.
  /// Used specifically when a student triggers the emergency SOS button.
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
      fullScreenIntent: true, // Pop over lock screen on Android
    );

    const NotificationDetails platformDetails = NotificationDetails(
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
