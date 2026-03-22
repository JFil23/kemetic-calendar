// Utility to strip internal metadata (kemet_cid, flowLocalId, reminder tags)
// from user-visible detail text.
String cleanFlowDetail(String? detail) {
  if (detail == null || detail.isEmpty) return '';

  String t = detail;

  // Remove legacy prefixes.
  if (t.startsWith('flowLocalId=')) {
    final i = t.indexOf(';');
    if (i >= 0 && i < t.length - 1) {
      t = t.substring(i + 1);
    }
  }
  if (t.startsWith('repeat=')) {
    final i = t.indexOf(';');
    if (i >= 0 && i < t.length - 1) {
      t = t.substring(i + 1);
    }
  }

  final cidRegex = RegExp(
    r'^(kemet(?:ic)?_cid:)?ky=\d+-km=\d+-kd=\d+\|s=\d+\|t=[^|]+\|f=[^|]+$',
    caseSensitive: false,
  );

  final kept = <String>[];
  for (final line in t.split(RegExp(r'\r?\n'))) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    final lower = trimmed.toLowerCase();

    if (lower.startsWith('kemet_cid:') || lower.startsWith('kemetic_cid:')) {
      continue;
    }
    if (lower.startsWith('reminder:')) continue;

    final norm = trimmed.replaceAll(RegExp(r'\s+'), '');
    if (cidRegex.hasMatch(norm)) continue;

    kept.add(line);
  }

  return kept.join('\n').trim();
}
