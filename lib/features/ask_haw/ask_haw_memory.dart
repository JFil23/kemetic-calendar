/// Confirmed account-owned memory. Persistence and pending writes belong to the
/// repository; this value never reads storage or grants action permissions.
class AskHawMemory {
  AskHawMemory({
    this.revision = 0,
    this.epoch = 0,
    Map<String, dynamic> payload = const {},
  }) : payload = Map<String, dynamic>.unmodifiable(_freezeMap(payload));

  factory AskHawMemory.fromJson(Map<String, dynamic> json) => AskHawMemory(
    revision: (json['revision'] as num?)?.toInt() ?? 0,
    epoch: (json['epoch'] as num?)?.toInt() ?? 0,
    payload: _map(json['payload']),
  );

  final int revision;
  final int epoch;
  final Map<String, dynamic> payload;

  Map<String, dynamic> get preferences => _readMap('preferences');
  Map<String, dynamic> get bindings => _readMap('bindings');
  Map<String, dynamic> get phraseBindings => bindings;
  Map<String, dynamic> get signals => _readMap('signals');
  Set<String> get hiddenSuggestions => Set<String>.unmodifiable(
    (payload['hidden'] is List ? payload['hidden'] as List : const [])
        .whereType<String>(),
  );
  bool get suggestionsEnabled => preferences['suggestionsEnabled'] != false;
  int? get preferredDurationMinutes {
    final raw = preferences['preferredDurationMinutes'];
    if (raw is! num) return null;
    final value = raw.toInt();
    return value > 0 && value <= 1440 ? value : null;
  }

  String get preferredTimeOfDay {
    final value = preferences['preferredTimeOfDay'];
    return const {'morning', 'afternoon', 'evening'}.contains(value)
        ? value as String
        : 'any';
  }

  Map<String, dynamic>? bindingFor(String normalizedPhrase) {
    final value = bindings[normalizedPhrase];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  AskHawMemory copyWith({
    int? revision,
    int? epoch,
    Map<String, dynamic>? payload,
  }) => AskHawMemory(
    revision: revision ?? this.revision,
    epoch: epoch ?? this.epoch,
    payload: payload ?? this.payload,
  );

  Map<String, dynamic> toJson() => {
    'revision': revision,
    'epoch': epoch,
    'payload': _freezeMap(payload),
  };

  Map<String, dynamic> _readMap(String key) =>
      Map<String, dynamic>.unmodifiable(_map(payload[key]));
}

Map<String, dynamic> _map(Object? value) => value is Map
    ? value.map((key, value) => MapEntry(key.toString(), value))
    : <String, dynamic>{};

Map<String, dynamic> _freezeMap(Map<String, dynamic> value) =>
    value.map((key, value) => MapEntry(key, _freezeValue(value)));

Object? _freezeValue(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable(_freezeMap(_map(value)));
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freezeValue));
  return value;
}
