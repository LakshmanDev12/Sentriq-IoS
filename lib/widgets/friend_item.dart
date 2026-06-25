import 'package:flutter/material.dart';
import '../models/user.dart';

class FriendItem extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;

  const FriendItem({
    super.key,
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarColor = user.isSharing ? Colors.green : Colors.grey;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: avatarColor.withOpacity(0.2),
        child: Text(
          user.name.isNotEmpty ? user.name[0].toUpperCase() : "?",
          style: TextStyle(
            color: avatarColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        user.name,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        user.isSharing ? "Online" : "Offline",
      ),
      trailing: const Icon(
        Icons.location_on,
        color: Colors.blue,
      ),
    );
  }
}
