import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../models/user.dart';
import '../widgets/friend_item.dart';
import '../widgets/guardian_logo.dart';
import '../widgets/developer_dialog.dart';
import '../utils/constants.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  
  String userName = "...";
  double latitude = 0.0;
  double longitude = 0.0;
  String address = "Fetching location...";
  bool isSharing = false;
  List<UserModel> friendsList = [];
  int requestCount = 0;
  int alertCount = 0;
  String? selectedFriendUid;
  
  bool isMapExpanded = false;
  bool isSearchExpanded = false;
  List<Location> locationSuggestions = [];
  LatLng? searchResultPoint;

  StreamSubscription? _userSub;
  StreamSubscription? _friendsSub;
  StreamSubscription? _requestsSub;
  StreamSubscription? _alertsSub;
  StreamSubscription? _locationSub;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final uid = currentUser.uid;
    final db = FirebaseDatabase.instance;

    // User data for non-location fields
    _userSub = db.ref(AppConstants.users).child(uid).onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null && mounted) {
        setState(() {
          userName = data["name"] ?? "";
          bool newSharing = data["isSharing"] ?? false;
          
          // If sharing status changed to TRUE, start location
          if (newSharing && !isSharing) {
            _startLiveLocation();
          } 
          // If sharing status changed to FALSE, stop location
          else if (!newSharing && isSharing) {
            _stopLiveLocation();
          }
          
          isSharing = newSharing;
        });
      }
    });

    // Friends data
    _friendsSub = db.ref(AppConstants.friends).child(uid).onValue.listen((event) async {
      final friendUids = event.snapshot.children.map((e) => e.key).toList();
      if (friendUids.isEmpty) {
        if (mounted) setState(() => friendsList = []);
        return;
      }

      List<UserModel> tempFriends = [];
      for (var fUid in friendUids) {
        if (fUid == null) continue;
        final fSnap = await db.ref(AppConstants.users).child(fUid).get();
        if (fSnap.exists && mounted) {
          tempFriends.add(UserModel.fromMap(fSnap.value as Map));
        }
      }
      if (mounted) setState(() => friendsList = tempFriends);
    });

    // Request count
    _requestsSub = db.ref(AppConstants.friendRequests).child(uid).onValue.listen((event) {
      if (mounted) setState(() => requestCount = event.snapshot.children.length);
    });

    // Alert count
    _alertsSub = db.ref(AppConstants.alerts).child(uid).onValue.listen((event) {
      if (mounted) setState(() => alertCount = event.snapshot.children.length);
    });
  }

  void _stopLiveLocation() {
    _locationSub?.cancel();
    _locationSub = null;
    if (mounted) {
      setState(() {
        address = "Location hidden";
      });
    }
  }

  Future<void> _startLiveLocation() async {
    // Check if already running
    if (_locationSub != null) return;

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => address = "Location services disabled");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => address = "Permission denied");
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => address = "Permission denied forever");
      return;
    }

    // Start listening to live location only if sharing is active
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
      ),
    ).listen((Position position) {
      debugPrint("LOCATION UPDATE (Live Sharing ON): ${position.latitude}, ${position.longitude}");
      if (mounted) {
        setState(() {
          latitude = position.latitude;
          longitude = position.longitude;
        });
        _getAddress(latitude, longitude);
        
        if (!isMapExpanded) {
           _mapController.move(LatLng(latitude, longitude), 15);
        }
      }
    });
  }

  Future<void> _getAddress(double lat, double lng) async {
    if (lat == 0.0 || lng == 0.0) return;
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks[0];
        setState(() {
          address = "${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}, ${place.country}";
        });
      }
    } catch (e) {
      if (mounted) setState(() => address = "Unable to get address");
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.length < 3) return;
    try {
      List<Location> locations = await locationFromAddress(query);
      if (mounted) {
        setState(() {
          locationSuggestions = locations;
        });
      }
    } catch (e) {
      if (mounted) setState(() => locationSuggestions = []);
    }
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _friendsSub?.cancel();
    _requestsSub?.cancel();
    _alertsSub?.cancel();
    _locationSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: _buildMainContent(),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => DeveloperDialog.show(context),
          child: Row(
            children: [
              const AnimatedGuardianLogo(size: 40, showWordmark: false),
              const SizedBox(width: 8),
              const Text("Sentriq",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF7F77DD))),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFC9545F), Color(0xFF4F80C8)],
                  ).createShader(bounds),
                  child: const Text("by Vk",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, 'friend_requests'),
          child: Container(
            width: 45,
            height: 45,
            decoration: const BoxDecoration(color: Color(0xFFF1F3F4), shape: BoxShape.circle),
            child: Center(
              child: Badge(
                label: Text(requestCount.toString()),
                isLabelVisible: requestCount > 0,
                backgroundColor: Colors.red,
                child: const Text("❤️", style: TextStyle(fontSize: 20)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    return SafeArea(
      child: Stack(
        children: [
          // If expanded, show full screen map
          if (isMapExpanded)
            Positioned.fill(
              child: _buildMapSection(),
            ),

          if (!isMapExpanded)
            // Dashboard Content
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildHeader(),
                  const SizedBox(height: 10),
                  const Text("Welcome back", style: TextStyle(color: Color(0xFF5F6368))),
                  Text("Hi, $userName",
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E))),
                  const SizedBox(height: 20),
                  _buildMinifiedMapSection(),
                  const SizedBox(height: 20),
                  _buildLiveSharingSwitch(),
                  const SizedBox(height: 20),
                  _buildFriendsSection(),
                  const SizedBox(height: 120),
                ],
              ),
            ),

          if (isMapExpanded) ...[
            _buildSearchUI(),
            _buildCloseButton(),
          ],

          const Align(
            alignment: Alignment.bottomCenter,
            child: BottomNavBar(currentIndex: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildMinifiedMapSection() {
    return Column(
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 2)],
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildMapSection(),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 2)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(address,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E))),
              const SizedBox(height: 12),
              Container(height: 1, color: Colors.grey[200]),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text("Lat ${latitude.toStringAsFixed(7)}",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(width: 16),
                  Text("Long ${longitude.toStringAsFixed(7)}",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchUI() {
    if (!isSearchExpanded) {
      return Positioned(
        top: 20,
        left: 16,
        child: GestureDetector(
          onTap: () => setState(() => isSearchExpanded = true),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))
            ]),
            child: const Icon(Icons.search, color: Color(0xFF4A8DFF), size: 28),
          ),
        ),
      );
    }

    return Positioned(
      top: 20,
      left: 16,
      right: 76,
      child: Column(
        children: [
          Container(
            height: 55,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)]),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() {
                    isSearchExpanded = false;
                    _searchController.clear();
                    locationSuggestions = [];
                  }),
                  child: const Icon(Icons.arrow_back, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _searchLocation,
                    autofocus: true,
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: "Search Location...",
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (locationSuggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
              child: Column(
                children: locationSuggestions.take(5).map((loc) {
                  return ListTile(
                    leading: const Icon(Icons.location_on, color: Colors.grey),
                    title: FutureBuilder<List<Placemark>>(
                      future: placemarkFromCoordinates(loc.latitude, loc.longitude),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                          final p = snapshot.data![0];
                          return Text("${p.name}, ${p.locality}");
                        }
                        return const Text("Loading...");
                      },
                    ),
                    onTap: () {
                      setState(() {
                        searchResultPoint = LatLng(loc.latitude, loc.longitude);
                        locationSuggestions = [];
                        isSearchExpanded = false;
                        _searchController.clear();
                      });
                      _mapController.move(searchResultPoint!, 17);
                    },
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCloseButton() {
    return Positioned(
      top: 20,
      right: 16,
      child: GestureDetector(
        onTap: () => setState(() {
          isMapExpanded = false;
          searchResultPoint = null;
          isSearchExpanded = false;
          _searchController.clear();
          locationSuggestions = [];
        }),
        child: Container(
          width: 55,
          height: 55,
          decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
          child: const Icon(Icons.close, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildMapSection() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(latitude, longitude),
        initialZoom: 15,
        onTap: (_, __) {
          if (!isMapExpanded) {
            setState(() => isMapExpanded = true);
          }
          setState(() => selectedFriendUid = null);
        },
        onMapReady: () {
          if (isMapExpanded) _autoZoomMap();
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.example.sentriq',
        ),
        MarkerLayer(
          markers: [
            if (isMapExpanded && searchResultPoint != null)
              Marker(
                point: searchResultPoint!,
                width: 40,
                height: 40,
                child: const Icon(Icons.location_on, color: Colors.green, size: 40),
              ),
            // Current User "You" Marker
            Marker(
              point: LatLng(latitude, longitude),
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
                  const Icon(Icons.location_on, color: Color(0xFF2ECC71), size: 35),
                ],
              ),
            ),
            // Friends Markers
            ...friendsList.map((f) => Marker(
                  point: LatLng(f.latitude, f.longitude),
                  width: 120,
                  height: 90,
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => selectedFriendUid = f.uid);
                      _mapController.move(LatLng(f.latitude, f.longitude), 16);
                    },
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[300]!),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                          ),
                          child: Text(
                            f.name,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.red, size: 20),
                        const Icon(Icons.location_on, color: Colors.red, size: 30),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ],
    );
  }

  Widget _buildLiveSharingSwitch() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: isSharing ? const Color(0xFFE7F3E8) : const Color(0xFFF1F3F4),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: isSharing ? const Color(0xFF2ECC71) : Colors.grey, shape: BoxShape.circle),
                  child: Icon(isSharing ? Icons.gps_fixed : Icons.gps_off, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Live sharing",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E))),
                    Text(isSharing ? "You are visible to friends" : "Location hidden",
                        style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
                  ],
                ),
              ],
            ),
            Switch(
              value: isSharing,
              onChanged: (val) async {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid != null) {
                  if (val) {
                    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                    if (!serviceEnabled) {
                      await Geolocator.openLocationSettings();
                      return;
                    }
                  }
                  
                  await FirebaseDatabase.instance.ref(AppConstants.users).child(uid).update({"isSharing": val});
                  if (val) {
                    FlutterBackgroundService().startService();
                  } else {
                    FlutterBackgroundService().invoke('stopService');
                  }
                }
              },
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF2ECC71),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: const Color(0xFFF1F3F4),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Nearby friends",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E))),
            const SizedBox(height: 10),
            if (friendsList.isEmpty)
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, 'search_friends'),
                child: const Column(
                  children: [
                    SizedBox(width: double.infinity),
                    AnimatedGuardianLogo(size: 100, showWordmark: false),
                    SizedBox(height: 12),
                    Text("No friends yet. Tap to add some!", style: TextStyle(color: Color(0xFF5F6368), fontSize: 13)),
                  ],
                ),
              )
            else
              ...friendsList.map((friend) => FriendItem(
                    user: friend,
                    onTap: () => Navigator.pushNamed(context, 'map', arguments: friend.uid),
                  )),
          ],
        ),
      ),
    );
  }

  void _autoZoomMap() {
    if (friendsList.isEmpty) return;
    
    final points = [LatLng(latitude, longitude), ...friendsList.map((f) => LatLng(f.latitude, f.longitude))];
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
  }
}
