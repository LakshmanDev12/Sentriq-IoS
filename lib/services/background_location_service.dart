import 'dart:async';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import '../firebase_options.dart';
import '../models/zone.dart';
import '../utils/constants.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  if (notificationResponse.actionId == 'stop_sharing') {
    // Initialize Firebase in this new isolate
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Update database state
      await FirebaseDatabase.instance
          .ref(AppConstants.users)
          .child(user.uid)
          .update({"isSharing": false});

      // Signal the service to stop
      FlutterBackgroundService().invoke('stopService');
      
      // Also clear all other notifications
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.cancelAll();
    }
  }
}

class BackgroundLocationService {
  static const String notificationChannelId = 'sentriq_location_channel';
  static const int notificationId = 888;

  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'Sentriq Location Service',
      description: 'This channel is used for live location sharing.',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Sentriq',
        initialNotificationContent: 'Live Sharing Enabled',
        foregroundServiceNotificationId: notificationId,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    // Initialize Firebase in the background isolate
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Notification Service for the background isolate
    await NotificationService.init();

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    // Initialize local notifications in the background isolate to handle action buttons
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Show initial notification with "Stop Sharing" button immediately
    _showLiveNotification(flutterLocalNotificationsPlugin);

    service.on('stopService').listen((event) {
      flutterLocalNotificationsPlugin.cancelAll();
      service.stopSelf();
    });

    Timer.periodic(const Duration(seconds: 10), (timer) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("BG SERVICE: User is NULL, skipping loop.");
        return;
      }

      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          _showLiveNotification(flutterLocalNotificationsPlugin);
        }
      }

      // Check if user is still sharing
      final snapshot = await FirebaseDatabase.instance
          .ref(AppConstants.users)
          .child(user.uid)
          .child("isSharing")
          .get();
      
      final bool isSharing = snapshot.value as bool? ?? false;
      print("BG SERVICE: User ${user.uid} isSharing: $isSharing");

      if (!isSharing) {
        print("BG SERVICE: Sharing turned off, stopping service.");
        flutterLocalNotificationsPlugin.cancelAll();
        service.stopSelf();
        return;
      }

      if (isSharing) {
        try {
          Position position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          print("BG SERVICE: Got position: ${position.latitude}, ${position.longitude}");

          await FirebaseDatabase.instance.ref(AppConstants.users).child(user.uid).update({
            "latitude": position.latitude,
            "longitude": position.longitude,
            "lastUpdated": DateTime.now().millisecondsSinceEpoch,
          });

          // Zone Detection Logic
          // New structure: /zones/$friendUid/ (where friendUid is user.uid)
          final zonesSnapshot = await FirebaseDatabase.instance
              .ref(AppConstants.zones)
              .child(user.uid)
              .get();

          if (zonesSnapshot.exists) {
            final Map<dynamic, dynamic> zonesData = zonesSnapshot.value as Map<dynamic, dynamic>;
            print("BG SERVICE: Checking ${zonesData.length} zones for current user.");
            
            final userSnapshot = await FirebaseDatabase.instance.ref(AppConstants.users).child(user.uid).get();
            final String userAddress = userSnapshot.child("address").value?.toString() ?? "Unknown Location";

            for (var entry in zonesData.entries) {
              final zone = Zone.fromMap({...entry.value as Map, 'zoneId': entry.key});
              
              double distance = Geolocator.distanceBetween(
                position.latitude,
                position.longitude,
                zone.latitude,
                zone.longitude,
              );

              bool isInside = distance <= zone.radius;
              String currentStatus = isInside ? "INSIDE" : "OUTSIDE";
              print("BG SERVICE: Zone ${zone.name}, distance: ${distance.toStringAsFixed(1)}m, radius: ${zone.radius}m, status: $currentStatus (DB status: ${zone.status})");

              if (currentStatus != zone.status) {
                print("BG SERVICE: STATUS CHANGE DETECTED for zone ${zone.name}. New status: $currentStatus");
                // Update Zone Status - New structure: /zones/$friendUid/$zoneId
                await FirebaseDatabase.instance
                    .ref(AppConstants.zones)
                    .child(user.uid)
                    .child(zone.zoneId)
                    .update({"status": currentStatus});

                // Update User Status
                await FirebaseDatabase.instance
                    .ref(AppConstants.users)
                    .child(user.uid)
                    .update({"zoneStatus": currentStatus});

                // Create Alert for the OWNER of the zone
                final String ownerUid = zone.ownerUid;
                final alertRef = FirebaseDatabase.instance
                    .ref(AppConstants.alerts)
                    .child(ownerUid)
                    .push();
                
                print("BG SERVICE: Sending alert to owner: $ownerUid for friend: ${user.uid}");

                await alertRef.set({
                  "alertId": alertRef.key,
                  "userId": user.uid,
                  "zoneName": zone.name,
                  "userName": zone.friendName,
                  "type": isInside ? "Entered" : "Exited",
                  "timestamp": DateTime.now().millisecondsSinceEpoch,
                  "address": userAddress,
                });
                print("BG SERVICE: Alert created at node alerts/$ownerUid/${alertRef.key}");

                // Trigger Local Notification for the user who crossed (Feedback)
                await NotificationService.showNotification(
                  title: isInside ? "📍 Safe Zone Entered" : "⚠️ Safe Zone Exited",
                  body: "You ${isInside ? "has arrived at" : "has left"} ${zone.name}",
                );
              }
            }
          } else {
            print("BG SERVICE: No zones found in /zones/${user.uid}");
          }
        } catch (e) {
          print("BG SERVICE ERROR: $e");
        }
      }
    });
  }

  static void _showLiveNotification(FlutterLocalNotificationsPlugin plugin) {
    plugin.show(
      notificationId,
      'Sentriq',
      'Live Sharing Enabled',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          notificationChannelId,
          'Sentriq Location Service',
          icon: '@mipmap/ic_launcher',
          ongoing: true,
          importance: Importance.low,
          priority: Priority.low,
          showWhen: false,
          actions: [
            AndroidNotificationAction(
              'stop_sharing',
              'Stop Sharing',
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ],
        ),
      ),
      payload: 'dashboard',
    );
  }
}
