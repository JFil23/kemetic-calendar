import 'sky_event.dart';
import 'sky_event_function.dart';
import 'sky_event_kind.dart';
import 'sky_visibility.dart';

/// One observing night in the flow: one materializable anchor, one function.
///
/// When a lunar eclipse is merged into a Full Moon (`mergedIntoId`), the rarer
/// phenomenon overrides: display combines both names, function is Reconsider,
/// and [skyEventId] remains the Full Moon anchor for Gate 16 / calendar linkage.
class SkyObservingNight {
  SkyObservingNight({
    required this.anchor,
    this.companion,
  }) : assert(anchor.mergedIntoId == null);

  /// Materializable catalog event (calendar / Gate 16 identity).
  final SkyEvent anchor;

  /// Optional same-night lunar eclipse merged into [anchor].
  final SkyEvent? companion;

  String get skyEventId => anchor.id;

  bool get isEclipseFullMoon => companion != null;

  String get displayName {
    final eclipse = companion;
    if (eclipse == null) return anchor.name;
    return '${anchor.name} + ${eclipse.name}';
  }

  /// Rarer/specific phenomenon wins when a companion is present.
  SkyEventFunction get function => companion?.function ?? anchor.function;

  /// Kind used for service copy and CTA routing.
  SkyEventKind get serviceKind => companion?.kind ?? anchor.kind;

  DateTime get primaryInstantUtc => anchor.primaryInstantUtc;

  SkyVisibilityPolicy get visibilityPolicy =>
      companion?.visibilityPolicy ?? anchor.visibilityPolicy;

  /// Event used for local viewing-window heuristics.
  SkyEvent get windowSource => companion ?? anchor;

  /// Notes prefer the exceptional companion when present.
  String? get notes => companion?.notes ?? anchor.notes;

  bool get specialNotification =>
      companion?.specialNotification ?? anchor.specialNotification;

  bool get provisional =>
      (companion?.provisional ?? false) || anchor.provisional;
}
