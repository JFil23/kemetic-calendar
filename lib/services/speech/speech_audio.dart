import 'dart:async';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

abstract interface class SpeechAudio {
  Stream<void> get completed;
  Future<void> play(Uint8List bytes, {required String mimeType});
  Future<void> dispose();
}

/// Each utterance owns a player, so old completion events cannot stop a new clip.
class DeviceSpeechAudio implements SpeechAudio {
  // Pronunciation has no progress UI. Avoid scheduling position queries on
  // every scroll frame, including queries that can outlive clip completion.
  final _player = AudioPlayer()..positionUpdater = null;
  bool _disposed = false;
  @override
  Stream<void> get completed => _player.onPlayerComplete;
  @override
  Future<void> play(Uint8List bytes, {required String mimeType}) async {
    if (_disposed) return;
    await _player.setSource(BytesSource(bytes, mimeType: mimeType));
    if (!_disposed) await _player.resume();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _player.dispose();
  }
}
