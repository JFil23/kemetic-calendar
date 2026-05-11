import 'package:flutter/foundation.dart';

@immutable
class DailyReflectionSnapshot {
  const DailyReflectionSnapshot({
    required this.schemaVersion,
    required this.kind,
    required this.generatedAt,
    required this.validForLocalDate,
    required this.timezone,
    required this.locale,
    required this.reflection,
    required this.kemeticDate,
    required this.intent,
    required this.expiresAt,
    required this.authRequired,
    required this.sourceVersion,
  });

  static const int currentSchemaVersion = 1;
  static const String dailyReflectionKind = 'daily_reflection';

  final int schemaVersion;
  final String kind;
  final DateTime generatedAt;
  final String validForLocalDate;
  final String timezone;
  final String locale;
  final String reflection;
  final DailyReflectionKemeticDate kemeticDate;
  final DailyReflectionIntent intent;
  final DateTime expiresAt;
  final bool authRequired;
  final String sourceVersion;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'kind': kind,
    'generatedAt': generatedAt.toIso8601String(),
    'validForLocalDate': validForLocalDate,
    'timezone': timezone,
    'locale': locale,
    'reflection': reflection,
    'kemeticDate': kemeticDate.toJson(),
    'intent': intent.toJson(),
    'expiresAt': expiresAt.toIso8601String(),
    'authRequired': authRequired,
    'sourceVersion': sourceVersion,
  };

  factory DailyReflectionSnapshot.fromJson(Map<String, Object?> json) {
    return DailyReflectionSnapshot(
      schemaVersion: _asInt(json['schemaVersion']) ?? 0,
      kind: _asString(json['kind']) ?? '',
      generatedAt: _asDateTime(json['generatedAt']) ?? DateTime(1970),
      validForLocalDate: _asString(json['validForLocalDate']) ?? '',
      timezone: _asString(json['timezone']) ?? '',
      locale: _asString(json['locale']) ?? '',
      reflection: _asString(json['reflection']) ?? '',
      kemeticDate: DailyReflectionKemeticDate.fromJson(
        _asMap(json['kemeticDate']) ?? const <String, Object?>{},
      ),
      intent: DailyReflectionIntent.fromJson(
        _asMap(json['intent']) ?? const <String, Object?>{},
      ),
      expiresAt: _asDateTime(json['expiresAt']) ?? DateTime(1970),
      authRequired: json['authRequired'] == true,
      sourceVersion: _asString(json['sourceVersion']) ?? '',
    );
  }
}

@immutable
class DailyReflectionKemeticDate {
  const DailyReflectionKemeticDate({
    required this.display,
    required this.dayKey,
    required this.kYear,
  });

  final String display;
  final String dayKey;
  final int kYear;

  Map<String, Object?> toJson() => <String, Object?>{
    'display': display,
    'dayKey': dayKey,
    'kYear': kYear,
  };

  factory DailyReflectionKemeticDate.fromJson(Map<String, Object?> json) {
    return DailyReflectionKemeticDate(
      display: _asString(json['display']) ?? '',
      dayKey: _asString(json['dayKey']) ?? '',
      kYear: _asInt(json['kYear']) ?? 0,
    );
  }
}

@immutable
class DailyReflectionIntent {
  const DailyReflectionIntent({
    required this.url,
    required this.route,
    required this.params,
  });

  final String url;
  final String route;
  final Map<String, String> params;

  Map<String, Object?> toJson() => <String, Object?>{
    'url': url,
    'route': route,
    'params': params,
  };

  factory DailyReflectionIntent.fromJson(Map<String, Object?> json) {
    final rawParams = json['params'];
    return DailyReflectionIntent(
      url: _asString(json['url']) ?? '',
      route: _asString(json['route']) ?? '',
      params: rawParams is Map
          ? rawParams.map<String, String>(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const <String, String>{},
    );
  }
}

Map<String, Object?>? _asMap(Object? value) {
  if (value is! Map) return null;
  return value.map<String, Object?>(
    (key, value) => MapEntry(key.toString(), value),
  );
}

String? _asString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int? _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

DateTime? _asDateTime(Object? value) {
  final text = _asString(value);
  return text == null ? null : DateTime.tryParse(text);
}
