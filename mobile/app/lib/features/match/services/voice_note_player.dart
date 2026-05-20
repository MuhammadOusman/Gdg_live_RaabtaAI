import 'voice_note_player_stub.dart'
    if (dart.library.html) 'voice_note_player_web.dart';

class VoiceNotePlayer {
  const VoiceNotePlayer();

  Future<void> play(String source) => playVoiceNote(source);
}