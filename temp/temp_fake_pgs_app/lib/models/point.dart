class Point {
  final double latitude;
  final double longitude;
  final int timestamp;

  Point({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory Point.fromJson(Map<String, dynamic> json) {
    return Point(
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      timestamp: json['timestamp'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "latitude": latitude,
      "longitude": longitude,
      "timestamp": timestamp,
    };
  }

  @override
  String toString() {
    return 'Point(lat: $latitude, lng: $longitude, time: $timestamp)';
  }
}