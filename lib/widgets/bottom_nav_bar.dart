import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'guardian_logo.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
  });

  void _onLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, 'login', (route) => false);
              }
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if keyboard is visible
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom != 0;

    if (isKeyboardVisible) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildLogoNavItem(context, 0, "dashboard"),
            _buildNavItem(context, 1, Icons.notifications_rounded, "Alerts", 'alerts'),
            _buildNavItem(context, 2, Icons.search_rounded, "Search", 'search_friends'),
            _buildNavItem(context, 3, Icons.people_rounded, "Friends", 'friends'),
            _buildLogoutItem(context),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoNavItem(BuildContext context, int index, String routeName) {
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () {
        if (isSelected) return;
        Navigator.pushReplacementNamed(context, routeName);
      },
      child: const SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedGuardianLogo(size: 24, showWordmark: false),
            SizedBox(height: 4),
            Text(
              "Sentriq",
              style: TextStyle(
                color: Color(0xFF7F77DD),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label, String routeName) {
    final isSelected = currentIndex == index;
    final color = isSelected ? const Color(0xFF1A1C1E) : Colors.grey[400];

    return GestureDetector(
      onTap: () {
        if (isSelected) return;
        Navigator.pushReplacementNamed(context, routeName);
      },
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutItem(BuildContext context) {
    final color = Colors.grey[400];

    return GestureDetector(
      onTap: () => _onLogout(context),
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.exit_to_app_rounded, color: Color(0xFF5F6368), size: 24),
            const SizedBox(height: 4),
            Text(
              "Logout",
              style: TextStyle(
                color: color,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
