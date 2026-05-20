import 'voice_note_player_stub.dart'
  if (dart.library.io) 'voice_note_player_io.dart'
    if (dart.library.html) 'voice_note_player_web.dart';

class VoiceNotePlayer {
  const VoiceNotePlayer();

  Future<void> play(String source) => playVoiceNote(source);
}