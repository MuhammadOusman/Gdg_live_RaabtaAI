import 'recording_audio_bytes_stub.dart'
    if (dart.library.io) 'recording_audio_bytes_io.dart'
    if (dart.library.html) 'recording_audio_bytes_web.dart';

Future<List<int>?> readRecordingBytes(String recordingSource) =>
    readRecordingBytesImpl(recordingSource);

String inferRecordingMimeType(String recordingSource) =>
    inferRecordingMimeTypeImpl(recordingSource);