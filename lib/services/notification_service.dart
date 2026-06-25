import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();
  
  static String? pendingRoute;

  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload == 'alerts') {
          navigatorKey.currentState?.pushNamed('alerts');
        } else if (response.payload == 'dashboard') {
          navigatorKey.currentState?.pushNamed('dashboard');
        }
      },
    );
    
    // Request permissions for Android 13+
    await notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'sentriq_zone_alerts_v3',
      'Sentriq Zone Alerts',
      channelDescription: 'Notifications when friends enter or leave zones',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      color: Color(0xFFFF0000), // Red color as in native snippet
      enableLights: true,
      enableVibration: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );

    await notifications.show(
      DateTime.now().millisecondsSinceEpoch % 1000000, // More unique ID
      title,
      body,
      const NotificationDetails(
        android: androidDetails,
      ),
      payload: 'alerts',
    );
  }

  static Future<void> cancelAll() async {
    await notifications.cancelAll();
  }
}
