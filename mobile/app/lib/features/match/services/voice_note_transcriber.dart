import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'recording_audio_bytes.dart';

class VoiceNoteTranscriber {
  VoiceNoteTranscriber({String? apiKey, String? modelName})
      : _apiKey = apiKey ?? dotenv.env['GEMINI_API_KEY'] ?? '',
        _modelNames = [
          modelName ?? dotenv.env['GEMINI_MODEL'] ?? 'gemini-2.5-flash',
          'gemini-1.5-flash',
        ];

  final String _apiKey;
  final List<String> _modelNames;

  Future<String> transcribeVoiceMessage(String recordingSource) async {
    if (_apiKey.isEmpty) {
      return '';
    }

    final bytes = await readRecordingBytes(recordingSource);
    if (bytes == null || bytes.isEmpty) {
      return '';
    }

    final mimeType = inferRecordingMimeType(recordingSource);
    for (final modelName in _modelNames.toSet()) {
      final transcript = await _transcribeWithModel(
        modelName: modelName,
        bytes: bytes,
        mimeType: mimeType,
      );

      if (transcript.isNotEmpty) {
        return transcript;
      }
    }

    return '';
  }

  Future<String> _transcribeWithModel({
    required String modelName,
    required List<int> bytes,
    required String mimeType,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$_apiKey',
    );

    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {
                'text':
                    'Transcribe this WhatsApp voice message to English text only. If the message is in a non-English language (Urdu, Arabic, Hindi, etc.), translate it to English. Output plain text only, no explanation.',
              },
              {
                'inline_data': {
                  'mime_type': mimeType,
                  'data': base64Encode(bytes),
                },
              },
            ],
          }
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return '';
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return '';
    }

    final rawText = _extractText(decoded);
    return _normalizeTranscription(rawText);
  }

  String _extractText(Map<String, dynamic> payload) {
    final candidates = payload['candidates'];
    if (candidates is! List) {
      return '';
    }

    for (final candidate in candidates) {
      if (candidate is! Map<String, dynamic>) {
        continue;
      }

      final content = candidate['content'];
      if (content is! Map<String, dynamic>) {
        continue;
      }

      final parts = content['parts'];
      if (parts is! List) {
        continue;
      }

      for (final part in parts) {
        if (part is Map<String, dynamic>) {
          final text = part['text'];
          if (text is String && text.trim().isNotEmpty) {
            return text;
          }
        }
      }
    }

    return '';
  }

  String _normalizeTranscription(String value) {
    var sanitized = value
        .replaceAll(RegExp(r'^```(?:text)?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*```$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (sanitized.startsWith('"') || sanitized.startsWith("'")) {
      sanitized = sanitized.substring(1);
    }

    if (sanitized.endsWith('"') || sanitized.endsWith("'")) {
      sanitized = sanitized.substring(0, sanitized.length - 1);
    }

    return sanitized.trim();
  }
}