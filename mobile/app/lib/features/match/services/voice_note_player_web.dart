import 'dart:html' as html;

Future<void> playVoiceNote(String source) async {
  final audio = html.AudioElement(source);
  await audio.play();
}