import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/user_events_repo.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';

/// Cut 2 P0: editing a Protect-stamped block from the day sheet must not strip
/// the Course ownership stamp, or the block silently stops being measurable.
void main() {
  const courseId = 'course-finish-my-book';

  Map<String, dynamic> protectRow({
    required bool carryStamps,
    String title = 'Finish my book',
  }) {
    final stamp = FollowSkyCourseOwnership.behaviorPayload(courseId: courseId);
    return <String, dynamic>{
      'id': 'evt-1',
      'client_event_id': 'cid-1',
      'title': title,
      'all_day': false,
      'starts_at': '2026-08-26T16:00:00Z',
      'ends_at': '2026-08-26T17:00:00Z',
      if (carryStamps) 'action_id': FollowSkyCourseOwnership.actionId,
      if (carryStamps) 'behavior_payload': stamp,
    };
  }

  test('carried stamps keep the block attributed to the Course', () {
    final saved = UserEvent.fromRow(protectRow(carryStamps: true));
    final edited = UserEvent.fromRow(
      protectRow(carryStamps: true, title: 'Finish my book — chapter 4'),
    );

    expect(
      FollowSkyCourseOwnership.courseIdOf(saved.behaviorPayload),
      courseId,
    );
    expect(
      FollowSkyCourseOwnership.courseIdOf(edited.behaviorPayload),
      courseId,
    );
    expect(FollowSkyCourseOwnership.isProtectTime(edited.behaviorPayload), isTrue);
    expect(edited.actionId, FollowSkyCourseOwnership.actionId);
  });

  test('dropped stamps are exactly how measurement attribution is lost', () {
    final edited = UserEvent.fromRow(
      protectRow(carryStamps: false, title: 'Finish my book — chapter 4'),
    );

    expect(FollowSkyCourseOwnership.courseIdOf(edited.behaviorPayload), isNull);
    expect(
      FollowSkyCourseOwnership.isProtectTime(edited.behaviorPayload),
      isFalse,
    );
  });

  test('a Course-owned Protect block is measurable without Connect', () {
    final course = TrackSkyCourse(
      courseId: courseId,
      label: 'Finish my book',
      sourceType: TrackSkyCourseSourceType.freeText,
      createdAt: DateTime.utc(2026, 8, 1),
    );
    final owned = UserEvent.fromRow(protectRow(carryStamps: true));

    // The same attribution rule production runs, not a restatement of it.
    final intervals = const FollowSkyCourseAttribution().intervalsFor(
      course: course,
      blocks: [
        FollowSkyCalendarBlock(
          start: owned.startsAt,
          end: owned.endsAt,
          flowId: owned.flowLocalId,
          actionId: owned.actionId,
          behaviorPayload: owned.behaviorPayload,
        ),
      ],
    );

    expect(intervals, hasLength(1));
    const service = CourseFunctionService();
    final measure = service.evidenceFor(
      function: SkyEventFunction.measure,
      course: course,
      now: DateTime.utc(2026, 8, 28, 12),
      intervals: intervals,
    );
    expect(measure.available, isTrue);
  });

  group('day-sheet update wiring', () {
    final calendarPage = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final repo = File('lib/data/user_events_repo.dart').readAsStringSync();

    String bodyOf(String source, String signature) {
      final start = source.indexOf(signature);
      expect(start, greaterThan(-1), reason: 'missing $signature');
      return source.substring(start, start + 4000);
    }

    test('_updateSingleNoteOnly threads the behavior stamps through', () {
      final body = bodyOf(
        calendarPage,
        'Future<({String clientEventId, String eventId})> _updateSingleNoteOnly({',
      );
      expect(body, contains('String? actionId,'));
      expect(body, contains('Map<String, dynamic>? behaviorPayload,'));
      // _Note, repo.replace and _addNote must all receive them.
      expect(
        RegExp('actionId: actionId,').allMatches(body).length,
        greaterThanOrEqualTo(3),
      );
      expect(
        RegExp('behaviorPayload: behaviorPayload,').allMatches(body).length,
        greaterThanOrEqualTo(3),
      );
    });

    test('the day sheet passes the existing note stamps', () {
      final body = bodyOf(calendarPage, 'saveResult = await _updateSingleNoteOnly(');
      expect(body, contains('actionId: existingNote.actionId,'));
      expect(body, contains('existingNote.behaviorPayload,'));
    });

    test('UserEventsRepo.replace writes the stamps when supplied', () {
      final body = bodyOf(repo, 'Future<UserEvent> replace({');
      expect(body, contains('String? actionId,'));
      expect(body, contains('Map<String, dynamic>? behaviorPayload,'));
      expect(body, contains("if (actionId != null) 'action_id': actionId,"));
      expect(
        body,
        contains(
          "if (behaviorPayload != null) 'behavior_payload': behaviorPayload,",
        ),
      );
    });
  });
}
