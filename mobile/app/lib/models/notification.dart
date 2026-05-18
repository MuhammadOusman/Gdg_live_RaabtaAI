import 'package:equatable/equatable.dart';

class Notification extends Equatable {
  final String id;
  final String? agentId;
  final String? listingId;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic> payload;
  final String type;

  const Notification({
    required this.id,
    this.agentId,
    this.listingId,
    required this.message,
    this.isRead = false,
    required this.createdAt,
    this.payload = const {},
    this.type = 'listing_update',
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] ?? '',
      agentId: json['agent_id'],
      listingId: json['listing_id'],
      message: json['message'] ?? '',
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      payload: json['payload'] ?? {},
      type: json['type'] ?? 'listing_update',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'agent_id': agentId,
    'listing_id': listingId,
    'message': message,
    'is_read': isRead,
    'created_at': createdAt.toIso8601String(),
    'payload': payload,
    'type': type,
  };

  Notification copyWith({
    String? id,
    String? agentId,
    String? listingId,
    String? message,
    bool? isRead,
    DateTime? createdAt,
    Map<String, dynamic>? payload,
    String? type,
  }) => Notification(
    id: id ?? this.id,
    agentId: agentId ?? this.agentId,
    listingId: listingId ?? this.listingId,
    message: message ?? this.message,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt ?? this.createdAt,
    payload: payload ?? this.payload,
    type: type ?? this.type,
  );

  @override
  List<Object?> get props => [id, agentId, listingId, message, isRead, createdAt, payload, type];
}
