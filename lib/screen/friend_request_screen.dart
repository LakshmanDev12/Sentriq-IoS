import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/friend_user.dart';
import '../widgets/guardian_logo.dart';
import '../widgets/bottom_nav_bar.dart';

class FriendRequestScreen extends StatefulWidget {
  const FriendRequestScreen({super.key});

  @override
  State<FriendRequestScreen> createState() => _FriendRequestScreenState();
}

class _FriendRequestScreenState extends State<FriendRequestScreen> {
  final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  List<FriendUser> _requests = [];
  StreamSubscription? _requestsSub;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initListener();
  }

  void _initListener() {
    if (_myUid.isEmpty) return;

    _requestsSub = _db.ref("friend_requests").child(_myUid).onValue.listen((event) async {
      final snapshot = event.snapshot;
      if (!snapshot.exists) {
        if (mounted) setState(() { _requests = []; _isLoading = false; });
        return;
      }

      List<FriendUser> temp = [];
      final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      
      for (var senderUid in data.keys) {
        final userSnapshot = await _db.ref("users").child(senderUid.toString()).get();
        final name = userSnapshot.child("name").value?.toString() ?? "User";
        final email = userSnapshot.child("email").value?.toString() ?? "";
        
        final friendSnapshot = await _db.ref("friends").child(_myUid).child(senderUid.toString()).get();
        
        temp.add(FriendUser(
          uid: senderUid.toString(),
          name: name,
          email: email,
          isAlreadyFriend: friendSnapshot.exists,
        ));
      }

      if (mounted) {
        setState(() {
          _requests = temp;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _acceptRequest(String senderUid) async {
    await _db.ref("friends").child(_myUid).child(senderUid).set(true);
    await _db.ref("friends").child(senderUid).child(_myUid).set(true);
    await _db.ref("friend_requests").child(_myUid).child(senderUid).remove();
  }

  Future<void> _rejectRequest(String senderUid) async {
    await _db.ref("friend_requests").child(_myUid).child(senderUid).remove();
  }

  void _showConfirmation(String title, String message, VoidCallback action, {bool isDestructive = false}) {
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
              backgroundColor: isDestructive ? Colors.red : const Color(0xFF3F51B5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    _requestsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pushReplacementNamed(context, 'dashboard'),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Friend requests",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading 
                ? const Center(child: AnimatedGuardianLogo(size: 150))
                : _requests.isEmpty 
                  ? _buildEmptyState() 
                  : _buildRequestList(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AnimatedGuardianLogo(size: 150),
          const SizedBox(height: 16),
          const Text("No pending requests", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildRequestList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        final request = _requests[index];
        return _buildRequestItem(request);
      },
    );
  }

  Widget _buildRequestItem(FriendUser request) {
    final String initials = request.name.length >= 2 
        ? request.name.substring(0, 2).toUpperCase() 
        : request.name.toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Color(0xFFE8EAF6),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Color(0xFF3F51B5),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Request from",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                Text(
                  request.name,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (request.isAlreadyFriend)
          Row(
            children: const [
              Icon(Icons.check, color: Color(0xFF4CAF50), size: 16),
              SizedBox(width: 8),
              Text("Already friends", style: TextStyle(color: Color(0xFF4CAF50))),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showConfirmation(
                    "Accept Request", 
                    "Do you want to accept ${request.name}'s friend request?", 
                    () => _acceptRequest(request.uid)
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text("Accept"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3F51B5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showConfirmation(
                    "Reject Request", 
                    "Are you sure you want to reject ${request.name}'s request?", 
                    () => _rejectRequest(request.uid),
                    isDestructive: true
                  ),
                  icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                  label: const Text("Reject", style: TextStyle(color: Colors.grey)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        const Divider(color: Colors.grey, thickness: 0.2),
      ],
    );
  }
}
