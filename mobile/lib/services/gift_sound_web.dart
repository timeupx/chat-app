import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

web.HTMLAudioElement? _audio;

Future<void> unlockGiftAudio(
  Uint8List bytes, {
  double volume = 0.08,
}) async {
  final audio = _ensureAudio(bytes);
  audio.volume = 0.001;
  try {
    await audio.play().toDart;
  } catch (_) {
    // Autoplay may still block until a real gesture; ignore.
  }
  audio.pause();
  audio.currentTime = 0;
  audio.volume = volume;
}

Future<void> playGiftAudio(
  Uint8List bytes, {
  double volume = 0.08,
}) async {
  final audio = _ensureAudio(bytes);
  audio.volume = volume;
  audio.currentTime = 0;
  try {
    await audio.play().toDart;
  } catch (e) {
    // ignore: avoid_print
    print('playGiftAudio failed: $e');
  }
}

web.HTMLAudioElement _ensureAudio(Uint8List bytes) {
  final existing = _audio;
  if (existing != null) return existing;

  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'audio/wav'),
  );
  final url = web.URL.createObjectURL(blob);
  final audio = web.HTMLAudioElement()
    ..src = url
    ..preload = 'auto';
  _audio = audio;
  return audio;
}
