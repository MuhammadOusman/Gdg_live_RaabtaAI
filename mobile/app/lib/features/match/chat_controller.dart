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
  Map<String, dynamic>? _pendingParsed;
  String? _pendingSessionId;

  ChatController() {
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

    await _processOutgoingText(text);
  }

  Future<void> _processOutgoingText(String text) async {
    try {
      final normalized = text.toLowerCase().trim();
      final isPublicConfirm =
          normalized == 'confirm public' ||
          normalized == 'public' ||
          normalized == '1';
      final isPrivateConfirm =
          normalized == 'confirm private' ||
          normalized == 'private' ||
          normalized == '2' ||
          normalized == 'confirm' ||
          normalized == 'yes' ||
          normalized == 'confirmed';

      if ((isPublicConfirm || isPrivateConfirm) &&
          _pendingParsed != null &&
          _pendingSessionId != null) {
        final parsed = Map<String, dynamic>.from(_pendingParsed!);
        parsed['is_public'] = isPublicConfirm;
        _pendingParsed = null;
        final sessionId = _pendingSessionId!;
        _pendingSessionId = null;
        final response = await _apiService.confirmMessage(
          parsedData: parsed,
          sessionId: sessionId,
        );
        _handleAgentResponse(response, isConfirmationResponse: true);
        return;
      }

      final response = await _apiService.sendMessage(text, source: 'app');
      _handleAgentResponse(response, isConfirmationResponse: false);
    } catch (e) {
      debugPrint('Error sending message to agent: $e');
    }
  }

  void _handleAgentResponse(
    Map<String, dynamic> response, {
    required bool isConfirmationResponse,
  }) {
    String? replyText;

    if (response['status'] == 'market_query_result') {
      final stats = response['stats'] as Map<String, dynamic>? ?? {};
      final ratio = stats['demand_ratio'];
      final ratioText = ratio is num ? ratio.toStringAsFixed(2) : '$ratio';
      replyText =
          'Recommender Insights:\n\n'
          '${response['advice'] ?? ''}\n\n'
          'Stats for ${response['block_id'] ?? 'this block'}:\n'
          'Supply: ${stats['supply'] ?? 0} plots\n'
          'Demand: ${stats['demand'] ?? 0} requests\n'
          'Ratio: ${ratioText == 'null' ? '0' : ratioText}';
    } else if (response['status'] == 'listing_saved') {
      if (isConfirmationResponse) {
        final parsed = response['parsed_data'] as Map<String, dynamic>?;
        final isPublic = parsed?['is_public'] == true;
        final count = response['matches_count'] as int? ?? 0;
        if (isPublic) {
          replyText = count > 0
              ? 'Listing saved publicly. We found $count matching buyer(s) and notified them.'
              : 'Listing saved publicly. No matching buyers right now, we will alert you on match.';
        } else {
          replyText = 'Listing saved privately in your Vault.';
        }
      } else {
        replyText =
            'Listing saved successfully in our system. Matchmaker is scanning for buyers...';
      }
    } else if (response['status'] == 'demand_saved') {
      final matches = response['matches'] as List<dynamic>?;
      replyText =
          'Searching... Demand saved. We found ${matches?.length ?? 0} immediate matches.';
    } else if (response['status'] == 'conflict') {
      replyText = 'Conflict Detected:\n${response['conflict_message'] ?? ''}';
    } else if (response['status'] == 'awaiting_confirm') {
      _pendingParsed = response['parsed'] as Map<String, dynamic>?;
      _pendingSessionId = response['session_id']?.toString();
      final parsed = _pendingParsed ?? const <String, dynamic>{};
      final features = parsed['features'] as List<dynamic>?;
      final featuresText = (features != null && features.isNotEmpty)
          ? '\nFeatures: ${features.join(', ')}'
          : '';
      final demandPrice = parsed['demand_price'];
      replyText =
          'Please Confirm:\n\n'
          'Block: ${parsed['block_id'] ?? ''}\n'
          'Size: ${parsed['size'] ?? ''}gz\n'
          'Demand: PKR ${demandPrice ?? ''}$featuresText\n\n'
          'Choose Visibility:\n'
          '1. Reply "confirm public"\n'
          '2. Reply "confirm private"';
    } else if (response['message'] != null) {
      replyText = response['message']?.toString();
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
        await _processOutgoingText(transcript);
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
