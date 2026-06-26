import 'package:latlong2/latlong.dart';

/// Sebuah titik/spot mancing yang dipilih pengguna.
class FishingSpot {
  final String id;
  final String name;
  final LatLng location;
  final DateTime createdAt;

  FishingSpot({
    required this.id,
    required this.name,
    required this.location,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  FishingSpot copyWith({String? name, LatLng? location}) => FishingSpot(
        id: id,
        name: name ?? this.name,
        location: location ?? this.location,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': location.latitude,
        'lng': location.longitude,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FishingSpot.fromJson(Map<String, dynamic> json) => FishingSpot(
        id: json['id'] as String,
        name: json['name'] as String,
        location: LatLng(
          (json['lat'] as num).toDouble(),
          (json['lng'] as num).toDouble(),
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
