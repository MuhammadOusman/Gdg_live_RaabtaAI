import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

final AudioPlayer _voiceNotePlayer = AudioPlayer();

Future<void> playVoiceNote(String source) async {
  await _voiceNotePlayer.stop();
  await _voiceNotePlayer.play(DeviceFileSource(File(source).path));
}