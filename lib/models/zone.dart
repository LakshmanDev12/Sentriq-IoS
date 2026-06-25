class Zone {
  final String zoneId;
  final String ownerUid;
  final String friendUid;
  final String friendName;
  final String name;
  final String type;
  final double latitude;
  final double longitude;
  final double radius;
  final String status;
  final String address;
  final int createdAt;

  Zone({
    required this.zoneId,
    required this.ownerUid,
    required this.friendUid,
    required this.friendName,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.status,
    required this.address,
    required this.createdAt,
  });

  factory Zone.fromMap(Map<dynamic, dynamic> map) {
    return Zone(
      zoneId: map["zoneId"] ?? "",
      ownerUid: map["ownerUid"] ?? "",
      friendUid: map["friendUid"] ?? "",
      friendName: map["friendName"] ?? "",
      name: map["name"] ?? "",
      type: map["type"] ?? "Custom",
      latitude: (map["latitude"] ?? 0).toDouble(),
      longitude: (map["longitude"] ?? 0).toDouble(),
      radius: (map["radius"] ?? 0).toDouble(),
      status: map["status"] ?? "OUTSIDE",
      address: map["address"] ?? "Zone Location",
      createdAt: map["createdAt"] ?? 0,
    );
  }
}
