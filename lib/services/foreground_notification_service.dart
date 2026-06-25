import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../utils/constants.dart';
import 'notification_service.dart';

class ForegroundNotificationService {
  static StreamSubscription? _subscription;
  static bool _isFirstLoad = true;

  static void startListening() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Cancel existing subscription if any
    stopListening();

    _isFirstLoad = true;

    _subscription = FirebaseDatabase.instance
        .ref(AppConstants.alerts)
        .child(user.uid)
        .onChildAdded
        .listen((event) {
      if (_isFirstLoad) {
        // Skip historic data on first load
        return;
      }

      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final String userName = data['userName']?.toString() ?? "Someone";
        final String type = (data['type']?.toString() ?? "").toUpperCase();
        final String zoneName = data['zoneName']?.toString() ?? "a zone";

        final bool isEntered = type == "ENTERED";
        final String title = isEntered ? "📍 Safe Zone Entered" : "⚠️ Safe Zone Exited";
        final String body = "$userName ${isEntered ? "has arrived at" : "has left"} $zoneName";
        print("FOREGROUND ALERT: $body");

        NotificationService.showNotification(
          title: title,
          body: body,
        );
      }
    }, onError: (e) {
      print("FOREGROUND ALERT ERROR: $e");
    });

    // Mark first load as finished after a short delay
    // This is a simple way to ignore all existing children when the listener starts
    Future.delayed(const Duration(seconds: 2), () {
      _isFirstLoad = false;
    });
  }

  static void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }
}
