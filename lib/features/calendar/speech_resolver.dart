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

  static String prose({required String base, String? englishCue}) {
    final resolvedBase = base.trim();
    if (resolvedBase.isEmpty) {
      return _normalizeCue(englishCue) ?? '';
    }
    return _withCue(resolvedBase, englishCue);
  }

  static String _withCue(String base, String? cue) {
    final normalizedCue = _normalizeCue(cue);
    if (normalizedCue == null) return base;
    return '$base, $normalizedCue';
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

  static String? _normalizeCue(String? cue) {
    final cleaned = cue
        ?.replaceAll(RegExp(r'^[\s"“”]+'), '')
        .replaceAll(RegExp(r'[\s"“”.,;:!?]+$'), '')
        .trim();
    if (cleaned == null || cleaned.isEmpty) return null;

    if (RegExp(r'^(the|a|an)\b', caseSensitive: false).hasMatch(cleaned)) {
      return cleaned;
    }
    return 'the $cleaned';
  }
}
