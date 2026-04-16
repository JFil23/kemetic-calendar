String buildSharedFileIntentSignature(Iterable<String?> entries) {
  final normalized =
      entries
          .map(_normalizeSharedFileIntentEntry)
          .whereType<String>()
          .toList(growable: false)
        ..sort();
  return normalized.join('|');
}

bool shouldSkipDuplicateSharedFileIntent({
  required String signature,
  String? lastSignature,
  DateTime? lastHandledAt,
  required DateTime now,
  Duration window = const Duration(seconds: 3),
}) {
  if (signature.isEmpty || lastSignature == null || lastHandledAt == null) {
    return false;
  }
  return signature == lastSignature && now.difference(lastHandledAt) < window;
}

bool isSupportedSharedCalendarFilePath(String? pathOrName) {
  final normalized = _normalizeSharedFileIntentEntry(pathOrName);
  return normalized != null && normalized.toLowerCase().endsWith('.ics');
}

String? _normalizeSharedFileIntentEntry(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed.replaceAll('\\', '/');
}
