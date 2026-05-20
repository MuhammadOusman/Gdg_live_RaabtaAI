import 'package:equatable/equatable.dart';

class Listing extends Equatable {
  final String id;
  final String? ownerAgentId;
  final bool isPublic;
  final double? latitude;
  final double? longitude;
  final String? blockId;
  final String? subLocationRaw;
  final int? size;
  final String unit;
  final List<String> features;
  final int? demandPrice;
  final String status;
  final bool isHotProperty;
  final List<dynamic> notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Listing({
    required this.id,
    this.ownerAgentId,
    this.isPublic = false,
    this.latitude,
    this.longitude,
    this.blockId,
    this.subLocationRaw,
    this.size,
    this.unit = 'gaz',
    this.features = const [],
    this.demandPrice,
    this.status = 'active',
    this.isHotProperty = false,
    this.notes = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Listing.fromJson(Map<String, dynamic> json) {
    // Handle geo_point which could be a PostGIS point format
    double? lat;
    double? lng;

    final geoPoint = json['geo_point'];
    if (geoPoint != null) {
      if (geoPoint is Map) {
        lat = (geoPoint['lat'] ?? geoPoint['y'])?.toDouble();
        lng = (geoPoint['lng'] ?? geoPoint['x'])?.toDouble();
      } else if (geoPoint is List && geoPoint.length >= 2) {
        lng = (geoPoint[0])?.toDouble();
        lat = (geoPoint[1])?.toDouble();
      }
    }

    return Listing(
      id: json['id'] ?? '',
      ownerAgentId: json['owner_agent_id'],
      isPublic: json['is_public'] ?? false,
      latitude: lat,
      longitude: lng,
      blockId: json['block_id'],
      subLocationRaw: json['sub_location_raw'],
      size: json['size'],
      unit: json['unit'] ?? 'gaz',
      features: json['features'] is String 
          ? [json['features'] as String]
          : (json['features'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      demandPrice: json['demand_price'],
      status: json['status'] ?? 'active',
      isHotProperty: json['is_hot_property'] ?? false,
      notes: json['notes'] is String 
          ? [json['notes']]
          : List<dynamic>.from(json['notes'] ?? []),
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'owner_agent_id': ownerAgentId,
    'is_public': isPublic,
    'geo_point': latitude != null && longitude != null ? {'lat': latitude, 'lng': longitude} : null,
    'block_id': blockId,
    'sub_location_raw': subLocationRaw,
    'size': size,
    'unit': unit,
    'features': features,
    'demand_price': demandPrice,
    'status': status,
    'is_hot_property': isHotProperty,
    'notes': notes,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  Listing copyWith({
    String? id,
    String? ownerAgentId,
    bool? isPublic,
    double? latitude,
    double? longitude,
    String? blockId,
    String? subLocationRaw,
    int? size,
    String? unit,
    List<String>? features,
    int? demandPrice,
    String? status,
    bool? isHotProperty,
    List<dynamic>? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Listing(
    id: id ?? this.id,
    ownerAgentId: ownerAgentId ?? this.ownerAgentId,
    isPublic: isPublic ?? this.isPublic,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    blockId: blockId ?? this.blockId,
    subLocationRaw: subLocationRaw ?? this.subLocationRaw,
    size: size ?? this.size,
    unit: unit ?? this.unit,
    features: features ?? this.features,
    demandPrice: demandPrice ?? this.demandPrice,
    status: status ?? this.status,
    isHotProperty: isHotProperty ?? this.isHotProperty,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [
    id, ownerAgentId, isPublic, latitude, longitude, blockId, subLocationRaw,
    size, unit, features, demandPrice, status, isHotProperty, notes, createdAt, updatedAt,
  ];
}
