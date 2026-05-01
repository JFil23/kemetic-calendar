import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SpeechVoiceOption {
  final String id;
  final String name;
  final String locale;
  final String? identifier;
  final String? gender;
  final String? quality;

  const SpeechVoiceOption({
    required this.id,
    required this.name,
    required this.locale,
    this.identifier,
    this.gender,
    this.quality,
  });

  String get displayLabel {
    if (locale.isEmpty) return name;

    final metadata = <String>[
      if (gender != null && gender!.isNotEmpty) gender!,
      if (quality != null && quality!.isNotEmpty) quality!,
    ];
    if (metadata.isEmpty) return '$name ($locale)';
    return '$name ($locale, ${metadata.join(', ')})';
  }

  Map<String, String> toVoiceMap() {
    return {
      'name': name,
      'locale': locale,
      if (identifier != null && identifier!.isNotEmpty)
        'identifier': identifier!,
      if (gender != null && gender!.isNotEmpty) 'gender': gender!,
      if (quality != null && quality!.isNotEmpty) 'quality': quality!,
    };
  }

  static SpeechVoiceOption? fromRaw(dynamic raw) {
    if (raw is! Map) return null;

    final name = raw['name']?.toString().trim() ?? '';
    final locale = raw['locale']?.toString().trim() ?? '';
    if (name.isEmpty || locale.isEmpty) return null;

    final identifier = raw['identifier']?.toString().trim();
    final gender = raw['gender']?.toString().trim();
    final quality = raw['quality']?.toString().trim();
    final normalizedIdentifier = (identifier == null || identifier.isEmpty)
        ? null
        : identifier;

    return SpeechVoiceOption(
      id: normalizedIdentifier != null
          ? 'id:$normalizedIdentifier'
          : 'voice:${locale.toLowerCase()}|${name.toLowerCase()}',
      name: name,
      locale: locale,
      identifier: normalizedIdentifier,
      gender: (gender == null || gender.isEmpty) ? null : gender,
      quality: (quality == null || quality.isEmpty) ? null : quality,
    );
  }
}

/// Lightweight, app-wide TTS helper with speaking state tracking.
class SpeechService {
  SpeechService._();
  static final SpeechService instance = SpeechService._();

  static const String _preferredVoiceKey = 'speech:preferredVoiceId';
  static const String _defaultLanguage = 'en-US';
  static const double _defaultSpeechRate = 0.46;
  static const double _defaultPitch = 0.9;
  static const String _anonymousUtteranceId = '__speech_service__anonymous__';

  FlutterTts _tts = FlutterTts();
  bool _ready = false;
  Future<void>? _initializing;
  String? _preferredVoiceId;
  bool _preferredVoiceLoaded = false;
  List<SpeechVoiceOption> _availableVoices = const [];
  bool _availableVoicesLoaded = false;

  /// Exposed so UI can swap icons based on actual TTS callbacks.
  final ValueNotifier<bool> isSpeaking = ValueNotifier<bool>(false);
  final ValueNotifier<String?> activeUtteranceId = ValueNotifier<String?>(null);

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
    final pending = _initializing;
    if (pending != null) {
      await pending;
      return;
    }

    final future = _initialize();
    _initializing = future;
    try {
      await future;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initialize() async {
    try {
      // Some platforms require this for completion/cancel callbacks.
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {
      // Best-effort; not all platforms support it.
    }

    _tts.setStartHandler(() => isSpeaking.value = true);
    _tts.setCompletionHandler(_clearPlaybackState);
    _tts.setCancelHandler(_clearPlaybackState);
    _tts.setErrorHandler((_) => _clearPlaybackState());

    // Slightly lower and slower than stock device defaults.
    await _tts.setSpeechRate(_defaultSpeechRate);
    await _tts.setPitch(_defaultPitch);
    await _tts.setLanguage(_defaultLanguage);

    await _loadPreferredVoiceId();
    await _loadAvailableVoices();
    final preferredVoice = _preferredVoice();
    if (preferredVoice != null) {
      await _applyVoice(preferredVoice);
    }

    _ready = true;
  }

  Future<void> _loadPreferredVoiceId() async {
    if (_preferredVoiceLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    _preferredVoiceId = prefs.getString(_preferredVoiceKey);
    _preferredVoiceLoaded = true;
  }

  Future<void> _loadAvailableVoices() async {
    try {
      final rawVoices = await _tts.getVoices;
      final voices = <SpeechVoiceOption>[];
      final seenIds = <String>{};

      if (rawVoices is List) {
        for (final raw in rawVoices) {
          final voice = SpeechVoiceOption.fromRaw(raw);
          if (voice == null) continue;
          if (!seenIds.add(voice.id)) continue;
          voices.add(voice);
        }
      }

      voices.sort((a, b) {
        final localeCompare = a.locale.toLowerCase().compareTo(
          b.locale.toLowerCase(),
        );
        if (localeCompare != 0) return localeCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      _availableVoices = List.unmodifiable(voices);
    } catch (_) {
      _availableVoices = const [];
    } finally {
      _availableVoicesLoaded = true;
    }
  }

  SpeechVoiceOption? _preferredVoice() {
    final preferredId = _preferredVoiceId;
    if (preferredId == null || preferredId.isEmpty) return null;
    for (final voice in _availableVoices) {
      if (voice.id == preferredId) return voice;
    }
    return null;
  }

  Future<void> _applyVoice(SpeechVoiceOption voice) async {
    final locale = voice.locale.trim().isEmpty
        ? _defaultLanguage
        : voice.locale;
    await _tts.setLanguage(locale);
    await _tts.setVoice(voice.toVoiceMap());
  }

  void _clearPlaybackState() {
    isSpeaking.value = false;
    activeUtteranceId.value = null;
  }

  Future<void> _recreateTtsInstance() async {
    try {
      await _tts.stop();
    } catch (_) {}

    _tts = FlutterTts();
    _ready = false;
    _availableVoicesLoaded = false;
    _clearPlaybackState();
  }

  Future<List<SpeechVoiceOption>> getAvailableVoices({
    String? localePrefix,
    bool reload = false,
  }) async {
    await _ensureReady();
    if (reload || !_availableVoicesLoaded) {
      await _loadAvailableVoices();
    }

    final prefix = localePrefix?.trim().toLowerCase();
    if (prefix == null || prefix.isEmpty) {
      return _availableVoices;
    }
    return List.unmodifiable(
      _availableVoices.where(
        (voice) => voice.locale.toLowerCase().startsWith(prefix),
      ),
    );
  }

  Future<SpeechVoiceOption?> getPreferredVoice() async {
    await _ensureReady();
    return _preferredVoice();
  }

  Future<void> setPreferredVoice(SpeechVoiceOption? voice) async {
    await stop();

    final prefs = await SharedPreferences.getInstance();
    if (voice == null) {
      _preferredVoiceId = null;
      _preferredVoiceLoaded = true;
      await prefs.remove(_preferredVoiceKey);
      await _recreateTtsInstance();
      await _ensureReady();
      return;
    }

    _preferredVoiceId = voice.id;
    _preferredVoiceLoaded = true;
    await prefs.setString(_preferredVoiceKey, voice.id);
    await _ensureReady();
    await _applyVoice(voice);
  }

  /// Speak the given text, stopping any prior utterance first.
  Future<void> speak(String text, {String? utteranceId}) async {
    await _ensureReady();
    await stop();
    final activeId = _effectiveUtteranceId(utteranceId);
    activeUtteranceId.value = activeId;
    try {
      await _tts.speak(_speechSafeText(text));
    } catch (_) {
      if (activeUtteranceId.value == activeId) {
        _clearPlaybackState();
      }
      rethrow;
    }
  }

  /// Stop any active utterance and clear state.
  Future<void> stop({String? utteranceId}) async {
    final activeId = activeUtteranceId.value;
    final requestedId = utteranceId?.trim();
    if (requestedId != null &&
        requestedId.isNotEmpty &&
        activeId != requestedId) {
      return;
    }
    try {
      await _tts.stop();
    } catch (_) {}
    _clearPlaybackState();
  }

  /// Speak a phonetic string (still normalized for TTS safety).
  Future<void> speakPhonetic(String text, {String? utteranceId}) async {
    await speak(text, utteranceId: utteranceId);
  }

  /// Approximate transliteration symbols to simpler phonetics to avoid TTS choke.
  String _speechSafeText(String input) {
    var s = input;
    _transliterationReplacements.forEach((k, v) {
      s = s.replaceAll(k, v);
    });

    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _effectiveUtteranceId(String? utteranceId) {
    final id = utteranceId?.trim();
    if (id == null || id.isEmpty) return _anonymousUtteranceId;
    return id;
  }
}
