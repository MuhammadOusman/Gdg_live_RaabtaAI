import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import 'models/chat_message.dart';
import 'services/recording_path.dart';
import 'services/voice_note_transcriber.dart';
import '../../services/api_service.dart';

class ChatController extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  final Record _recorder = Record();
  final VoiceNoteTranscriber _transcriber = VoiceNoteTranscriber();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ApiService _apiService = ApiService();

  bool _isRecording = false;
  int _recordingDuration = 0;
  Timer? _recordingTimer;

  String? _playingMessageId;
  bool _isPlayingAudio = false;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;

  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _completeSub;

  ChatController() {
    _seedConversation();
    _initAudioPlayer();
  }

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isRecording => _isRecording;
  int get recordingDuration => _recordingDuration;

  String? get playingMessageId => _playingMessageId;
  bool get isPlayingAudio => _isPlayingAudio;
  Duration get audioPosition => _audioPosition;
  Duration get audioDuration => _audioDuration;

  final _uuid = const Uuid();

  void _initAudioPlayer() {
    _positionSub = _audioPlayer.onPositionChanged.listen((pos) {
      _audioPosition = pos;
      notifyListeners();
    });

    _durationSub = _audioPlayer.onDurationChanged.listen((dur) {
      if (dur != Duration.zero) {
        _audioDuration = dur;
        notifyListeners();
      }
    });

    _completeSub = _audioPlayer.onPlayerComplete.listen((_) {
      _isPlayingAudio = false;
      _audioPosition = Duration.zero;
      _playingMessageId = null;
      notifyListeners();
    });
  }

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

  Future<void> sendText(String text) async {
    final msg = ChatMessage(
      id: _uuid.v4(),
      sender: 'me',
      text: text,
      timestamp: DateTime.now(),
      type: MessageType.text,
    );
    _messages.insert(0, msg);
    notifyListeners();

    try {
      final response = await _apiService.sendMessage(text, source: 'app');
      _handleAgentResponse(response);
    } catch (e) {
      debugPrint('Error sending message to agent: $e');
    }
  }

  void _handleAgentResponse(Map<String, dynamic> response) {
    String? replyText;

    if (response['status'] == 'market_query_result') {
       replyText = response['advice'];
    } else if (response['status'] == 'listing_saved') {
       replyText = response['preview'];
    } else if (response['status'] == 'demand_saved') {
       replyText = response['preview'];
    } else if (response['status'] == 'conflict') {
       replyText = response['conflict_message'];
    } else if (response['status'] == 'awaiting_confirm') {
       replyText = response['preview'];
    } else if (response['message'] != null) {
       replyText = response['message'];
    }

    if (replyText != null) {
      final reply = ChatMessage(
        id: _uuid.v4(),
        sender: 'them',
        text: replyText,
        timestamp: DateTime.now(),
        type: MessageType.text,
      );
      _messages.insert(0, reply);
      notifyListeners();
    }
  }

  Future<void> startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      return;
    }

    final path = createRecordingPath(_uuid.v4());
    await _recorder.start(path: path, encoder: AudioEncoder.aacLc);
    _isRecording = true;
    _recordingDuration = 0;
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _recordingDuration++;
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    final path = await _recorder.stop();
    _isRecording = false;
    _recordingDuration = 0;

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
      notifyListeners();

      if (transcript.isNotEmpty) {
        try {
          final response = await _apiService.sendMessage(transcript, source: 'app');
          _handleAgentResponse(response);
        } catch (e) {
          debugPrint('Error sending voice transcript to agent: $e');
        }
      }
    }
    notifyListeners();
  }

  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    await _recorder.stop();
    _isRecording = false;
    _recordingDuration = 0;
    notifyListeners();
  }

  Future<void> playAudio(String messageId, String path) async {
    if (_playingMessageId == messageId) {
      if (_isPlayingAudio) {
        await _audioPlayer.pause();
        _isPlayingAudio = false;
      } else {
        await _audioPlayer.resume();
        _isPlayingAudio = true;
      }
    } else {
      await _audioPlayer.stop();
      _playingMessageId = messageId;
      _audioPosition = Duration.zero;
      _audioDuration = Duration.zero;
      _isPlayingAudio = true;
      await _audioPlayer.play(DeviceFileSource(File(path).path));
    }
    notifyListeners();
  }

  Future<void> seekAudio(Duration position) async {
    if (_playingMessageId != null) {
      await _audioPlayer.seek(position);
    }
  }

  void addIncoming(ChatMessage message) {
    _messages.insert(0, message);
    notifyListeners();
  }

  void clear() {
    _messages.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completeSub?.cancel();
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}
