part of 'pronunciation_service.dart';

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

/// Device rendering is used only by the single pronunciation authority.
class _DevicePronunciationVoice implements PronunciationFallback {
  static const _preferredVoiceKey = 'speech:preferredVoiceId';
  static const _defaultLanguage = 'en-US';
  final FlutterTts _tts = FlutterTts();
  Future<void>? _ready;
  String? _preferredVoiceId;
  bool _preferredVoiceLoaded = false;
  bool _availableVoicesLoaded = false;
  List<SpeechVoiceOption> _availableVoices = const [];

  @override
  Future<void> prepare() => _ready ??= _initialize().catchError((Object error) {
    _ready = null;
    throw error;
  });
  Future<void> _initialize() async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(0.46);
    await _tts.setPitch(0.9);
    await _tts.setLanguage(_defaultLanguage);
    await _loadPreferredVoiceId();
    await _loadAvailableVoices();
    final preferred = _preferredVoice();
    if (preferred != null) await _applyVoice(preferred);
  }

  @override
  Future<void> speak(String catalogText) async {
    await _tts.speak(catalogText);
  }

  @override
  Future<void> stop() async {
    if (_ready != null) await _tts.stop();
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

  Future<List<SpeechVoiceOption>> voices({
    String? localePrefix,
    bool reload = false,
  }) async {
    await prepare();
    if (reload || !_availableVoicesLoaded) await _loadAvailableVoices();
    final prefix = localePrefix?.toLowerCase();
    return List.unmodifiable(
      _availableVoices.where(
        (v) => prefix == null || v.locale.toLowerCase().startsWith(prefix),
      ),
    );
  }

  Future<void> select(SpeechVoiceOption? voice) async {
    await prepare();
    final prefs = await SharedPreferences.getInstance();
    _preferredVoiceId = voice?.id;
    if (voice == null) {
      await prefs.remove(_preferredVoiceKey);
      await _tts.setLanguage(_defaultLanguage);
    } else {
      await prefs.setString(_preferredVoiceKey, voice.id);
      await _applyVoice(voice);
    }
  }
}
