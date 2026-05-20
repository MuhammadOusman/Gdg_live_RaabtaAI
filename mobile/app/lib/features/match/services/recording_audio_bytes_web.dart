import 'dart:html' as html;
import 'dart:typed_data';

Future<List<int>?> readRecordingBytesImpl(String recordingSource) async {
  try {
    final request = await html.HttpRequest.request(
      recordingSource,
      responseType: 'arraybuffer',
    );
    final response = request.response;
    if (response is ByteBuffer) {
      return Uint8List.view(response);
    }
    if (response is Uint8List) {
      return response;
    }
    return null;
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