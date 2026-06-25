class UserModel {
  final String uid;
  final String name;
  final String email;
  final double latitude;
  final double longitude;
  final String address;
  final bool isSharing;
  final String zoneStatus;
  final int lastUpdated;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.address = "",
    this.isSharing = false,
    this.zoneStatus = "OUTSIDE",
    this.lastUpdated = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'isSharing': isSharing,
      'zoneStatus': zoneStatus,
      'lastUpdated': lastUpdated,
    };
  }

  factory UserModel.fromMap(Map<dynamic, dynamic> map) {
    return UserModel(
      uid: map["uid"] ?? "",
      name: map["name"] ?? "",
      email: map["email"] ?? "",
      latitude: (map["latitude"] ?? 0.0).toDouble(),
      longitude: (map["longitude"] ?? 0.0).toDouble(),
      address: map["address"] ?? "",
      isSharing: map["isSharing"] ?? false,
      zoneStatus: map["zoneStatus"] ?? "OUTSIDE",
      lastUpdated: map["lastUpdated"] ?? 0,
    );
  }

  factory UserModel.fromJson(Map<dynamic, dynamic> json) => UserModel.fromMap(json);
}
