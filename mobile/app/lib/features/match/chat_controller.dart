import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import 'models/chat_message.dart';
import 'services/recording_path.dart';
import 'services/voice_note_transcriber.dart';

class ChatController extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  final Record _recorder = Record();
  final VoiceNoteTranscriber _transcriber = VoiceNoteTranscriber();
  bool _isRecording = false;

  ChatController() {
    _seedConversation();
  }

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isRecording => _isRecording;

  final _uuid = const Uuid();

  void _seedConversation() {
    if (_messages.isNotEmpty) {
      return;
    }

    _messages.addAll([
      ChatMessage(
        id: _uuid.v4(),
        sender: 'them',
        type: MessageType.image,
        mediaLabel: 'Shared preview',
        text: 'Looks good. Send the voice note too.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 18)),
      ),
      ChatMessage(
        id: _uuid.v4(),
        sender: 'me',
        text: 'loru',
        timestamp: DateTime.now().subtract(const Duration(minutes: 9)),
      ),
      ChatMessage(
        id: _uuid.v4(),
        sender: 'them',
        type: MessageType.audio,
        audioPath: null,
        text: 'Voice note',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      ChatMessage(
        id: _uuid.v4(),
        sender: 'me',
        text: '.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
    ]);
  }

  void sendText(String text) {
    final msg = ChatMessage(
      id: _uuid.v4(),
      sender: 'me',
      text: text,
      timestamp: DateTime.now(),
      type: MessageType.text,
    );
    _messages.insert(0, msg);
    notifyListeners();
  }

  Future<void> startRecording() async {
    if (await _recorder.hasPermission()) {
      final path = createRecordingPath(_uuid.v4());
      await _recorder.start(path: path, encoder: AudioEncoder.aacLc);
      _isRecording = true;
      notifyListeners();
    }
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;
    final path = await _recorder.stop();
    _isRecording = false;
    if (path != null) {
      final transcript = await _transcriber.transcribeVoiceMessage(path);
      final msg = ChatMessage(
        id: _uuid.v4(),
        sender: 'me',
        audioPath: path,
        text: transcript.isNotEmpty ? transcript : 'Voice note',
        timestamp: DateTime.now(),
        type: MessageType.audio,
      );
      _messages.insert(0, msg);
    }
    notifyListeners();
  }

  void addIncoming(ChatMessage message) {
    _messages.insert(0, message);
    notifyListeners();
  }

  void clear() {
    _messages.clear();
    notifyListeners();
  }
}
