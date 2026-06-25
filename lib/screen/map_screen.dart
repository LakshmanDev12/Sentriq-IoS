import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../widgets/bottom_nav_bar.dart';
import '../models/user.dart';
import '../services/location_service.dart';
import '../models/zone.dart';
import '../utils/constants.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final LocationService _locationService = LocationService();

  LatLng _myLocation = const LatLng(11.1271, 78.6569);
  final Map<String, UserModel> _friends = {};
  List<Zone> _zones = [];
  
  String? _trackedFriendUid;
  bool _isFollowingFriend = false;

  StreamSubscription? _myLocationSub;
  StreamSubscription? _friendsListSub;
  StreamSubscription? _zonesSub;
  final List<StreamSubscription> _friendSubs = [];

  @override
  void initState() {
    super.initState();
    _initLocation();
    _initFriendsListener();
    _initZonesListener();
    
    // Check if we should start tracking a specific friend passed via arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        setState(() {
          _trackedFriendUid = args;
          _isFollowingFriend = true;
        });
      }
    });
  }

  void _initZonesListener() {
    _zonesSub = _database.ref(AppConstants.zones).orderByChild("ownerUid").equalTo(_myUid).onValue.listen((event) {
      List<Zone> temp = [];
      if (event.snapshot.exists) {
        for (var child in event.snapshot.children) {
          temp.add(Zone.fromMap({...child.value as Map, 'zoneId': child.key}));
        }
      }
      if (mounted) {
        setState(() {
          _zones = temp;
        });
      }
    });
  }

  void _initLocation() async {
    final pos = await _locationService.getCurrentLocation();
    if (pos != null) {
      if (mounted) {
        setState(() {
          _myLocation = LatLng(pos.latitude, pos.longitude);
        });
        _mapController.move(_myLocation, 13);
      }
    }

    _myLocationSub = _locationService.getLocationStream().listen((pos) {
      if (mounted) {
        setState(() {
          _myLocation = LatLng(pos.latitude, pos.longitude);
        });
      }
    });
  }

  void _initFriendsListener() {
    if (_myUid.isEmpty) return;

    _friendsListSub = _database.ref(AppConstants.friends).child(_myUid).onValue.listen((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists) return;

      final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      final List<String> currentFriendUids = data.keys.map((e) => e.toString()).toList();

      for (String uid in currentFriendUids) {
        if (!_friends.containsKey(uid)) {
          _listenToFriend(uid);
        }
      }
    });
  }

  void _listenToFriend(String uid) {
    final sub = _database.ref(AppConstants.users).child(uid).onValue.listen((event) {
      final snap = event.snapshot;
      if (snap.exists) {
        final data = snap.value as Map<dynamic, dynamic>;
        final user = UserModel.fromJson({...data, 'uid': uid});
        if (mounted) {
          setState(() {
            if (user.isSharing) {
              _friends[uid] = user;
              // Auto-move camera if following this friend
              if (_isFollowingFriend && _trackedFriendUid == uid) {
                _mapController.move(LatLng(user.latitude, user.longitude), _mapController.camera.zoom);
              }
            } else {
              _friends.remove(uid);
              if (_trackedFriendUid == uid) {
                _trackedFriendUid = null;
                _isFollowingFriend = false;
              }
            }
          });
        }
      }
    });
    _friendSubs.add(sub);
  }

  @override
  void dispose() {
    _myLocationSub?.cancel();
    _friendsListSub?.cancel();
    _zonesSub?.cancel();
    for (var sub in _friendSubs) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<void> _openDirections(UserModel friend) async {
    final url = "https://www.google.com/maps/dir/?api=1&destination=${friend.latitude},${friend.longitude}&travelmode=driving";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _showFriendDetails(UserModel friend) {
    setState(() {
      _trackedFriendUid = friend.uid;
    });

    double distance = Geolocator.distanceBetween(
      _myLocation.latitude,
      _myLocation.longitude,
      friend.latitude,
      friend.longitude,
    );

    String lastSeen = "Just now";
    if (friend.lastUpdated > 0) {
      final dt = DateTime.fromMillisecondsSinceEpoch(friend.lastUpdated);
      lastSeen = DateFormat('jm').format(dt);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF7F77DD).withOpacity(0.1),
                  child: Text(
                    friend.name[0].toUpperCase(),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF7F77DD)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(friend.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(friend.address, style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text("LIVE", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _infoItem(Icons.social_distance, "Distance", "${(distance / 1000).toStringAsFixed(1)} km"),
                _infoItem(Icons.update, "Last Seen", lastSeen),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _actionButton(
                  onPressed: () {
                    setState(() => _isFollowingFriend = true);
                    _mapController.move(LatLng(friend.latitude, friend.longitude), 16);
                    Navigator.pop(context);
                  },
                  icon: Icons.my_location,
                  label: "TRACK",
                  color: const Color(0xFF7F77DD),
                ),
                const SizedBox(width: 8),
                _actionButton(
                  onPressed: () {
                    setState(() {
                      _trackedFriendUid = friend.uid;
                    });
                    Navigator.pop(context);
                  },
                  icon: Icons.route,
                  label: "ROUTE",
                  color: Colors.blue[600]!,
                ),
                const SizedBox(width: 8),
                _actionButton(
                  onPressed: () => _openDirections(friend),
                  icon: Icons.directions,
                  label: "GO",
                  color: const Color(0xFF279969),
                  isPrimary: true,
                ),
                const SizedBox(width: 8),
                _actionButton(
                  onPressed: () => Navigator.pushNamed(context, 'create_zone', arguments: friend.uid),
                  icon: Icons.add_location_alt,
                  label: "ZONE",
                  color: const Color(0xFF5C59BB),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    bool isPrimary = false,
  }) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: isPrimary ? color : Colors.white,
            foregroundColor: isPrimary ? Colors.white : color,
            elevation: isPrimary ? 2 : 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: isPrimary ? BorderSide.none : BorderSide(color: color.withOpacity(0.2)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[400]),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    UserModel? trackedFriend = _trackedFriendUid != null ? _friends[_trackedFriendUid] : null;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text("Live Map", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_isFollowingFriend)
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              onPressed: () => setState(() => _isFollowingFriend = false),
              tooltip: "Stop Following",
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _myLocation,
              initialZoom: 13,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture && _isFollowingFriend) {
                  setState(() => _isFollowingFriend = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.sentriq',
              ),
              CircleLayer(
                circles: _zones.map((zone) => CircleMarker(
                  point: LatLng(zone.latitude, zone.longitude),
                  color: (zone.status == "INSIDE" ? Colors.green : Colors.blue).withOpacity(0.3),
                  borderStrokeWidth: 2,
                  borderColor: zone.status == "INSIDE" ? Colors.green : Colors.blue,
                  useRadiusInMeter: true,
                  radius: zone.radius,
                )).toList(),
              ),
              if (trackedFriend != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_myLocation, LatLng(trackedFriend.latitude, trackedFriend.longitude)],
                      strokeWidth: 4,
                      color: const Color(0xFF7F77DD),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // My Marker
                  Marker(
                    point: _myLocation,
                    width: 100,
                    height: 90,
                    alignment: Alignment.topCenter,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.withOpacity(0.5)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                          ),
                          child: const Text(
                            "You",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.blue, size: 20),
                        const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
                      ],
                    ),
                  ),
                  // Friends Markers
                  ..._friends.values.map((friend) => Marker(
                    point: LatLng(friend.latitude, friend.longitude),
                    width: 120,
                    height: 90,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => _showFriendDetails(friend),
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
                              friend.name,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Colors.red, size: 20),
                          const Icon(Icons.location_pin, color: Colors.red, size: 40),
                        ],
                      ),
                    ),
                  )),
                ],
              ),
            ],
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: BottomNavBar(currentIndex: 0),
          ),
        ],
      ),
    );
  }
}
