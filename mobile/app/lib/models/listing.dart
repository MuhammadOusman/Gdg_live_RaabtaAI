import 'package:equatable/equatable.dart';
import 'dart:typed_data';

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
    double? toDoubleValue(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    bool toBoolValue(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final lower = value.trim().toLowerCase();
        return lower == 'true' || lower == '1' || lower == 'public';
      }
      return false;
    }

    // Handle geo_point which could be a PostGIS point format
    double? lat;
    double? lng;
    ({double? lat, double? lng})? parseWkbHexPoint(String hex) {
      try {
        if (hex.length < 42) return null;
        final bytes = Uint8List.fromList(
          List<int>.generate(
            hex.length ~/ 2,
            (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
          ),
        );
        if (bytes.length < 1 + 4 + 16) return null;

        final endian = bytes[0] == 0 ? Endian.big : Endian.little;
        final data = ByteData.sublistView(bytes);
        final typeWithFlags = data.getUint32(1, endian);
        final hasSrid = (typeWithFlags & 0x20000000) != 0;
        final geomType = typeWithFlags & 0xFF;
        if (geomType != 1) return null;

        var offset = 1 + 4;
        if (hasSrid) offset += 4;
        if (bytes.length < offset + 16) return null;

        final lngValue = data.getFloat64(offset, endian);
        final latValue = data.getFloat64(offset + 8, endian);
        return (lat: latValue, lng: lngValue);
      } catch (_) {
        return null;
      }
    }

    final geoPoint = json['geo_point'];
    if (geoPoint != null) {
      if (geoPoint is Map) {
        if (geoPoint.containsKey('coordinates')) {
          final coords = geoPoint['coordinates'];
          if (coords is List && coords.length >= 2) {
            lng = (coords[0])?.toDouble();
            lat = (coords[1])?.toDouble();
          }
        } else {
          lat = (geoPoint['lat'] ?? geoPoint['y'])?.toDouble();
          lng = (geoPoint['lng'] ?? geoPoint['x'])?.toDouble();
        }
      } else if (geoPoint is List && geoPoint.length >= 2) {
        lng = (geoPoint[0])?.toDouble();
        lat = (geoPoint[1])?.toDouble();
      } else if (geoPoint is String) {
        final regExp = RegExp(
          r'POINT\s*\(\s*([0-9.-]+)\s+([0-9.-]+)\s*\)',
          caseSensitive: false,
        );
        final match = regExp.firstMatch(geoPoint);
        if (match != null && match.groupCount >= 2) {
          // PostGIS uses (Longitude, Latitude) order.
          // However, if the user reports placement issues, they might be stored as (lat, lng).
          // Heuristic for Karachi: Latitude ~24.9, Longitude ~67.1
          final first = double.tryParse(match.group(1) ?? '');
          final second = double.tryParse(match.group(2) ?? '');

          if (first != null && second != null) {
            // Check which one is closer to Karachi's typical longitude (~67)
            if ((first - 67.0).abs() < (second - 67.0).abs()) {
              lng = first;
              lat = second;
            } else {
              lat = first;
              lng = second;
            }
          }
        } else if (RegExp(r'^[0-9A-Fa-f]+$').hasMatch(geoPoint)) {
          final point = parseWkbHexPoint(geoPoint);
          lat = point?.lat;
          lng = point?.lng;
        }
      }
    }

    // Fallback to direct coordinate fields when geo_point is absent.
    lat ??= toDoubleValue(json['latitude'] ?? json['lat']);
    lng ??= toDoubleValue(json['longitude'] ?? json['lng'] ?? json['lon']);

    final visibilityRaw = json['visibility'];
    final isPublic = json.containsKey('is_public')
        ? toBoolValue(json['is_public'])
        : json.containsKey('isPublic')
        ? toBoolValue(json['isPublic'])
        : json.containsKey('public')
        ? toBoolValue(json['public'])
        : (visibilityRaw is String
              ? visibilityRaw.toLowerCase() == 'public'
              : true);

    return Listing(
      id: json['id'] ?? '',
      ownerAgentId: json['owner_agent_id'],
      isPublic: isPublic,
      latitude: lat,
      longitude: lng,
      blockId: json['block_id'],
      subLocationRaw: json['sub_location_raw'],
      size: json['size'],
      unit: json['unit'] ?? 'gaz',
      features: json['features'] is String
          ? [json['features'] as String]
          : (json['features'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
      demandPrice: json['demand_price'],
      status: json['status'] ?? 'active',
      isHotProperty: json['is_hot_property'] ?? false,
      notes: json['notes'] is String
          ? [json['notes']]
          : List<dynamic>.from(json['notes'] ?? []),
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'owner_agent_id': ownerAgentId,
    'is_public': isPublic,
    'geo_point': latitude != null && longitude != null
        ? {'lat': latitude, 'lng': longitude}
        : null,
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
    id,
    ownerAgentId,
    isPublic,
    latitude,
    longitude,
    blockId,
    subLocationRaw,
    size,
    unit,
    features,
    demandPrice,
    status,
    isHotProperty,
    notes,
    createdAt,
    updatedAt,
  ];
}
