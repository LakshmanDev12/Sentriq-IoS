import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/bottom_nav_bar.dart';
import '../models/user.dart';
import '../utils/constants.dart';

class TrackFriendScreen extends StatefulWidget {
  const TrackFriendScreen({super.key});

  @override
  State<TrackFriendScreen> createState() => _TrackFriendScreenState();
}

class _TrackFriendScreenState extends State<TrackFriendScreen> {
  final MapController _mapController = MapController();
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  
  UserModel? _friend;
  LatLng _myLocation = const LatLng(0, 0);
  bool _isLoading = true;
  bool _showDistanceOverlay = false;
  double _distanceInKm = 0.0;
  
  StreamSubscription? _friendSub;
  StreamSubscription? _myLocationSub;

  @override
  void initState() {
    super.initState();
    _initMyLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final friendUid = ModalRoute.of(context)?.settings.arguments as String?;
    if (friendUid != null && _friend == null) {
      _listenToFriend(friendUid);
    }
  }

  void _initMyLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    final pos = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _myLocation = LatLng(pos.latitude, pos.longitude);
      });
    }

    _myLocationSub = Geolocator.getPositionStream().listen((pos) {
      if (mounted) {
        setState(() {
          _myLocation = LatLng(pos.latitude, pos.longitude);
        });
      }
    });
  }

  void _listenToFriend(String uid) {
    _friendSub = _database.ref(AppConstants.users).child(uid).onValue.listen((event) {
      final snap = event.snapshot;
      if (snap.exists) {
        final data = snap.value as Map<dynamic, dynamic>;
        if (mounted) {
          setState(() {
            _friend = UserModel.fromJson({...data, 'uid': uid});
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  @override
  void dispose() {
    _friendSub?.cancel();
    _myLocationSub?.cancel();
    super.dispose();
  }

  void _calculateDistance() {
    if (_friend == null || _myLocation.latitude == 0) return;
    
    double distance = Geolocator.distanceBetween(
      _myLocation.latitude,
      _myLocation.longitude,
      _friend!.latitude,
      _friend!.longitude,
    );
    
    setState(() {
      _distanceInKm = distance / 1000;
      _showDistanceOverlay = true;
    });

    // Auto-zoom to fit both markers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final points = [_myLocation, LatLng(_friend!.latitude, _friend!.longitude)];
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 50),
      ));
    });
  }

  Future<void> _openDirections() async {
    if (_friend == null) return;
    final url = "https://www.google.com/maps/dir/?api=1&destination=${_friend!.latitude},${_friend!.longitude}&travelmode=driving";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_friend == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: const Center(child: Text("Friend not found")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        /* HEADER */
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pushReplacementNamed(context, 'dashboard'),
                              icon: const Icon(Icons.arrow_back),
                            ),
                            const Text(
                              "Tracking friend",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1C1E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        /* MAIN INFO CARD */
                        _buildFriendInfoCard(),
                        const SizedBox(height: 16),
                        /* MAP CARD */
                        _buildMapCard(),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
                const BottomNavBar(currentIndex: 3),
              ],
            ),
          ),
          if (_showDistanceOverlay) _buildDistanceOverlay(),
        ],
      ),
    );
  }

  Widget _buildFriendInfoCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: Colors.white,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: const Color(0xFFE7F3E8),
                      child: Text(
                        _friend!.name.isNotEmpty ? _friend!.name[0].toUpperCase() : "?",
                        style: const TextStyle(
                          color: Color(0xFF2ECC71),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _friend!.isSharing ? const Color(0xFF2ECC71) : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _friend!.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const Text(
                      "Live location",
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            /* Address Section */
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _friend!.address,
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${_friend!.latitude.toStringAsFixed(6)}, ${_friend!.longitude.toStringAsFixed(6)}",
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            /* Action Buttons */
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _calculateDistance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C59BB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  elevation: 0,
                ),
                child: const Text("How far away?", style: TextStyle(fontWeight: FontWeight.w500)),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, 'create_zone', arguments: _friend!.uid),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF279969),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_location_alt, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Add zone",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            "Get notified when ${_friend!.name} enters or leaves",
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: SizedBox(
        height: 300,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(_friend!.latitude, _friend!.longitude),
            initialZoom: 15,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.example.sentriq',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(_friend!.latitude, _friend!.longitude),
                  width: 120,
                  height: 90,
                  alignment: Alignment.topCenter,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withOpacity(0.5)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                        ),
                        child: Text(
                          _friend!.name,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.red, size: 20),
                      const Icon(Icons.location_on, color: Colors.red, size: 40),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.white,
        child: Stack(
          children: [
            /* Full Screen Map */
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(
                    (_myLocation.latitude + _friend!.latitude) / 2,
                    (_myLocation.longitude + _friend!.longitude) / 2,
                  ),
                  initialZoom: 12,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.example.sentriq',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _myLocation,
                        width: 100,
                        height: 90,
                        alignment: Alignment.topCenter,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[400]!),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                              ),
                              child: const Text("You", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 20),
                            const Icon(Icons.person_pin_circle, color: Colors.blue, size: 35),
                          ],
                        ),
                      ),
                      Marker(
                        point: LatLng(_friend!.latitude, _friend!.longitude),
                        width: 120,
                        height: 90,
                        alignment: Alignment.topCenter,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red[300]!),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                              ),
                              child: Text(_friend!.name,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                            ),
                            const Icon(Icons.arrow_drop_down, color: Colors.red, size: 20),
                            const Icon(Icons.location_on, color: Colors.red, size: 35),
                          ],
                        ),
                      ),
                    ],
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [_myLocation, LatLng(_friend!.latitude, _friend!.longitude)],
                        strokeWidth: 4,
                        color: const Color(0xFF5C59BB).withOpacity(0.6),
                        pattern: const StrokePattern.dotted(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            /* Top Bar */
            Positioned(
              top: 40,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => setState(() => _showDistanceOverlay = false),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.8),
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Text(
                      _friend!.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            /* Bottom Info Panel */
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.45,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.0),
                      Colors.white.withOpacity(0.8),
                      Colors.white,
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${_distanceInKm.toStringAsFixed(2)} km",
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        height: 55,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4285F4), Color(0xFF34A853)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _openDirections,
                          icon: const Icon(Icons.directions, color: Colors.white, size: 24),
                          label: const Text(
                            "START NAVIGATION",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 1.1,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text("Estimated travel time:", style: TextStyle(color: Colors.black54, fontSize: 14)),
                      const SizedBox(height: 24),
                      _buildTransportMode("Walking", (_distanceInKm / 5 * 60).toInt(), Colors.orange),
                      const SizedBox(height: 12),
                      _buildTransportMode("Bike", (_distanceInKm / 15 * 60).toInt(), Colors.green),
                      const SizedBox(height: 12),
                      _buildTransportMode("Car", (_distanceInKm / 40 * 60).toInt(), Colors.red),
                      const SizedBox(height: 120), // Padding for nav bar
                    ],
                  ),
                ),
              ),
            ),
            /* FAB */
            Positioned(
              right: 24,
              bottom: 120, // Push above nav bar
              child: FloatingActionButton(
                onPressed: () {
                  setState(() => _showDistanceOverlay = false);
                  Navigator.pushNamed(context, 'create_zone', arguments: _friend!.uid);
                },
                backgroundColor: const Color(0xFF279969),
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
                child: const Icon(Icons.add_location_alt, size: 28),
              ),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: BottomNavBar(currentIndex: 3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransportMode(String mode, int minutes, Color color) {
    IconData icon;
    if (mode == "Walking") {
      icon = Icons.directions_walk;
    } else if (mode == "Bike") {
      icon = Icons.directions_bike;
    } else {
      icon = Icons.directions_car;
    }

    return Card(
      elevation: 0,
      color: Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Text(mode, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
              ],
            ),
            Text("$minutes min", style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
