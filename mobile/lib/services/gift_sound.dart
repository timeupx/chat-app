import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'gift_sound_stub.dart'
    if (dart.library.html) 'gift_sound_web.dart' as web_audio;

/// Plays the short gift chime on mobile + Chrome web.
///
/// Browsers block audio until a user gesture — call [unlock] from a tap
/// (opening the gift sheet) so later gift events can play.
class GiftSound {
  GiftSound._();
  static final GiftSound instance = GiftSound._();

  /// Soft UI chime — keep well below full volume.
  static const double playVolume = 0.08;

  final AudioPlayer _player = AudioPlayer();
  bool _unlocked = false;
  Uint8List? _bytes;

  Uint8List _chimeBytes() => _bytes ??= _buildGiftChimeWav();

  /// Warm up audio on a user gesture (Chrome autoplay policy).
  Future<void> unlock() async {
    if (_unlocked) return;
    try {
      final bytes = _chimeBytes();
      if (kIsWeb) {
        await web_audio.unlockGiftAudio(bytes, volume: playVolume);
      } else {
        await _player.setVolume(0.001);
        await _player.play(
          BytesSource(bytes, mimeType: 'audio/wav'),
          mode: PlayerMode.mediaPlayer,
        );
        await _player.stop();
        await _player.setVolume(playVolume);
      }
      _unlocked = true;
    } catch (e) {
      debugPrint('GiftSound.unlock failed: $e');
    }
  }

  Future<void> play() async {
    try {
      final bytes = _chimeBytes();
      if (!_unlocked) {
        await unlock();
      }
      if (kIsWeb) {
        await web_audio.playGiftAudio(bytes, volume: playVolume);
        return;
      }
      await _player.stop();
      await _player.setVolume(playVolume);
      await _player.play(
        BytesSource(bytes, mimeType: 'audio/wav'),
        mode: PlayerMode.mediaPlayer,
      );
    } catch (e) {
      debugPrint('GiftSound.play failed: $e');
    }
  }

  Future<void> dispose() => _player.dispose();
}

/// Compact stereo 44.1kHz WAV — no asset file required.
Uint8List _buildGiftChimeWav() {
  const sampleRate = 44100;
  const durationSec = 0.32;
  final n = (sampleRate * durationSec).round();
  const tones = <(double, double, double)>[
    (988, 0.0, 0.14),
    (1319, 0.07, 0.18),
    (1760, 0.14, 0.18),
  ];

  final pcm = ByteData(n * 4); // stereo 16-bit
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    var v = 0.0;
    for (final (freq, start, length) in tones) {
      if (t < start || t > start + length) continue;
      final local = t - start;
      final env =
          math.sin(math.pi * (local / length).clamp(0.0, 1.0)) *
          math.exp(-5.0 * local);
      v += 0.10 * env * math.sin(2 * math.pi * freq * local);
    }
    if (v > 1) v = 1;
    if (v < -1) v = -1;
    final s = (v * 32767).round();
    final o = i * 4;
    pcm.setInt16(o, s, Endian.little);
    pcm.setInt16(o + 2, s, Endian.little);
  }

  final dataSize = n * 4;
  final bytes = BytesBuilder(copy: false)
    ..add('RIFF'.codeUnits)
    ..add(_u32le(36 + dataSize))
    ..add('WAVE'.codeUnits)
    ..add('fmt '.codeUnits)
    ..add(_u32le(16))
    ..add(_u16le(1))
    ..add(_u16le(2))
    ..add(_u32le(sampleRate))
    ..add(_u32le(sampleRate * 4))
    ..add(_u16le(4))
    ..add(_u16le(16))
    ..add('data'.codeUnits)
    ..add(_u32le(dataSize))
    ..add(pcm.buffer.asUint8List());
  return bytes.toBytes();
}

Uint8List _u16le(int v) =>
    (ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List();
Uint8List _u32le(int v) =>
    (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List();
