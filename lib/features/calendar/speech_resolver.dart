import 'speech_overrides.dart';

class SpeechResolver {
  static String month({
    required int monthId,
    required String fallbackTranslit,
    String? englishCue,
  }) {
    final base = monthSpeech[monthId]?.trim();
    return _withCue(
      (base != null && base.isNotEmpty) ? base : fallbackTranslit.trim(),
      englishCue,
    );
  }

  static String decan({
    required int decanId,
    required String fallbackTranslit,
    String? englishCue,
  }) {
    final base = decanSpeech[decanId]?.trim();
    return _withCue(
      (base != null && base.isNotEmpty) ? base : fallbackTranslit.trim(),
      englishCue,
    );
  }

  static String _withCue(String base, String? cue) {
    final c = cue?.trim();
    if (c == null || c.isEmpty) return base;
    return '$base. $c.';
  }
}
