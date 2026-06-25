import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/zone.dart';
import '../utils/constants.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/guardian_logo.dart';

class MyZonesScreen extends StatefulWidget {
  const MyZonesScreen({super.key});

  @override
  State<MyZonesScreen> createState() => _MyZonesScreenState();
}

class _MyZonesScreenState extends State<MyZonesScreen> {
  final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  String? _friendUid;
  String? _friendName;
  List<Zone> _zones = [];
  bool _isLoading = true;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        _friendUid = args;
      }
      _loadZones();
      _isInitialized = true;
    }
  }

  void _loadZones() {
    final ref = FirebaseDatabase.instance.ref(AppConstants.zones);

    ref.onValue.listen((event) {
      List<Zone> temp = [];

      if (event.snapshot.exists) {
        // First level: Friend UIDs
        for (var friendNode in event.snapshot.children) {
          // Second level: Zone IDs
          for (var zoneNode in friendNode.children) {
            final data = zoneNode.value;
            if (data is Map) {
              final zone = Zone.fromMap({...data, 'zoneId': zoneNode.key});
              
              if (_friendUid != null) {
                // Filter for a specific friend
                if (zone.ownerUid == _myUid && zone.friendUid == _friendUid) {
                  temp.add(zone);
                }
              } else {
                // General view: all zones I've created
                if (zone.ownerUid == _myUid) {
                  temp.add(zone);
                }
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _zones = temp;
          _isLoading = false;
        });
      }
    }, onError: (error) {
      debugPrint("Database error: $error");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  void _deleteZone(Zone zone) {
    FirebaseDatabase.instance
        .ref(AppConstants.zones)
        .child(zone.friendUid)
        .child(zone.zoneId)
        .remove();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<Zone> filteredZones = _zones.where((z) {
      return z.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _zones.isEmpty
                      ? _buildEmptyState("None of the zone is marked")
                      : filteredZones.isEmpty
                          ? _buildEmptyState("No zones match your search")
                          : _buildZoneList(filteredZones),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 3),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pushReplacementNamed(context, 'dashboard'),
                icon: const Icon(Icons.arrow_back, color: Colors.black),
              ),
              const SizedBox(width: 8),
              const Text(
                "Saved places",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1C1E),
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, 'create_zone', arguments: _friendUid),
            icon: const Icon(Icons.add, size: 28, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: "Search zones...",
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = "");
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF9F9F9),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEBEBEB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF5A4FCF)),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AnimatedGuardianLogo(size: 100, showWordmark: false),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneList(List<Zone> zones) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: zones.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final zone = zones[index];
        
        return ZoneItemCard(
          zone: zone,
          onEdit: () => Navigator.pushNamed(context, 'mark_zone', arguments: zone),
          onDelete: () => _deleteZone(zone),
        );
      },
    );
  }
}

class ZoneItemCard extends StatelessWidget {
  final Zone zone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ZoneItemCard({
    super.key,
    required this.zone,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFEEEEEE)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F3F4),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: AnimatedGuardianLogo(size: 24, showWordmark: false),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zone.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Friend: ${zone.friendName}",
                        style: const TextStyle(
                          color: Color(0xFF5A4FCF),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: zone.status == "INSIDE" ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              zone.status,
                              style: TextStyle(
                                color: zone.status == "INSIDE" ? Colors.green : Colors.grey,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Lat: ${zone.latitude.toStringAsFixed(6)}",
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                      Text(
                        "Long: ${zone.longitude.toStringAsFixed(6)}",
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${zone.radius.toInt()} m",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5A4FCF),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Radius",
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF5A4FCF)),
                  label: const Text("Mark", style: TextStyle(color: Color(0xFF5A4FCF))),
                ),
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Delete Zone?"),
                        content: const Text("Are you sure you want to remove this place?"),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
                          TextButton(
                            onPressed: () {
                              onDelete();
                              Navigator.pop(context);
                            },
                            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFE57373)),
                  label: const Text("Delete", style: TextStyle(color: Color(0xFFE57373))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
