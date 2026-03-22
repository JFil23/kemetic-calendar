import 'dart:async';
import 'dart:io' show Platform;
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

  static const Map<String, String> _transliterationReplacements = {
    'ꜣ': 'a',
    'Ꜣ': 'a',
    'ꜥ': 'a',
    'Ꜥ': 'a',
    'ḥ': 'h',
    'Ḥ': 'h',
    'ḫ': 'kh',
    'Ḫ': 'kh',
    'ẖ': 'kh',
    'š': 'sh',
    'Š': 'sh',
    'ṯ': 't',
    'Ṯ': 't',
    'ḏ': 'dj',
    'Ḏ': 'dj',
    'ȝ': 'a',
    'Ȝ': 'a',
    'ỉ': 'i',
    'Ỉ': 'i',
    'ʿ': 'a',
    'ʾ': 'a',
  };

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
    await _tts.setSpeechRate(0.5); // slower for clarity
    await _tts.setPitch(1.0);      // neutral pitch
    await _tts.setLanguage('en-US');
    if (!kIsWeb && Platform.isIOS) {
      // Prefer a clearer iOS voice
      await _tts.setVoice({'name': 'Samantha', 'locale': 'en-US'});
    }

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

  /// Speak a phonetic string (still normalized for TTS safety).
  Future<void> speakPhonetic(String text) async {
    await _ensureReady();
    await stop();
    await _tts.speak(_speechSafeText(text));
  }

  /// Approximate transliteration symbols to simpler phonetics to avoid TTS choke.
  String _speechSafeText(String input) {
    var s = input;
    _transliterationReplacements.forEach((k, v) {
      s = s.replaceAll(k, v);
    });

    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
