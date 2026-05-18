import 'package:equatable/equatable.dart';

class Agent extends Equatable {
  final String id;
  final String name;
  final String? agencyName;
  final List<String> workAreas;
  final int publicListingsCount;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Agent({
    required this.id,
    required this.name,
    this.agencyName,
    this.workAreas = const [],
    this.publicListingsCount = 0,
    this.isVerified = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      agencyName: json['agency_name'],
      workAreas: List<String>.from(json['work_areas'] ?? []),
      publicListingsCount: json['public_listings_count'] ?? 0,
      isVerified: json['is_verified'] ?? false,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'agency_name': agencyName,
    'work_areas': workAreas,
    'public_listings_count': publicListingsCount,
    'is_verified': isVerified,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  Agent copyWith({
    String? id,
    String? name,
    String? agencyName,
    List<String>? workAreas,
    int? publicListingsCount,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Agent(
    id: id ?? this.id,
    name: name ?? this.name,
    agencyName: agencyName ?? this.agencyName,
    workAreas: workAreas ?? this.workAreas,
    publicListingsCount: publicListingsCount ?? this.publicListingsCount,
    isVerified: isVerified ?? this.isVerified,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [id, name, agencyName, workAreas, publicListingsCount, isVerified, createdAt, updatedAt];
}
