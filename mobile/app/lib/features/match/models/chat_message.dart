import 'package:flutter/foundation.dart';

enum MessageType { text, audio, image }

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    this.text,
    this.audioPath,
    this.mediaLabel,
    required this.timestamp,
    this.type = MessageType.text,
  });

  final String id;
  final String sender; // 'me' or 'them' for now
  final String? text;
  final String? audioPath;
  final String? mediaLabel;
  final DateTime timestamp;
  final MessageType type;
}
