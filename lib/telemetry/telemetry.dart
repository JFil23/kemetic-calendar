// Shared app_events telemetry constants and lightweight client helpers.
const String kAppEventsSchemaVersion = 'ae_v1';

final RegExp _uuidPattern = RegExp(
  r'\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b',
);
final RegExp _emailPattern = RegExp(
  r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
  caseSensitive: false,
);
final RegExp _bearerTokenPattern = RegExp(
  r'Bearer\s+[A-Za-z0-9._~+/=-]+',
  caseSensitive: false,
);
final RegExp _tokenAssignmentPattern = RegExp(
  r'\b(access_token|refresh_token|token)=([^&\s]+)',
  caseSensitive: false,
);

String safeLogIdentifier(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return '<none>';
  if (_uuidPattern.hasMatch(normalized)) {
    return '${normalized.substring(0, 8)}...${normalized.substring(normalized.length - 4)}';
  }
  if (normalized.length <= 8) return '<redacted>';
  return '${normalized.substring(0, 4)}...${normalized.substring(normalized.length - 4)}';
}

String redactLogText(String value) {
  return value
      .replaceAll(_bearerTokenPattern, 'Bearer <redacted>')
      .replaceAllMapped(
        _tokenAssignmentPattern,
        (match) => '${match.group(1)}=<redacted>',
      )
      .replaceAll(_uuidPattern, '<uuid>')
      .replaceAll(_emailPattern, '<email>');
}

const Set<String> _defaultSensitiveLogKeys = {
  'access_token',
  'action_id',
  'avatar_url',
  'behavior_payload',
  'body',
  'client_event_id',
  'description',
  'detail',
  'display_name',
  'email',
  'flow_name',
  'handle',
  'location',
  'message',
  'name',
  'notes',
  'payload',
  'payload_json',
  'recipient_id',
  'refresh_token',
  'sender_id',
  'source_client_event_id',
  'text',
  'title',
  'token',
  'user_id',
};

bool _isSensitiveLogKey(String key) {
  final normalized = key.trim().toLowerCase();
  if (normalized.isEmpty) return false;
  if (_defaultSensitiveLogKeys.contains(normalized)) return true;
  return normalized.endsWith('_id') ||
      normalized.endsWith('_ids') ||
      normalized.contains('token') ||
      normalized.contains('payload') ||
      normalized.contains('secret');
}

String safeLogMapSummary(Map<dynamic, dynamic>? value) {
  if (value == null) return 'map<null>';
  final keys = value.keys.map((key) => key.toString()).toList()..sort();
  final sensitiveKeys = keys.where(_isSensitiveLogKey).toList();
  final safeKeys = keys.where((key) => !_isSensitiveLogKey(key)).toList();
  final parts = <String>[
    'size=${keys.length}',
    if (safeKeys.isNotEmpty) 'safeKeys=${safeKeys.join(",")}',
    if (sensitiveKeys.isNotEmpty) 'redactedKeys=${sensitiveKeys.join(",")}',
  ];
  return 'map<${parts.join(" ")}>';
}

String safeLogCollectionSummary(Object? value) {
  if (value == null) return '<null>';
  if (value is Map) return safeLogMapSummary(value);
  if (value is Iterable) return 'list<size=${value.length}>';
  return redactLogText(value.toString());
}

String safeUriHost(String value) {
  final uri = Uri.tryParse(value.trim());
  final host = uri?.host.trim();
  return host == null || host.isEmpty ? '<invalid>' : host;
}

class ScreenViewDedupe {
  ScreenViewDedupe({this.window = const Duration(seconds: 2)});

  final Duration window;
  String? _lastRoute;
  DateTime? _lastTrackedAt;

  bool shouldTrack(String route, DateTime now) {
    final normalized = route.trim().isEmpty ? '/' : route.trim();
    final lastTrackedAt = _lastTrackedAt;
    if (_lastRoute == normalized &&
        lastTrackedAt != null &&
        now.difference(lastTrackedAt) < window) {
      return false;
    }
    _lastRoute = normalized;
    _lastTrackedAt = now;
    return true;
  }

  void reset() {
    _lastRoute = null;
    _lastTrackedAt = null;
  }
}
