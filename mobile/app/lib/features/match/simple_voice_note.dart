import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:uuid/uuid.dart';

import 'services/recording_path.dart';

class SimpleVoiceNote extends StatefulWidget {
  const SimpleVoiceNote({
    super.key,
    this.onStartRecording,
    this.onStopRecording,
  });

  final Future<void> Function()? onStartRecording;
  final Future<void> Function()? onStopRecording;

  @override
  State<SimpleVoiceNote> createState() => _SimpleVoiceNoteState();
}

class _SimpleVoiceNoteState extends State<SimpleVoiceNote> {
  final Record _recorder = Record();
  final AudioPlayer _player = AudioPlayer();
  final _uuid = const Uuid();

  bool _isRecording = false;
  String? _lastRecordingPath;
  StreamSubscription<RecordState>? _recStateSub;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _recStateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (widget.onStartRecording != null) {
      await widget.onStartRecording!();
      if (!mounted) return;
      setState(() => _isRecording = true);
      return;
    }

    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission denied')));
      return;
    }

    final id = _uuid.v4();
    final path = createRecordingPath(id);
    try {
      await _recorder.start(path: path, encoder: AudioEncoder.aacLc);
      if (!mounted) return;
      setState(() => _isRecording = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Start recording failed: $e')));
    }
  }

  Future<void> _stopRecording() async {
    if (widget.onStopRecording != null) {
      await widget.onStopRecording!();
      if (!mounted) return;
      setState(() => _isRecording = false);
      return;
    }

    if (!_isRecording) return;
    try {
      final path = await _recorder.stop();
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        if (path != null && File(path).existsSync()) {
          _lastRecordingPath = path;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stop recording failed: $e')));
    }
  }

  Future<void> _play() async {
    final path = _lastRecordingPath;
    if (path == null) return;
    try {
      await _player.stop();
      await _player.play(DeviceFileSource(File(path).path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Playback failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FloatingActionButton(
              heroTag: 'rec',
              backgroundColor: _isRecording ? Colors.red : Colors.green,
              onPressed: () async {
                if (_isRecording) {
                  await _stopRecording();
                } else {
                  await _startRecording();
                }
                setState(() {});
              },
              child: Icon(_isRecording ? Icons.stop : Icons.mic),
            ),
            const SizedBox(width: 20),
            FloatingActionButton(
              heroTag: 'play',
              backgroundColor: _lastRecordingPath != null ? Colors.blue : Colors.grey,
              onPressed: _lastRecordingPath != null ? _play : null,
              child: const Icon(Icons.play_arrow),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _isRecording
              ? 'Recording…'
              : (_lastRecordingPath != null ? 'Ready: ${_lastRecordingPath!.split(Platform.pathSeparator).last}' : 'No recording yet'),
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }
}
