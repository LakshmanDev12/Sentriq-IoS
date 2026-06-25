import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/friend_user.dart';
import '../widgets/guardian_logo.dart';
import '../widgets/bottom_nav_bar.dart';
import '../utils/constants.dart';

class SearchFriendsScreen extends StatefulWidget {
  const SearchFriendsScreen({super.key});

  @override
  State<SearchFriendsScreen> createState() => _SearchFriendsScreenState();
}

class _SearchFriendsScreenState extends State<SearchFriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  String _searchText = "";
  List<FriendUser> _searchResults = [];
  List<FriendUser> _suggestedUsers = [];
  List<FriendUser> _friendsList = [];
  bool _isSearching = false;

  final Set<String> _myFriends = {};
  final Map<String, bool> _sentRequests = {};
  final Map<String, bool> _receivedRequests = {};

  StreamSubscription? _friendsSub;
  StreamSubscription? _receivedReqSub;
  StreamSubscription? _sentReqSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initListeners();
  }

  void _initListeners() {
    if (_myUid.isEmpty) return;

    // Listen to friends
    _friendsSub = _db.ref(AppConstants.friends).child(_myUid).onValue.listen((event) async {
      final snapshot = event.snapshot;
      _myFriends.clear();
      List<FriendUser> tempFriends = [];
      
      if (snapshot.value != null) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        for (var fid in data.keys) {
          _myFriends.add(fid.toString());
          final uSnap = await _db.ref(AppConstants.users).child(fid.toString()).get();
          if (uSnap.exists) {
            tempFriends.add(FriendUser(
              uid: fid.toString(),
              name: uSnap.child("name").value?.toString() ?? "User",
              email: uSnap.child("email").value?.toString() ?? "",
              isAlreadyFriend: true,
            ));
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _friendsList = tempFriends;
        });
        _loadSuggestions();
      }
    });

    // Listen to received friend requests
    _receivedReqSub = _db.ref(AppConstants.friendRequests).child(_myUid).onValue.listen((event) {
      final snapshot = event.snapshot;
      _receivedRequests.clear();
      if (snapshot.value != null) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        for (var key in data.keys) {
          _receivedRequests[key.toString()] = true;
        }
      }
      if (mounted) setState(() {});
    });

    // Listen to all friend requests to find sent ones (as per Kotlin logic)
    _sentReqSub = _db.ref(AppConstants.friendRequests).onValue.listen((event) {
      final snapshot = event.snapshot;
      _sentRequests.clear();
      if (snapshot.value != null) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((targetUid, requests) {
          if (requests is Map && requests.containsKey(_myUid)) {
            _sentRequests[targetUid.toString()] = true;
          }
        });
      }
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadSuggestions() async {
    if (_myFriends.isEmpty) {
      if (mounted) setState(() => _suggestedUsers = []);
      return;
    }

    Set<String> potentialUids = {};
    for (var fid in _myFriends) {
      final snapshot = await _db.ref(AppConstants.friends).child(fid).get();
      if (snapshot.value != null) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        for (var key in data.keys) {
          String potentialUid = key.toString();
          if (potentialUid != _myUid && !_myFriends.contains(potentialUid)) {
            potentialUids.add(potentialUid);
          }
        }
      }
    }

    List<FriendUser> tempSug = [];
    for (var uid in potentialUids) {
      final uSnap = await _db.ref(AppConstants.users).child(uid).get();
      if (uSnap.exists) {
        tempSug.add(FriendUser(
          uid: uid,
          name: uSnap.child("name").value?.toString() ?? "User",
          email: uSnap.child("email").value?.toString() ?? "",
        ));
      }
    }
    
    if (mounted) {
      setState(() {
        tempSug.shuffle();
        _suggestedUsers = tempSug.take(5).toList();
      });
    }
  }

  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchText = "";
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _searchText = query;
      _isSearching = true;
    });

    final snapshot = await _db.ref(AppConstants.users).get();
    List<FriendUser> res = [];
    if (snapshot.value != null) {
      final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((uid, userData) {
        if (uid.toString() == _myUid) return;
        String name = userData['name']?.toString() ?? "";
        String email = userData['email']?.toString() ?? "";
        
        if (name.toLowerCase().contains(query.toLowerCase()) || 
            email.toLowerCase().contains(query.toLowerCase())) {
          res.add(FriendUser(
            uid: uid.toString(),
            name: name,
            email: email,
            isAlreadyFriend: _myFriends.contains(uid.toString()),
            hasSentRequest: _sentRequests[uid.toString()] == true,
            hasReceivedRequest: _receivedRequests[uid.toString()] == true,
          ));
        }
      });
    }

    if (mounted) {
      setState(() {
        _searchResults = res;
        _isSearching = false;
      });
    }
  }

  void _showConfirmation(String title, String message, VoidCallback action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A8DFF),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              action();
              Navigator.pop(context);
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _friendsSub?.cancel();
    _receivedReqSub?.cancel();
    _sentReqSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pushReplacementNamed(context, 'dashboard'),
        ),
        title: const Text(
          "Discover People",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4A8DFF),
          labelColor: const Color(0xFF4A8DFF),
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          tabs: const [
            Tab(text: "Discover"),
            Tab(text: "Friends"),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildDiscoverTab(),
              _buildFriendsTab(),
            ],
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: BottomNavBar(currentIndex: 2),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            onChanged: _performSearch,
            decoration: InputDecoration(
              hintText: "Search by name or email",
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFFF1F3F4).withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              if (_searchText.isNotEmpty) ...[
                Row(
                  children: [
                    const Text("Search Results", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 14)),
                    if (_isSearching) ...[
                      const SizedBox(width: 8),
                      const SizedBox(width: 24, height: 24, child: AnimatedGuardianLogo(size: 24, showWordmark: false)),
                    ]
                  ],
                ),
                const SizedBox(height: 12),
                if (_searchResults.isEmpty && !_isSearching)
                  Text("No users found matching \"$_searchText\"", style: const TextStyle(color: Colors.grey))
                else
                  ..._searchResults.map((user) => DiscoveryCard(
                    user: user.copyWith(
                      isAlreadyFriend: _myFriends.contains(user.uid),
                      hasSentRequest: _sentRequests[user.uid] == true,
                      hasReceivedRequest: _receivedRequests[user.uid] == true,
                    ),
                    onSend: (uid, name) => _showConfirmation("Send Friend Request", "Are you sure you want to send a friend request to $name?", () {
                      _db.ref(AppConstants.friendRequests).child(uid).child(_myUid).set(true);
                    }),
                    onAccept: (uid, name) => _showConfirmation("Accept Request", "Do you want to accept $name's friend request?", () {
                      _db.ref(AppConstants.friends).child(_myUid).child(uid).set(true);
                      _db.ref(AppConstants.friends).child(uid).child(_myUid).set(true);
                      _db.ref(AppConstants.friendRequests).child(_myUid).child(uid).remove();
                    }),
                    onReject: (uid, name) => _showConfirmation("Reject Request", "Are you sure you want to reject $name's request?", () {
                      _db.ref(AppConstants.friendRequests).child(_myUid).child(uid).remove();
                    }),
                  )),
              ] else ...[
                const Text("People you may know", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 12),
                if (_suggestedUsers.isEmpty)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60),
                      const AnimatedGuardianLogo(size: 150),
                      const SizedBox(height: 16),
                      const Text("Finding suggestions...", style: TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  )
                else
                  ..._suggestedUsers.map((user) => DiscoveryCard(
                    user: user.copyWith(
                      isAlreadyFriend: _myFriends.contains(user.uid),
                      hasSentRequest: _sentRequests[user.uid] == true,
                      hasReceivedRequest: _receivedRequests[user.uid] == true,
                    ),
                    onSend: (uid, name) => _showConfirmation("Send Friend Request", "Are you sure you want to send a friend request to $name?", () {
                      _db.ref(AppConstants.friendRequests).child(uid).child(_myUid).set(true);
                    }),
                    onAccept: (uid, name) => _showConfirmation("Accept Request", "Do you want to accept $name's friend request?", () {
                      _db.ref(AppConstants.friends).child(_myUid).child(uid).set(true);
                      _db.ref(AppConstants.friends).child(uid).child(_myUid).set(true);
                      _db.ref(AppConstants.friendRequests).child(_myUid).child(uid).remove();
                    }),
                    onReject: (uid, name) => _showConfirmation("Reject Request", "Are you sure you want to reject $name's request?", () {
                      _db.ref(AppConstants.friendRequests).child(_myUid).child(uid).remove();
                    }),
                  )),
              ],
              const SizedBox(height: 100),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFriendsTab() {
    if (_friendsList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AnimatedGuardianLogo(size: 150),
            const SizedBox(height: 16),
            const Text("No friends added yet", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _friendsList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => DiscoveryCard(
        user: _friendsList[index],
        onSend: (_, __) {},
        onAccept: (_, __) {},
        onReject: (_, __) {},
      ),
    );
  }
}

class DiscoveryCard extends StatelessWidget {
  final FriendUser user;
  final Function(String, String) onSend;
  final Function(String, String) onAccept;
  final Function(String, String) onReject;

  const DiscoveryCard({
    super.key,
    required this.user,
    required this.onSend,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFF1F3F4),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : "?",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A8DFF)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                user.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            _buildAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildAction() {
    if (user.isAlreadyFriend) {
      return const Text(
        "Friend",
        style: TextStyle(color: Color(0xFF2ECC71), fontWeight: FontWeight.bold, fontSize: 13),
      );
    }
    if (user.hasReceivedRequest) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => onReject(user.uid, user.name),
            icon: const Icon(Icons.close, color: Colors.red),
          ),
          IconButton(
            onPressed: () => onAccept(user.uid, user.name),
            icon: const Icon(Icons.check, color: Color(0xFF2ECC71)),
          ),
        ],
      );
    }
    if (user.hasSentRequest) {
      return const Text(
        "Requested",
        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
      );
    }
    return IconButton(
      onPressed: () => onSend(user.uid, user.name),
      icon: const Icon(Icons.person_add, color: Color(0xFF4A8DFF)),
    );
  }
}
