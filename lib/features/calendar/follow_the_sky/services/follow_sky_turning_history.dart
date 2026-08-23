import '../domain/sky_event_function.dart';
import 'track_sky_enrollment_service.dart';

/// What actually happened at a turning.
///
/// The distinction is load-bearing: watching the sky is not the same as making
/// a decision about your Course, and the history must never blur the two.
enum FollowSkyTurningEntryKind {
  /// The user observed the turning. No Course decision was taken.
  witnessed,

  /// The user completed the turning's function with a real decision.
  functionCompleted,
}

class FollowSkyTurningEntry {
  const FollowSkyTurningEntry({
    required this.skyEventId,
    required this.kind,
    required this.function,
    required this.recordedAtUtc,
    this.courseId,
    this.choice,
  });

  final String skyEventId;
  final FollowSkyTurningEntryKind kind;
  final SkyEventFunction function;
  final DateTime recordedAtUtc;

  /// Course the decision was about. Null for a witnessed-only turning.
  final String? courseId;

  /// The decision the user made. Only ever set for [functionCompleted].
  final FollowSkyProductChoice? choice;

  bool get isWitnessedOnly => kind == FollowSkyTurningEntryKind.witnessed;
  bool get isFunctionCompleted =>
      kind == FollowSkyTurningEntryKind.functionCompleted;
}

/// In-memory ledger of turnings, kept per Follow the Sky session.
///
/// Nothing is recorded without evidence: a Keep / Change / Release entry only
/// exists because the user tapped that choice on a surfaced evidence object.
class FollowSkyTurningHistory {
  final List<FollowSkyTurningEntry> _entries = <FollowSkyTurningEntry>[];

  List<FollowSkyTurningEntry> get entries =>
      List<FollowSkyTurningEntry>.unmodifiable(_entries);

  Iterable<FollowSkyTurningEntry> get witnessed =>
      _entries.where((e) => e.isWitnessedOnly);

  Iterable<FollowSkyTurningEntry> get functionsCompleted =>
      _entries.where((e) => e.isFunctionCompleted);

  /// The user looked at the turning without deciding anything.
  void recordWitnessed({
    required String skyEventId,
    required SkyEventFunction function,
    required DateTime nowUtc,
  }) {
    _entries.add(
      FollowSkyTurningEntry(
        skyEventId: skyEventId,
        kind: FollowSkyTurningEntryKind.witnessed,
        function: function,
        recordedAtUtc: nowUtc.toUtc(),
      ),
    );
  }

  /// The user made a real Course decision at this turning.
  void recordFunctionCompleted({
    required String skyEventId,
    required SkyEventFunction function,
    required FollowSkyProductChoice choice,
    required String courseId,
    required DateTime nowUtc,
  }) {
    _entries.add(
      FollowSkyTurningEntry(
        skyEventId: skyEventId,
        kind: FollowSkyTurningEntryKind.functionCompleted,
        function: function,
        choice: choice,
        courseId: courseId,
        recordedAtUtc: nowUtc.toUtc(),
      ),
    );
  }

  /// True once a decision (not just an observation) exists for [skyEventId].
  bool hasFunctionCompleted(String skyEventId) =>
      functionsCompleted.any((e) => e.skyEventId == skyEventId);

  /// True when the turning was only observed and never decided on.
  bool wasOnlyWitnessed(String skyEventId) =>
      witnessed.any((e) => e.skyEventId == skyEventId) &&
      !hasFunctionCompleted(skyEventId);

  void clear() => _entries.clear();
}
