import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/bottom_nav_bar.dart';
import '../models/zone_alert.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';

class AlertScreen extends StatefulWidget {
  const AlertScreen({super.key});

  @override
  State<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends State<AlertScreen> {
  List<ZoneAlert> alerts = [];
  bool isLoading = true;
  StreamSubscription? _alertsSub;

  @override
  void initState() {
    super.initState();
    loadAlerts();
  }

  @override
  void dispose() {
    _alertsSub?.cancel();
    super.dispose();
  }

  void loadAlerts() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    debugPrint("ALERT SCREEN: Loading alerts for UID: $uid");
    if (uid == null) {
      setState(() => isLoading = false);
      return;
    }

    _alertsSub = FirebaseDatabase.instance.ref(AppConstants.alerts).child(uid).onValue.listen((event) {
      List<ZoneAlert> temp = [];

      debugPrint("ALERT SCREEN: Received update. Exists: ${event.snapshot.exists}");

      if (event.snapshot.exists) {
        for (var child in event.snapshot.children) {
          try {
            final data = child.value as Map<dynamic, dynamic>;
            temp.add(ZoneAlert.fromMap(data));
          } catch (e) {
            debugPrint("ALERT SCREEN: Error parsing alert: $e");
          }
        }

        temp.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }

      debugPrint("ALERT SCREEN: Total alerts loaded: ${temp.length}");

      if (mounted) {
        setState(() {
          alerts = temp;
          isLoading = false;
        });
      }
    }, onError: (error) {
      debugPrint("ALERT SCREEN: Database Error: $error");
      if (mounted) setState(() => isLoading = false);
    });
  }

  void _deleteAllAlerts() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete All Alerts", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to permanently delete all alert messages?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                await FirebaseDatabase.instance.ref(AppConstants.alerts).child(uid).remove();
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Delete All", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String formatTimestamp(int timestamp) {
    var dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('MMM dd, yyyy • hh:mm a').format(dt);
  }

  Widget _buildAlertCard(ZoneAlert alert, bool isEntered) {
    final statusColor = isEntered ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F);
    final surfaceColor = isEntered ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
    final statusText = isEntered ? "Arrived" : "Left";
    
    var dt = DateTime.fromMillisecondsSinceEpoch(alert.timestamp);
    String dateTimeStr = DateFormat('MMM dd, yyyy • hh:mm a').format(dt);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAEAEA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (alert.userId.isNotEmpty) {
              Navigator.pushNamed(context, 'map', arguments: alert.userId);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: statusColor, size: 10),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isEntered
                      ? "${alert.userName} has arrived at ${alert.zoneName}"
                      : "${alert.userName} has left ${alert.zoneName}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  dateTimeStr,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("ALERT SCREEN: Building UI. Alerts: ${alerts.length}, Loading: $isLoading");
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                /* HEADER */
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.black),
                            onPressed: () => Navigator.pushReplacementNamed(context, 'dashboard'),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "Zone Alerts",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (alerts.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: _deleteAllAlerts,
                        ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : alerts.isEmpty
                          ? Center(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text("🔔", style: TextStyle(fontSize: 60)),
                                    const SizedBox(height: 16),
                                    const Text(
                                      "No Zone Alerts",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                                    ),
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 40),
                                      child: Text(
                                        "Alerts will appear here when friends enter or leave zones you've marked.",
                                        style: TextStyle(color: Colors.grey[600]),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                              itemCount: alerts.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final alert = alerts[index];
                                final isEntered = alert.type.toLowerCase() == "entered";
                                
                                return Dismissible(
                                  key: Key(alert.alertId),
                                  direction: DismissDirection.startToEnd,
                                  background: Container(
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    margin: const EdgeInsets.only(bottom: 4), 
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFEBEE),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.delete, color: Color(0xFFD32F2F)),
                                  ),
                                  onDismissed: (direction) {
                                    final uid = FirebaseAuth.instance.currentUser?.uid;
                                    if (uid != null) {
                                      FirebaseDatabase.instance
                                          .ref(AppConstants.alerts)
                                          .child(uid)
                                          .child(alert.alertId)
                                          .remove();
                                    }
                                  },
                                  child: _buildAlertCard(alert, isEntered),
                                );
                              },
                            ),
                ),
              ],
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: BottomNavBar(currentIndex: 1),
            ),
          ],
        ),
      ),
    );
  }
}

// Remove the old AlertCard class below as it's now integrated as _buildAlertCard logic

