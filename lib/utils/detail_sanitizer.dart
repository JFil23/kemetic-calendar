import 'dart:convert';

final RegExp _cidRegex = RegExp(
  r'^(kemet(?:ic)?_cid:)?ky=\d+-km=\d+-kd=\d+\|s=\d+\|t=[^|]+\|f=[^|]+$',
  caseSensitive: false,
);

final RegExp _jsonKeyRegex = RegExp(
  r'"(?:id|title|detail|details|description|overview|notes|start|start_date|start_time|end|end_date|end_time|offset_days|all_day|location|kind)"\s*:',
  caseSensitive: false,
);

final RegExp _metadataPrefixRegex = RegExp(
  r'^(?:flowLocalId=[^;]*|repeat=\{.*?\}|repeat=[^;]*|color=[0-9a-fA-FxX]+|alert=[-+]?\d+);',
  caseSensitive: false,
);

final RegExp _titleTimeOnlyRegex = RegExp(
  r'^\s*\d{1,2}\s*:\s*\d{1,2}(?:\s+\d+)?\s*(?:am|pm)?\s*$',
  caseSensitive: false,
);

String cleanFlowTitle(String? title) {
  final raw = _stripCodeFences(title).trim();
  if (raw.isEmpty) return '';

  final fromJson = _extractTextFromJsonString(
    raw,
    preferTitle: true,
    allowTitleFallback: true,
  );
  var cleaned = fromJson ?? raw;
  cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

  if (_titleTimeOnlyRegex.hasMatch(cleaned) || _looksLikeMachineText(cleaned)) {
    return '';
  }
  return cleaned;
}

String cleanFlowOverview(String? notes, {String? decodedOverview}) {
  final decoded = cleanFlowDetail(decodedOverview);
  if (decoded.isNotEmpty) return decoded;

  final raw = _stripCodeFences(notes).trim();
  if (raw.isEmpty) return '';

  final overviewToken = _extractOverviewToken(raw);
  if (overviewToken.isNotEmpty) {
    return cleanFlowDetail(overviewToken);
  }

  final fromJson = _extractTextFromJsonString(raw);
  if (fromJson != null) {
    return cleanFlowDetail(fromJson);
  }

  final repeatingMeta = _extractRepeatingNoteDetail(raw);
  if (repeatingMeta.isNotEmpty) {
    return cleanFlowDetail(repeatingMeta);
  }

  final cleaned = cleanFlowDetail(raw);
  if (cleaned.isNotEmpty) return cleaned;

  return _looksLikeMachineText(raw) ? '' : raw;
}

// Utility to strip internal metadata (kemet_cid, flowLocalId, reminder tags)
// from user-visible detail text.
String cleanFlowDetail(String? detail) {
  final raw = _stripCodeFences(detail).trim();
  if (raw.isEmpty) return '';

  final fromJson = _extractTextFromJsonString(raw);
  if (fromJson != null) {
    return cleanFlowDetail(fromJson);
  }

  final overviewToken = _extractOverviewToken(raw);
  if (overviewToken.isNotEmpty) {
    return cleanFlowDetail(overviewToken);
  }

  var t = raw;
  while (true) {
    final match = _metadataPrefixRegex.firstMatch(t);
    if (match == null) break;
    if (match.end >= t.length) return '';
    t = t.substring(match.end).trimLeft();
  }

  final kept = <String>[];
  for (final line in t.split(RegExp(r'\r?\n'))) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    if (_isMetadataLine(trimmed)) continue;

    final structured = _extractTextFromJsonString(trimmed);
    if (structured != null) {
      final cleaned = cleanFlowDetail(structured);
      if (cleaned.isNotEmpty) kept.add(cleaned);
      continue;
    }

    if (_looksLikeMachineText(trimmed)) continue;
    kept.add(trimmed);
  }

  return kept.join('\n').trim();
}

String _stripCodeFences(String? value) {
  if (value == null || value.isEmpty) return '';
  return value
      .replaceAll(RegExp(r'```[a-z0-9_-]*\s*', caseSensitive: false), '')
      .replaceAll('```', '')
      .trim();
}

String _extractOverviewToken(String raw) {
  for (final token in raw.split(';')) {
    final trimmed = token.trim();
    if (!trimmed.startsWith('ov=')) continue;
    final encoded = trimmed.substring(3);
    try {
      return Uri.decodeComponent(encoded).trim();
    } catch (_) {
      return encoded.trim();
    }
  }
  return '';
}

String _extractRepeatingNoteDetail(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map && decoded['kind'] == 'repeating_note') {
      return _firstNonEmptyString([
        decoded['detail'],
        decoded['details'],
        decoded['description'],
        decoded['notes'],
      ]);
    }
  } catch (_) {
    // Not JSON.
  }
  return '';
}

String? _extractTextFromJsonString(
  String raw, {
  bool preferTitle = false,
  bool allowTitleFallback = false,
}) {
  final trimmed = raw.trim();
  if (!(trimmed.startsWith('{') || trimmed.startsWith('['))) return null;

  try {
    final decoded = jsonDecode(trimmed);
    final extracted = _extractTextFromJsonValue(
      decoded,
      preferTitle: preferTitle,
      allowTitleFallback: allowTitleFallback,
    );
    final normalized = extracted.trim();
    return normalized.isEmpty ? null : normalized;
  } catch (_) {
    return null;
  }
}

String _extractTextFromJsonValue(
  dynamic value, {
  bool preferTitle = false,
  bool allowTitleFallback = false,
}) {
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || _looksLikeMachineText(trimmed)) return '';
    return trimmed;
  }

  if (value is List) {
    for (final item in value) {
      final nested = _extractTextFromJsonValue(
        item,
        preferTitle: preferTitle,
        allowTitleFallback: allowTitleFallback,
      );
      if (nested.isNotEmpty) return nested;
    }
    return '';
  }

  if (value is! Map) return '';

  final map = value.map((key, val) => MapEntry(key.toString(), val));

  final repeatingDetail = _firstNonEmptyString([
    if (map['kind'] == 'repeating_note') map['detail'],
    if (map['kind'] == 'repeating_note') map['details'],
    if (map['kind'] == 'repeating_note') map['description'],
    if (map['kind'] == 'repeating_note') map['notes'],
  ]);
  if (repeatingDetail.isNotEmpty) return repeatingDetail;

  if (preferTitle) {
    final title = _firstNonEmptyString([map['title'], map['name']]);
    if (title.isNotEmpty) return title;
  }

  final descriptive = _firstNonEmptyString([
    map['overview'],
    map['summary'],
    map['description'],
    map['details'],
    map['detail'],
    map['notes'],
    map['body'],
    map['text'],
    map['message'],
  ]);
  if (descriptive.isNotEmpty) return descriptive;

  final nestedPayload = map['payload'];
  if (nestedPayload != null) {
    final nested = _extractTextFromJsonValue(
      nestedPayload,
      preferTitle: preferTitle,
      allowTitleFallback: allowTitleFallback,
    );
    if (nested.isNotEmpty) return nested;
  }

  if (!preferTitle && allowTitleFallback) {
    final title = _firstNonEmptyString([map['title'], map['name']]);
    if (title.isNotEmpty) return title;
  }

  return '';
}

String _firstNonEmptyString(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && !_looksLikeMachineText(text)) {
      return text;
    }
  }
  return '';
}

bool _isMetadataLine(String value) {
  final lower = value.toLowerCase();
  if (lower.startsWith('kemet_cid:') || lower.startsWith('kemetic_cid:')) {
    return true;
  }
  if (lower.startsWith('reminder:')) return true;
  if (lower.startsWith('flowlocalid=')) return true;
  if (lower.startsWith('repeat=')) return true;
  if (lower.startsWith('mode=')) return true;
  if (lower.startsWith('split=')) return true;
  if (lower.startsWith('maat=')) return true;

  final normalized = value.replaceAll(RegExp(r'\s+'), '');
  if (_cidRegex.hasMatch(normalized)) return true;

  return false;
}

bool _looksLikeMachineText(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;

  if ((trimmed.startsWith('{') || trimmed.startsWith('[')) &&
      (_jsonKeyRegex.hasMatch(trimmed) || trimmed.contains('":'))) {
    return true;
  }

  final lower = trimmed.toLowerCase();
  if (lower.startsWith('flowlocalid=')) return true;
  if (lower.startsWith('repeat=')) return true;
  if (lower.startsWith('mode=')) return true;
  if (lower.startsWith('split=')) return true;
  if (lower.startsWith('maat=')) return true;
  if (lower.startsWith('color=')) return true;
  if (lower.startsWith('alert=')) return true;
  if (lower.startsWith('kemet_cid:') || lower.startsWith('kemetic_cid:')) {
    return true;
  }
  if (lower.startsWith('reminder:')) return true;

  final normalized = trimmed.replaceAll(RegExp(r'\s+'), '');
  if (_cidRegex.hasMatch(normalized)) return true;

  if (RegExp(
    r'^(?:mode|split|maat|flowLocalId|repeat|color|alert)=[^;]+(?:;(?:mode|split|maat|flowLocalId|repeat|color|alert)=[^;]+)*$',
    caseSensitive: false,
  ).hasMatch(trimmed)) {
    return true;
  }

  return false;
}
