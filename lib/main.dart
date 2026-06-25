import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
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
import 'models/zone.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/background_location_service.dart';
import 'services/notification_service.dart';
import 'services/foreground_notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await BackgroundLocationService.initializeService();
  await NotificationService.init();
  
  // Listen for auth state changes to start/stop the foreground alert listener
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      ForegroundNotificationService.startListening();
    } else {
      ForegroundNotificationService.stopListening();
    }
  });

  // Handle notification launch when the app is terminated
  final notificationDetails = await NotificationService.notifications.getNotificationAppLaunchDetails();
  if (notificationDetails?.didNotificationLaunchApp ?? false) {
    NotificationService.pendingRoute = notificationDetails?.notificationResponse?.payload;
  }

  runApp(const SentriqApp());
}

class SentriqApp extends StatelessWidget {
  const SentriqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Sentriq',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7F77DD),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        'login': (context) => const LoginScreen(),
        'dashboard': (context) => const DashboardScreen(),
        'register': (context) => const RegisterScreen(),
        'forgot_password': (context) => const ForgotRequestScreen(),
        'search_friends': (context) => const SearchFriendsScreen(),
        'friends': (context) => const FriendsScreen(),
        'friend_requests': (context) => const FriendRequestScreen(),
        'alerts': (context) => const AlertScreen(),
        'map': (context) => const TrackFriendScreen(),
        'zones': (context) => const MyZonesScreen(),
        'my_zones': (context) => const MyZonesScreen(),
        'create_zone': (context) => const CreateZoneScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == 'mark_zone') {
          final zone = settings.arguments as Zone;
          return MaterialPageRoute(
            builder: (context) => MarkZoneScreen(zone: zone),
          );
        }
        return null;
      },
    );
  }
}
