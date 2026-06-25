import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';

class ZonesScreen extends StatelessWidget {
  const ZonesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text("Zones Screen (Coming Soon)")),
      bottomNavigationBar: BottomNavBar(currentIndex: 4),
    );
  }
}
