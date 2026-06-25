import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import '../models/zone.dart';
import '../utils/constants.dart';
import '../widgets/bottom_nav_bar.dart';

class MarkZoneScreen extends StatefulWidget {
  final Zone zone;
  const MarkZoneScreen({super.key, required this.zone});

  @override
  State<MarkZoneScreen> createState() => _MarkZoneScreenState();
}

class _MarkZoneScreenState extends State<MarkZoneScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  final TextEditingController _searchController = TextEditingController();
  
  late String _selectedType;
  late LatLng _selectedLocation;
  late double _radius;
  
  final MapController _mapController = MapController();
  bool _isSearchExpanded = false;
  List<Location> _locationSuggestions = [];

  final Map<String, IconData> _types = {
    "Home": Icons.home_rounded,
    "Work": Icons.work_rounded,
    "School": Icons.school_rounded,
    "Custom": Icons.location_on_rounded,
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.zone.name);
    _radius = widget.zone.radius;
    _selectedType = _types.containsKey(widget.zone.type) ? widget.zone.type : "Custom";
    _selectedLocation = LatLng(widget.zone.latitude, widget.zone.longitude);
  }

  Future<void> _searchLocation(String query) async {
    if (query.length < 3) return;
    try {
      List<Location> locations = await locationFromAddress(query);
      if (mounted) {
        setState(() {
          _locationSuggestions = locations;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _locationSuggestions = []);
    }
  }

  void _updateZone() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final zoneRef = FirebaseDatabase.instance
          .ref(AppConstants.zones)
          .child(widget.zone.friendUid)
          .child(widget.zone.zoneId);

      debugPrint("Updating zone at: ${zoneRef.path}");
      await zoneRef.update({
        "createdAt": widget.zone.createdAt,
        "friendName": widget.zone.friendName,
        "friendUid": widget.zone.friendUid,
        "latitude": _selectedLocation.latitude,
        "longitude": _selectedLocation.longitude,
        "name": _nameController.text,
        "ownerUid": widget.zone.ownerUid,
        "radius": _radius,
        "status": widget.zone.status,
        "type": _selectedType,
        "zoneId": widget.zone.zoneId,
      });
      debugPrint("Zone updated successfully!");

      if (mounted) {
        Navigator.pop(context); // Close BottomSheet
        Navigator.pop(context); // Go back to My Zones Screen
      }
    } catch (e) {
      debugPrint("Error updating zone: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update zone: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          _buildMap(),
          _buildSearchUI(),
          _buildCloseButton(),
          _buildConfirmFAB(),
          const Align(
            alignment: Alignment.bottomCenter,
            child: BottomNavBar(currentIndex: 3),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _selectedLocation,
        initialZoom: 16,
        onTap: (tapPosition, point) {
          setState(() => _selectedLocation = point);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.example.sentriq',
        ),
        CircleLayer<Object>(
          circles: [
            CircleMarker<Object>(
              point: _selectedLocation,
              color: const Color(0xFF5C59BB).withOpacity(0.2),
              borderStrokeWidth: 2,
              borderColor: const Color(0xFF5C59BB),
              useRadiusInMeter: true,
              radius: _radius,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: _selectedLocation,
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
                      border: Border.all(color: const Color(0xFF5C59BB).withOpacity(0.5)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                    ),
                    child: Text(
                      widget.zone.friendName,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5C59BB)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Color(0xFF5C59BB), size: 20),
                  const Icon(Icons.location_on, color: Color(0xFF5C59BB), size: 40),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchUI() {
    if (!_isSearchExpanded) {
      return Positioned(
        top: 40,
        left: 16,
        child: GestureDetector(
          onTap: () => setState(() => _isSearchExpanded = true),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white, 
              shape: BoxShape.circle, 
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))]
            ),
            child: const Icon(Icons.search, color: Color(0xFF4A8DFF), size: 28),
          ),
        ),
      );
    }

    return Positioned(
      top: 40,
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
                    _isSearchExpanded = false;
                    _searchController.clear();
                    _locationSuggestions = [];
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
          if (_locationSuggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
              child: Column(
                children: _locationSuggestions.take(5).map((loc) {
                  return ListTile(
                    leading: const Icon(Icons.location_on, color: Colors.grey),
                    title: FutureBuilder<List<Placemark>>(
                      future: placemarkFromCoordinates(loc.latitude, loc.longitude),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                          final p = snapshot.data![0];
                          return Text("${p.name ?? ''}, ${p.locality ?? ''}");
                        }
                        return const Text("Loading...");
                      },
                    ),
                    onTap: () {
                      setState(() {
                        _selectedLocation = LatLng(loc.latitude, loc.longitude);
                        _locationSuggestions = [];
                        _isSearchExpanded = false;
                        _searchController.clear();
                      });
                      _mapController.move(_selectedLocation, 17);
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
      top: 40,
      right: 16,
      child: GestureDetector(
        onTap: () => Navigator.pushReplacementNamed(context, 'dashboard'),
        child: Container(
          width: 55,
          height: 55,
          decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
          child: const Icon(Icons.close, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildConfirmFAB() {
    return Positioned(
      bottom: 120,
      right: 20,
      child: FloatingActionButton(
        onPressed: _showZoneConfigBottomSheet,
        backgroundColor: const Color(0xFF5C59BB),
        child: const Icon(Icons.check, color: Colors.white),
      ),
    );
  }

  void _showZoneConfigBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text("Mark Zone", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    _buildModalZoneTypeSelector(setModalState),
                    const SizedBox(height: 20),
                    _buildModalZoneNameInput(),
                    const SizedBox(height: 20),
                    _buildModalRadiusSelector(setModalState),
                    const SizedBox(height: 30),
                    _buildModalSaveButton(),
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildModalZoneTypeSelector(StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Zone type", style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _types.entries.map((entry) {
            bool isSelected = _selectedType == entry.key;
            return GestureDetector(
              onTap: () {
                setModalState(() {
                  _selectedType = entry.key;
                  _nameController.text = "${widget.zone.friendName} ${entry.key}";
                });
                setState(() {});
              },
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFEDECFF) : const Color(0xFFF7F8FA),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(entry.value, color: isSelected ? const Color(0xFF5C59BB) : Colors.grey[400]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.black : Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildModalZoneNameInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Zone name", style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: "Enter zone name",
              border: InputBorder.none,
              icon: Icon(Icons.domain, color: Colors.grey, size: 20),
            ),
            validator: (val) => val!.isEmpty ? "Enter zone name" : null,
          ),
        ),
      ],
    );
  }

  Widget _buildModalRadiusSelector(StateSetter setModalState) {
    return Row(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                value: _radius / 1000,
                strokeWidth: 4,
                backgroundColor: const Color(0xFFEDECFF),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5C59BB)),
              ),
            ),
            const Text("m", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Radius", style: TextStyle(color: Colors.grey, fontSize: 12)),
              Text("${_radius.toInt()} m", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  if (_radius > 50) {
                    setModalState(() => _radius -= 50);
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.remove),
              ),
              IconButton(
                onPressed: () {
                  if (_radius < 1000) {
                    setModalState(() => _radius += 50);
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModalSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: _updateZone,
        icon: const Icon(Icons.save_rounded),
        label: const Text("Save mark", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5C59BB),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
      ),
    );
  }
}
