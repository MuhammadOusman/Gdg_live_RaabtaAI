import 'dart:io';

Future<List<int>?> readRecordingBytesImpl(String recordingSource) async {
  try {
    return await File(recordingSource).readAsBytes();
  } catch (_) {
    return null;
  }
}

String inferRecordingMimeTypeImpl(String recordingSource) {
  final lower = recordingSource.toLowerCase();
  if (lower.endsWith('.m4a') || lower.endsWith('.mp4')) {
    return 'audio/mp4';
  }
  if (lower.endsWith('.wav')) {
    return 'audio/wav';
  }
  if (lower.endsWith('.ogg')) {
    return 'audio/ogg';
  }
  if (lower.endsWith('.mp3')) {
    return 'audio/mpeg';
  }
  return 'audio/webm';
}