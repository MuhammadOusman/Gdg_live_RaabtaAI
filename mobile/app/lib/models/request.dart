import 'package:equatable/equatable.dart';

class Request extends Equatable {
  final String id;
  final String? buyerAgentId;
  final List<String> targetBlocks;
  final int? targetSize;
  final String unit;
  final List<String> targetFeatures;
  final int? maxBudget;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Request({
    required this.id,
    this.buyerAgentId,
    this.targetBlocks = const [],
    this.targetSize,
    this.unit = 'gaz',
    this.targetFeatures = const [],
    this.maxBudget,
    this.status = 'searching',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Request.fromJson(Map<String, dynamic> json) {
    return Request(
      id: json['id'] ?? '',
      buyerAgentId: json['buyer_agent_id'],
      targetBlocks: List<String>.from(json['target_blocks'] ?? []),
      targetSize: json['target_size'],
      unit: json['unit'] ?? 'gaz',
      targetFeatures: List<String>.from(json['target_features'] ?? []),
      maxBudget: json['max_budget'],
      status: json['status'] ?? 'searching',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'buyer_agent_id': buyerAgentId,
    'target_blocks': targetBlocks,
    'target_size': targetSize,
    'unit': unit,
    'target_features': targetFeatures,
    'max_budget': maxBudget,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  Request copyWith({
    String? id,
    String? buyerAgentId,
    List<String>? targetBlocks,
    int? targetSize,
    String? unit,
    List<String>? targetFeatures,
    int? maxBudget,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Request(
    id: id ?? this.id,
    buyerAgentId: buyerAgentId ?? this.buyerAgentId,
    targetBlocks: targetBlocks ?? this.targetBlocks,
    targetSize: targetSize ?? this.targetSize,
    unit: unit ?? this.unit,
    targetFeatures: targetFeatures ?? this.targetFeatures,
    maxBudget: maxBudget ?? this.maxBudget,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [
    id, buyerAgentId, targetBlocks, targetSize, unit, targetFeatures,
    maxBudget, status, createdAt, updatedAt,
  ];
}
