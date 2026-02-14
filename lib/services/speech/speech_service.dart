import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Lightweight, app-wide TTS helper with speaking state tracking.
class SpeechService {
  SpeechService._();
  static final SpeechService instance = SpeechService._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  /// Exposed so UI can swap icons based on actual TTS callbacks.
  final ValueNotifier<bool> isSpeaking = ValueNotifier<bool>(false);

  Future<void> _ensureReady() async {
    if (_ready) return;

    try {
      // Some platforms require this for completion/cancel callbacks.
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {
      // Best-effort; not all platforms support it.
    }

    // Keep UI honest about real speaking state.
    _tts.setStartHandler(() => isSpeaking.value = true);
    _tts.setCompletionHandler(() => isSpeaking.value = false);
    _tts.setCancelHandler(() => isSpeaking.value = false);
    _tts.setErrorHandler((_) => isSpeaking.value = false);

    // Sensible defaults; tweak to taste.
    await _tts.setSpeechRate(0.9);
    await _tts.setPitch(1.0);
    await _tts.setLanguage('en-US');

    _ready = true;
  }

  /// Speak the given text, stopping any prior utterance first.
  Future<void> speak(String text) async {
    await _ensureReady();
    await stop();
    await _tts.speak(_speechSafeText(text));
  }

  /// Stop any active utterance and clear state.
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    isSpeaking.value = false;
  }

  /// Approximate transliteration symbols to simpler phonetics to avoid TTS choke.
  String _speechSafeText(String input) {
    var s = input;
    s = s
        .replaceAll('ꜣ', 'a')
        .replaceAll('ꜥ', 'a')
        .replaceAll('ḥ', 'h')
        .replaceAll('ḫ', 'kh')
        .replaceAll('š', 'sh')
        .replaceAll('ṯ', 't')
        .replaceAll('ḏ', 'j')
        .replaceAll('ȝ', 'a')
        .replaceAll('ʿ', 'a')
        .replaceAll('ʾ', 'a');

    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
