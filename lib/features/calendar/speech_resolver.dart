import 'package:mobile/features/calendar/kemetic_month_metadata.dart';

import 'speech_overrides.dart';

class SpeechResolver {
  static String month({
    required KemeticMonth month,
    String? displayName,
    String? englishCue,
  }) {
    final base = _firstNonEmpty([
      monthSpeechNames[month.id],
      month.speechName,
      displayName,
      month.displayShort,
    ]);
    return _withCue(base, englishCue);
  }

  static String decan({
    required int decanId,
    required String displayName,
    String? englishCue,
  }) {
    final base = _firstNonEmpty([
      decanSpeechNames[decanId],
      decanSpeechNamesByLabel[_stripEnglishCue(displayName)],
      decanSpeechNamesByLabel[displayName.trim()],
      displayName,
    ]);
    return _withCue(base, englishCue);
  }

  static String _withCue(String base, String? cue) {
    final c = cue?.trim();
    if (c == null || c.isEmpty) return base;
    return '$base. $c.';
  }

  static String _firstNonEmpty(List<String?> options) {
    for (final opt in options) {
      if (opt == null) continue;
      final t = opt.trim();
      if (t.isNotEmpty) return t;
    }
    return '';
  }

  static String _stripEnglishCue(String s) {
    return s.split('(').first.trim();
  }
}
