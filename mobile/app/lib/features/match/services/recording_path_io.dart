import 'dart:io';

String createRecordingPathImpl(String recordingId) {
  return '${Directory.systemTemp.path}/voice_note_$recordingId.m4a';
}