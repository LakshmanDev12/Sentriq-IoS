import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/guardian_logo.dart';
import '../services/notification_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  void _navigateToNext() async {
    // Wait for the logo animation to finish (approx 3.5s in AnimatedGuardianLogo)
    // plus some extra time for a better feel
    await Future.delayed(const Duration(milliseconds: 4000));
    
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (NotificationService.pendingRoute != null) {
        String route = NotificationService.pendingRoute!;
        NotificationService.pendingRoute = null; // Clear it
        Navigator.pushReplacementNamed(context, route);
      } else {
        Navigator.pushReplacementNamed(context, 'dashboard');
      }
    } else {
      Navigator.pushReplacementNamed(context, 'login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          const Center(
            child: AnimatedGuardianLogo(size: 150, showWordmark: true),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "from",
                    style: TextStyle(
                      color: Color(0xFF5F6368),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFC9545F), Color(0xFF4F80C8)],
                    ).createShader(bounds),
                    child: const Text(
                      "Vk",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
