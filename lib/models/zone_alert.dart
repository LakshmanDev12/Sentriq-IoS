class ZoneAlert {
  final String alertId;
  final String userId;
  final String zoneName;
  final String userName;
  final String type; // e.g., "Entered" or "Exited"
  final int timestamp;
  final String address;

  ZoneAlert({
    this.alertId = "",
    this.userId = "",
    this.zoneName = "",
    this.userName = "",
    this.type = "Entered",
    this.timestamp = 0,
    this.address = "",
  });

  Map<String, dynamic> toMap() {
    return {
      'alertId': alertId,
      'userId': userId,
      'zoneName': zoneName,
      'userName': userName,
      'type': type,
      'timestamp': timestamp,
      'address': address,
    };
  }

  factory ZoneAlert.fromMap(Map<dynamic, dynamic> map) {
    return ZoneAlert(
      alertId: map['alertId'] ?? map['id'] ?? '',
      userId: map['userId'] ?? '',
      zoneName: map['zoneName'] ?? '',
      userName: map['userName'] ?? '',
      type: map['type'] ?? 'Entered',
      timestamp: map['timestamp'] ?? 0,
      address: map['address'] ?? '',
    );
  }

  factory ZoneAlert.fromJson(Map<dynamic, dynamic> json) => ZoneAlert.fromMap(json);
}
