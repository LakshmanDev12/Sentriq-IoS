import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';

// Screens
import 'screen/splash_screen.dart';
import 'screen/login_screen.dart';
import 'screen/dashboard_screen.dart';
import 'screen/register_screen.dart';
import 'screen/forgot_request_screen.dart';
import 'screen/search_friends_screen.dart';
import 'screen/friends_screen.dart';
import 'screen/friend_request_screen.dart';
import 'screen/alert_screen.dart';
import 'screen/track_friend_screen.dart';
import 'screen/my_zones_screen.dart';
import 'screen/create_zone_screen.dart';
import 'screen/mark_zone_screen.dart';

// Models
import 'models/zone.dart';

// Services
import 'services/background_location_service.dart';
import 'services/notification_service.dart';
import 'services/foreground_notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Firebase must be ready before the app starts.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    debugPrint('Firebase initialized successfully');
  } catch (e, stackTrace) {
    debugPrint('Firebase initialization error: $e');
    debugPrintStack(stackTrace: stackTrace);
  }

  // Start the UI immediately.
  runApp(const SentriqApp());

  // Initialize additional services without blocking the UI.
  initializeAppServices();
}

Future<void> initializeAppServices() async {
  // --------------------------------------------------
  // Background Location Service
  // --------------------------------------------------

  try {
    await BackgroundLocationService.initializeService();

    debugPrint(
      'Background location service initialized successfully',
    );
  } catch (e, stackTrace) {
    debugPrint(
      'Background location service error: $e',
    );

    debugPrintStack(
      stackTrace: stackTrace,
    );
  }

  // --------------------------------------------------
  // Notification Service
  // --------------------------------------------------

  try {
    await NotificationService.init();

    debugPrint(
      'Notification service initialized successfully',
    );

    final notificationDetails =
        await NotificationService.notifications
            .getNotificationAppLaunchDetails();

    if (notificationDetails?.didNotificationLaunchApp ??
        false) {
      NotificationService.pendingRoute =
          notificationDetails
              ?.notificationResponse
              ?.payload;

      debugPrint(
        'Notification route: '
        '${NotificationService.pendingRoute}',
      );
    }
  } catch (e, stackTrace) {
    debugPrint(
      'Notification initialization error: $e',
    );

    debugPrintStack(
      stackTrace: stackTrace,
    );
  }

  // --------------------------------------------------
  // Firebase Authentication Listener
  // --------------------------------------------------

  FirebaseAuth.instance.authStateChanges().listen(
    (User? user) {
      try {
        if (user != null) {
          debugPrint(
            'User logged in: ${user.uid}',
          );

          ForegroundNotificationService.startListening();
        } else {
          debugPrint('User logged out');

          ForegroundNotificationService.stopListening();
        }
      } catch (e, stackTrace) {
        debugPrint(
          'Foreground notification service error: $e',
        );

        debugPrintStack(
          stackTrace: stackTrace,
        );
      }
    },
    onError: (error) {
      debugPrint(
        'Authentication listener error: $error',
      );
    },
  );
}

// ======================================================
// SENTRIQ APPLICATION
// ======================================================

class SentriqApp extends StatelessWidget {
  const SentriqApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,

      debugShowCheckedModeBanner: false,

      title: 'Sentriq',

      // ------------------------------------------------
      // Application Theme
      // ------------------------------------------------

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(
            0xFF7F77DD,
          ),
        ),
        useMaterial3: true,
      ),

      // ------------------------------------------------
      // Initial Screen
      // ------------------------------------------------

      home: const SplashScreen(),

      // ------------------------------------------------
      // Named Routes
      // ------------------------------------------------

      routes: {
        'login': (context) =>
            const LoginScreen(),

        'dashboard': (context) =>
            const DashboardScreen(),

        'register': (context) =>
            const RegisterScreen(),

        'forgot_password': (context) =>
            const ForgotRequestScreen(),

        'search_friends': (context) =>
            const SearchFriendsScreen(),

        'friends': (context) =>
            const FriendsScreen(),

        'friend_requests': (context) =>
            const FriendRequestScreen(),

        'alerts': (context) =>
            const AlertScreen(),

        'map': (context) =>
            const TrackFriendScreen(),

        'zones': (context) =>
            const MyZonesScreen(),

        'my_zones': (context) =>
            const MyZonesScreen(),

        'create_zone': (context) =>
            const CreateZoneScreen(),
      },

      // ------------------------------------------------
      // Dynamic Routes
      // ------------------------------------------------

      onGenerateRoute: (RouteSettings settings) {
        if (settings.name == 'mark_zone') {
          final arguments = settings.arguments;

          if (arguments is Zone) {
            return MaterialPageRoute(
              builder: (context) {
                return MarkZoneScreen(
                  zone: arguments,
                );
              },
            );
          }

          debugPrint(
            'Invalid arguments supplied to mark_zone route',
          );
        }

        return null;
      },

      // ------------------------------------------------
      // Unknown Route Handler
      // ------------------------------------------------

      onUnknownRoute: (settings) {
        debugPrint(
          'Unknown route: ${settings.name}',
        );

        return MaterialPageRoute(
          builder: (context) =>
              const SplashScreen(),
        );
      },
    );
  }
}