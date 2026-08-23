import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/user_events_repo.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';

/// Cut 2 — Protect Time is the whole reason a free-text Course is measurable
/// without Connect, so it is proved here through the persistence codec that
/// production actually writes and reads (`toInsert` / `toPatch` / `fromRow`)
/// and through the real attribution rule, never through hand-built intervals.
void main() {
  late SkyCatalog catalog;

  setUpAll(() {
    catalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );
  });

  /// The user typed their own course; nothing in the calendar is linked to it.
  final freeTextCourse = TrackSkyCourse(
    courseId: 'course-finish-my-book',
    label: 'Finish my book',
    sourceType: TrackSkyCourseSourceType.freeText,
    createdAt: DateTime.utc(2026, 8, 1),
  );

  final now = DateTime.utc(2026, 8, 28, 12);
  const attribution = FollowSkyCourseAttribution();
  const functions = CourseFunctionService();

  SkyObservingNight nightFor(SkyEventFunction function) {
    return catalog
        .upcomingNights(nowUtc: DateTime.utc(2026, 8, 1))
        .firstWhere((n) => n.function == function);
  }

  /// Exactly what `CalendarPage._protectFollowSkyCourseTime` hands to
  /// `_saveSingleNoteOnly`: an ordinary single block plus the ownership stamp.
  UserEvent protectBlock({
    required String id,
    required TrackSkyCourse course,
    required DateTime startUtc,
    required Duration length,
  }) {
    return UserEvent(
      id: id,
      clientEventId: 'cid-$id',
      title: course.label,
      allDay: false,
      startsAt: startUtc,
      endsAt: startUtc.add(length),
      actionId: FollowSkyCourseOwnership.actionId,
      behaviorPayload: FollowSkyCourseOwnership.behaviorPayload(
        courseId: course.courseId,
      ),
    );
  }

  test('Protect Time stamps action id, course id and creator', () {
    final store = _EventStore();
    final saved = store.insert(
      protectBlock(
        id: 'p1',
        course: freeTextCourse,
        startUtc: DateTime.utc(2026, 8, 26, 16),
        length: const Duration(hours: 1),
      ),
    );

    expect(saved.actionId, FollowSkyCourseOwnership.actionId);
    expect(
      saved.behaviorPayload?[FollowSkyCourseOwnership.courseIdKey],
      freeTextCourse.courseId,
    );
    expect(
      saved.behaviorPayload?[FollowSkyCourseOwnership.createdByKey],
      FollowSkyCourseOwnership.createdByValue,
    );
    expect(FollowSkyCourseOwnership.isProtectTime(saved.behaviorPayload), isTrue);
  });

  test('a protected block is a single calendar block, not a Flow', () {
    final store = _EventStore();
    final saved = store.insert(
      protectBlock(
        id: 'p1',
        course: freeTextCourse,
        startUtc: DateTime.utc(2026, 8, 26, 16),
        length: const Duration(hours: 1),
      ),
    );

    expect(saved.flowLocalId, isNull);
    expect(_blockOf(saved).isSingleCalendarBlock, isTrue);
    expect(_blockOf(saved).isProtectTime, isTrue);
  });

  test('production protects time through the single-note save, not a join', () {
    final body = _methodBody(
      File('lib/features/calendar/calendar_page.dart').readAsStringSync(),
      'Future<void> _protectFollowSkyCourseTime({',
    );

    expect(body, contains('_saveSingleNoteOnly('));
    expect(body, contains('actionId: FollowSkyCourseOwnership.actionId'));
    expect(body, contains('behaviorPayload: ownership'));
    // A Course must never spawn a permanent Flow or a Ma'at enrollment.
    expect(body, isNot(contains('joinTrackSky')));
    expect(body, isNot(contains('FlowsRepo')));
    expect(body, isNot(contains('_addMaatFlowInstance')));
  });

  test('live inputs attribute measurement through the shared rule', () {
    final body = _methodBody(
      File('lib/features/calendar/calendar_page.dart').readAsStringSync(),
      '}) _followSkyLiveInputs() {',
    );

    expect(body, contains('FollowSkyCourseAttribution().intervalsFor('));
    // No second copy of the rule may live in the widget layer.
    expect(body, isNot(contains('CourseMeasurementInterval(')));
  });

  test('ownership survives a title edit through the persistence codec', () {
    final store = _EventStore();
    final saved = store.insert(
      protectBlock(
        id: 'p1',
        course: freeTextCourse,
        startUtc: DateTime.utc(2026, 8, 26, 16),
        length: const Duration(hours: 1),
      ),
    );

    final renamed = store.replace(
      saved.id,
      _copyWith(saved, title: 'Finish my book — chapter 4'),
    );

    expect(renamed.title, 'Finish my book — chapter 4');
    expect(renamed.actionId, FollowSkyCourseOwnership.actionId);
    expect(
      FollowSkyCourseOwnership.courseIdOf(renamed.behaviorPayload),
      freeTextCourse.courseId,
    );
    expect(
      attribution.attributes(
        course: freeTextCourse,
        block: _blockOf(renamed),
      ),
      isTrue,
    );
  });

  test('ownership survives a move and the measured interval moves with it', () {
    final store = _EventStore();
    final saved = store.insert(
      protectBlock(
        id: 'p1',
        course: freeTextCourse,
        startUtc: DateTime.utc(2026, 8, 26, 16),
        length: const Duration(hours: 1),
      ),
    );

    final movedStart = DateTime.utc(2026, 8, 27, 19);
    final moved = store.replace(
      saved.id,
      _copyWith(
        saved,
        startsAt: movedStart,
        endsAt: movedStart.add(const Duration(hours: 2)),
      ),
    );

    expect(
      FollowSkyCourseOwnership.courseIdOf(moved.behaviorPayload),
      freeTextCourse.courseId,
    );

    final intervals = attribution.intervalsFor(
      course: freeTextCourse,
      blocks: store.blocks(),
    );
    expect(intervals, hasLength(1));
    expect(intervals.single.start, movedStart);
    expect(intervals.single.minutes, 120);
  });

  test('deleting the protected block stops measurement', () {
    final store = _EventStore();
    final saved = store.insert(
      protectBlock(
        id: 'p1',
        course: freeTextCourse,
        startUtc: DateTime.utc(2026, 8, 26, 16),
        length: const Duration(hours: 1),
      ),
    );

    expect(
      attribution.intervalsFor(
        course: freeTextCourse,
        blocks: store.blocks(),
      ),
      hasLength(1),
    );

    store.delete(saved.id);

    final afterDelete = attribution.intervalsFor(
      course: freeTextCourse,
      blocks: store.blocks(),
    );
    expect(afterDelete, isEmpty);

    final measure = functions.evidenceFor(
      function: SkyEventFunction.measure,
      course: freeTextCourse,
      now: now,
      intervals: afterDelete,
    );
    expect(measure.available, isFalse);
  });

  test('another Course never inherits this Course\'s protected time', () {
    final store = _EventStore();
    store.insert(
      protectBlock(
        id: 'p1',
        course: freeTextCourse,
        startUtc: DateTime.utc(2026, 8, 26, 16),
        length: const Duration(hours: 1),
      ),
    );

    final otherCourse = TrackSkyCourse(
      courseId: 'course-learn-piano',
      label: 'Learn piano',
      sourceType: TrackSkyCourseSourceType.freeText,
      createdAt: DateTime.utc(2026, 8, 20),
    );

    expect(
      attribution.intervalsFor(course: otherCourse, blocks: store.blocks()),
      isEmpty,
    );
    // No Course at all must never pick up someone's protected time either.
    expect(
      attribution.intervalsFor(course: null, blocks: store.blocks()),
      isEmpty,
    );
  });

  group('what each function may conclude from protected time alone', () {
    late List<CourseMeasurementInterval> intervals;

    setUp(() {
      final store = _EventStore();
      store.insert(
        protectBlock(
          id: 'p1',
          course: freeTextCourse,
          startUtc: DateTime.utc(2026, 8, 20, 10),
          length: const Duration(minutes: 90),
        ),
      );
      store.insert(
        protectBlock(
          id: 'p2',
          course: freeTextCourse,
          startUtc: DateTime.utc(2026, 8, 26, 9),
          length: const Duration(hours: 1),
        ),
      );
      intervals = attribution.intervalsFor(
        course: freeTextCourse,
        blocks: store.blocks(),
      );
      expect(intervals, hasLength(2));
    });

    test('the Equinox counts it — Measure reports the real minutes', () {
      final equinox = nightFor(SkyEventFunction.measure);
      expect(equinox.serviceKind, SkyEventKind.equinox);

      final evidence = functions.evidenceFor(
        function: equinox.function,
        course: freeTextCourse,
        now: now,
        intervals: intervals,
      );

      expect(evidence.available, isTrue);
      expect(evidence.body, contains('Current 14 days: 2h 30m'));
      expect(evidence.body, contains('Previous 14 days: 0h 00m'));
    });

    test('an eclipse does not treat it as carried forward', () {
      final eclipse = nightFor(SkyEventFunction.reconsider);

      final evidence = functions.evidenceFor(
        function: eclipse.function,
        course: freeTextCourse,
        now: now,
        intervals: intervals,
      );

      expect(evidence.available, isFalse);
      expect(evidence.unavailableReason, contains('carried-forward'));
      // With no evidence object there is nothing to Keep / Change / Release.
      expect(
        TrackSkyEnrollmentService(
          materializer: _noopMaterializer,
          visibilityService: const SkyVisibilityService(),
        ).availableChoices(
          hasCourse: true,
          hasEvidenceObject: evidence.available,
          function: eclipse.function,
        ),
        isEmpty,
      );
    });

    test('a Full Moon does not treat it as something open', () {
      final fullMoon = nightFor(SkyEventFunction.reveal);
      expect(fullMoon.serviceKind, SkyEventKind.fullMoon);

      final evidence = functions.evidenceFor(
        function: fullMoon.function,
        course: freeTextCourse,
        now: now,
        intervals: intervals,
      );

      expect(evidence.available, isFalse);
      expect(evidence.unavailableReason, contains('unfinished'));
    });

    test('a Solstice may summarize the season', () {
      final solstice = nightFor(SkyEventFunction.turn);
      expect(solstice.serviceKind, SkyEventKind.solstice);

      final evidence = functions.evidenceFor(
        function: solstice.function,
        course: freeTextCourse,
        now: now,
        intervals: intervals,
      );

      expect(evidence.available, isTrue);
      expect(evidence.body, contains('2h 30m'));
      expect(evidence.body, contains(freeTextCourse.label));
    });
  });
}

/// Source slice for exactly one method, so a `isNot(contains(...))` assertion
/// can never be satisfied or broken by whatever follows it in the file.
String _methodBody(String source, String signature) {
  final start = source.indexOf(signature);
  if (start < 0) throw StateError('missing $signature');
  // A `({` signature opens the named-parameter block first; the body brace is
  // whichever `{` follows it.
  final paramsEnd = signature.trimRight().endsWith('{')
      ? _matchBrace(source, source.indexOf('{', start))
      : start + signature.length - 1;
  final bodyOpen = source.indexOf('{', paramsEnd);
  return source.substring(start, _matchBrace(source, bodyOpen) + 1);
}

int _matchBrace(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '{') depth += 1;
    if (source[i] == '}') {
      depth -= 1;
      if (depth == 0) return i;
    }
  }
  throw StateError('unbalanced braces at $open');
}

FollowSkyCalendarBlock _blockOf(UserEvent event) => FollowSkyCalendarBlock(
      start: event.startsAt,
      end: event.endsAt,
      flowId: event.flowLocalId,
      actionId: event.actionId,
      behaviorPayload: event.behaviorPayload,
    );

UserEvent _copyWith(
  UserEvent event, {
  String? title,
  DateTime? startsAt,
  DateTime? endsAt,
}) {
  return UserEvent(
    id: event.id,
    clientEventId: event.clientEventId,
    calendarId: event.calendarId,
    title: title ?? event.title,
    detail: event.detail,
    location: event.location,
    allDay: event.allDay,
    startsAt: startsAt ?? event.startsAt,
    endsAt: endsAt ?? event.endsAt,
    category: event.category,
    actionId: event.actionId,
    behaviorPayload: event.behaviorPayload,
  );
}

/// Persists through the same row encoders `UserEventsRepo` uses, so an edit that
/// silently dropped `action_id` / `behavior_payload` would fail here too.
class _EventStore {
  final Map<String, Map<String, dynamic>> _rows = <String, Map<String, dynamic>>{};

  UserEvent insert(UserEvent event) {
    final row = event.toInsert(userId: 'user-1')..['id'] = event.id;
    _rows[event.id] = row;
    return UserEvent.fromRow(row);
  }

  UserEvent replace(String id, UserEvent updated) {
    final row = _rows[id];
    if (row == null) throw StateError('no row $id');
    row.addAll(updated.toPatch());
    return UserEvent.fromRow(row);
  }

  void delete(String id) => _rows.remove(id);

  Iterable<FollowSkyCalendarBlock> blocks() =>
      _rows.values.map(UserEvent.fromRow).map(_blockOf);
}

final _noopMaterializer = TrackSkyMaterializer(
  toLocal: (utc, _) => utc,
  toUtc: (local, _) => local,
);
