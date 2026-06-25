class FriendUser {
  final String uid;
  final String name;
  final String email;
  final bool isAlreadyFriend;
  final bool hasSentRequest;
  final bool hasReceivedRequest;

  FriendUser({
    required this.uid,
    required this.name,
    required this.email,
    this.isAlreadyFriend = false,
    this.hasSentRequest = false,
    this.hasReceivedRequest = false,
  });

  FriendUser copyWith({
    String? uid,
    String? name,
    String? email,
    bool? isAlreadyFriend,
    bool? hasSentRequest,
    bool? hasReceivedRequest,
  }) {
    return FriendUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      isAlreadyFriend: isAlreadyFriend ?? this.isAlreadyFriend,
      hasSentRequest: hasSentRequest ?? this.hasSentRequest,
      hasReceivedRequest: hasReceivedRequest ?? this.hasReceivedRequest,
    );
  }
}
