import 'sky_event_function.dart';
import 'sky_event_kind.dart';
import 'sky_visibility.dart';

class SkyPeakWindow {
  const SkyPeakWindow({required this.startUtc, required this.endUtc});

  final DateTime startUtc;
  final DateTime endUtc;

  factory SkyPeakWindow.fromJson(Map<String, dynamic> json) {
    return SkyPeakWindow(
      startUtc: DateTime.parse(json['startUtc'] as String).toUtc(),
      endUtc: DateTime.parse(json['endUtc'] as String).toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
    'startUtc': startUtc.toIso8601String(),
    'endUtc': endUtc.toIso8601String(),
  };
}

/// Canonical astronomy fact. Copy and scheduling derive from this — never the reverse.
class SkyEvent {
  const SkyEvent({
    required this.id,
    required this.kind,
    required this.name,
    required this.function,
    required this.visibilityPolicy,
    required this.precision,
    required this.source,
    required this.sourceVersion,
    this.instantUtc,
    this.peakWindowUtc,
    this.culturalName,
    this.mergedIntoId,
    this.specialNotification = true,
    this.provisional = false,
    this.notes,
    this.enhancedWindows = const [],
  });

  final String id;
  final SkyEventKind kind;
  final String name;
  final SkyEventFunction function;
  final SkyVisibilityPolicy visibilityPolicy;
  final SkyEventPrecision precision;
  final String source;
  final String sourceVersion;
  final DateTime? instantUtc;
  final SkyPeakWindow? peakWindowUtc;
  final String? culturalName;
  final String? mergedIntoId;
  final bool specialNotification;
  final bool provisional;
  final String? notes;
  final List<SkyPeakWindow> enhancedWindows;

  DateTime get primaryInstantUtc {
    if (instantUtc != null) return instantUtc!;
    final window = peakWindowUtc;
    if (window != null) {
      final mid = window.startUtc
          .add(window.endUtc.difference(window.startUtc) ~/ 2);
      return mid.toUtc();
    }
    throw StateError('SkyEvent $id has no instant or peak window');
  }

  factory SkyEvent.fromJson(Map<String, dynamic> json) {
    final kind = SkyEventKindX.parse(json['kind'] as String);
    final functionRaw = json['function'] as String?;
    return SkyEvent(
      id: json['id'] as String,
      kind: kind,
      name: json['name'] as String,
      function: functionRaw != null
          ? SkyEventFunctionX.parse(functionRaw)
          : SkyEventFunctionX.forKind(kind.wireName),
      visibilityPolicy:
          SkyVisibilityPolicyX.parse(json['visibilityPolicy'] as String),
      precision: SkyEventPrecisionX.parse(json['precision'] as String),
      source: json['source'] as String,
      sourceVersion: json['sourceVersion'] as String,
      instantUtc: json['instantUtc'] == null
          ? null
          : DateTime.parse(json['instantUtc'] as String).toUtc(),
      peakWindowUtc: json['peakWindowUtc'] == null
          ? null
          : SkyPeakWindow.fromJson(
              Map<String, dynamic>.from(json['peakWindowUtc'] as Map),
            ),
      culturalName: json['culturalName'] as String?,
      mergedIntoId: json['mergedIntoId'] as String?,
      specialNotification: json['specialNotification'] as bool? ?? true,
      provisional: json['provisional'] as bool? ?? false,
      notes: json['notes'] as String?,
      enhancedWindows: (json['enhancedWindows'] as List?)
              ?.map(
                (e) => SkyPeakWindow.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.wireName,
    'name': name,
    'function': function.wireName,
    'visibilityPolicy': visibilityPolicy.wireName,
    'precision': precision.wireName,
    'source': source,
    'sourceVersion': sourceVersion,
    if (instantUtc != null) 'instantUtc': instantUtc!.toIso8601String(),
    if (peakWindowUtc != null) 'peakWindowUtc': peakWindowUtc!.toJson(),
    if (culturalName != null) 'culturalName': culturalName,
    if (mergedIntoId != null) 'mergedIntoId': mergedIntoId,
    'specialNotification': specialNotification,
    'provisional': provisional,
    if (notes != null) 'notes': notes,
    if (enhancedWindows.isNotEmpty)
      'enhancedWindows': enhancedWindows.map((e) => e.toJson()).toList(),
  };
}
