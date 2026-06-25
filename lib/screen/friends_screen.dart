import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/guardian_logo.dart';
import '../models/user.dart';
import '../utils/constants.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  List<String> _friendUids = [];
  final Map<String, UserModel> _friendData = {};
  final List<StreamSubscription> _subscriptions = [];
  StreamSubscription? _friendsListSub;

  String _searchQuery = "";
  bool _isSearchingBarVisible = false;
  bool _isLoading = true;

  final Color _onlineGreen = const Color(0xFF2ECC71);
  final Color _offlineRed = const Color(0xFFE74C3C);
  final Color _onlineBg = const Color(0xFFE7F3E8);
  final Color _offlineBg = const Color(0xFFFBE9E7);
  final Color _textColor = const Color(0xFF1A1C1E);
  final Color _subTextColor = const Color(0xFF5F6368);

  @override
  void initState() {
    super.initState();
    _initFriendsListener();
  }

  void _initFriendsListener() {
    if (_myUid.isEmpty) return;

    _friendsListSub = _database.ref(AppConstants.friends).child(_myUid).onValue.listen((event) {
      final snapshot = event.snapshot;
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      if (!snapshot.exists) {
        if (mounted) setState(() => _friendUids = []);
        return;
      }

      final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      final List<String> newFriendUids = data.keys.map((e) => e.toString()).toList();

      // For each new friend, start listening to their profile
      for (String uid in newFriendUids) {
        if (!_friendData.containsKey(uid)) {
          final sub = _database.ref(AppConstants.users).child(uid).onValue.listen((userEvent) {
            final userSnap = userEvent.snapshot;
            if (userSnap.exists) {
              final userData = userSnap.value as Map<dynamic, dynamic>;
              if (mounted) {
                setState(() {
                  _friendData[uid] = UserModel.fromJson({...userData, 'uid': uid});
                });
              }
            }
          });
          _subscriptions.add(sub);
        }
      }

      if (mounted) {
        setState(() {
          _friendUids = newFriendUids;
        });
      }
    });
  }

  @override
  void dispose() {
    _friendsListSub?.cancel();
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  void _showUnfriendDialog(String friendUid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Friend"),
        content: const Text("Are you sure you want to remove this friend?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("NO"),
          ),
          TextButton(
            onPressed: () {
              _database.ref(AppConstants.friends).child(_myUid).child(friendUid).remove();
              _database.ref(AppConstants.friends).child(friendUid).child(_myUid).remove();
              Navigator.pop(context);
            },
            child: const Text("YES", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredFriends = _friendUids.where((uid) {
      if (_searchQuery.isEmpty) return true;
      final user = _friendData[uid];
      if (user == null) return false;
      return user.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.email.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 32),
              /* HEADER */
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: _isSearchingBarVisible
                    ? Row(
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: (val) => setState(() => _searchQuery = val),
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: "Search friends...",
                                hintStyle: const TextStyle(color: Colors.grey),
                                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.grey),
                                  onPressed: () {
                                    setState(() {
                                      _isSearchingBarVisible = false;
                                      _searchQuery = "";
                                    });
                                  },
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF9F9F9),
                                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.grey),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.grey),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF4A8DFF)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.arrow_back, color: _textColor),
                                onPressed: () => Navigator.pushReplacementNamed(context, 'dashboard'),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "My friends",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: _textColor,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.search, color: _textColor),
                            onPressed: () => setState(() => _isSearchingBarVisible = true),
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 16),

              /* FRIENDS LIST */
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: AnimatedGuardianLogo(size: 150),
                      )
                    : filteredFriends.isEmpty
                        ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const AnimatedGuardianLogo(size: 150),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty ? "No friends yet" : "No matching friends found",
                              style: TextStyle(color: _subTextColor),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
                        itemCount: filteredFriends.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final uid = filteredFriends[index];
                          final user = _friendData[uid];
                          if (user == null) {
                            return const SizedBox(height: 100);
                          }
                          return FriendDetailCard(
                            user: user,
                            onlineBg: _onlineBg,
                            offlineBg: _offlineBg,
                            onlineColor: _onlineGreen,
                            offlineColor: _offlineRed,
                            textColor: _textColor,
                            subTextColor: _subTextColor,
                            onTrack: () => Navigator.pushNamed(context, 'map', arguments: uid),
                            onMarkZone: () => Navigator.pushNamed(context, 'create_zone', arguments: uid),
                            onMyZones: () => Navigator.pushNamed(context, 'my_zones', arguments: uid),
                            onUnfriend: () => _showUnfriendDialog(uid),
                          );
                        },
                      ),
              ),
            ],
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: BottomNavBar(currentIndex: 3),
          ),
        ],
      ),
    );
  }
}

class FriendDetailCard extends StatefulWidget {
  final UserModel user;
  final Color onlineBg;
  final Color offlineBg;
  final Color onlineColor;
  final Color offlineColor;
  final Color textColor;
  final Color subTextColor;
  final VoidCallback onTrack;
  final VoidCallback onMarkZone;
  final VoidCallback onMyZones;
  final VoidCallback onUnfriend;

  const FriendDetailCard({
    super.key,
    required this.user,
    required this.onlineBg,
    required this.offlineBg,
    required this.onlineColor,
    required this.offlineColor,
    required this.textColor,
    required this.subTextColor,
    required this.onTrack,
    required this.onMarkZone,
    required this.onMyZones,
    required this.onUnfriend,
  });

  @override
  State<FriendDetailCard> createState() => _FriendDetailCardState();
}

class _FriendDetailCardState extends State<FriendDetailCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final bool isOnline = widget.user.isSharing;
    final statusColor = isOnline ? widget.onlineColor : widget.offlineColor;
    final cardBackground = isOnline ? widget.onlineBg : widget.offlineBg;
    final borderColor = statusColor.withOpacity(0.3);

    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : "?",
                            style: TextStyle(
                              color: widget.subTextColor,
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
                              color: cardBackground,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: Container(
                              decoration: BoxDecoration(
                                color: statusColor,
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
                          widget.user.name,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 1,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Text(
                        isOnline ? "Live" : "Offline",
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: statusColor,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: statusColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.address,
                          style: TextStyle(
                            color: widget.textColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "${widget.user.latitude.toStringAsFixed(7)}, ${widget.user.longitude.toStringAsFixed(7)}",
                          style: TextStyle(
                            color: widget.subTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.track_changes,
                      label: "Track",
                      onClick: widget.onTrack,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.map,
                      label: "Mark zone",
                      onClick: widget.onMarkZone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.grid_view,
                      label: "My zones",
                      onClick: widget.onMyZones,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.person_remove,
                      label: "Unfriend",
                      onClick: widget.onUnfriend,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onClick;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onClick,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onClick,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1A1C1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F3F4),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: const Color(0xFF4A8DFF), size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
