import 'package:mobile/features/pages/pages_arrangement.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/commons_models.dart';
import 'package:mobile/features/pages/pages_feed_rotation.dart';

CommonsPracticeRoom room(String id, [Map<String, dynamic> fields = const {}]) =>
    CommonsPracticeRoom.fromJson({
      'id': id,
      'title': 'Public practice $id',
      'calendar_id': 'calendar',
      'source_flow_id': 1,
      'created_by': 'owner',
      'visibility': 'public',
      'status': 'active',
      'join_policy': 'owner_approval',
      'member_count': 3,
      'viewer_can_request_join': true,
      ...fields,
    });
const question = CommonsQuestion(id: 'today', question: 'What matters today?');
const answered = CommonsQuestion(
  id: 'today',
  question: 'What matters today?',
  myAnswer: CommonsAnswer(
    id: 'answer',
    questionId: 'today',
    userId: 'viewer',
    bodyText: 'Saved answer',
  ),
);
CommonsHomeSnapshot home(
  List<CommonsPracticeRoom> rooms, {
  List<CommonsPracticeRoom> mine = const [],
}) => CommonsHomeSnapshot(
  rhythm: CommonsRhythmSummary.empty(),
  publicSharedPractices: rooms,
  mySharedPractices: mine,
);

void main() {
  test('local edition boundaries include overnight and exact transitions', () {
    for (final value in [
      (4, 59, PagesFeedEdition.dusk),
      (5, 0, PagesFeedEdition.dawn),
      (11, 29, PagesFeedEdition.dawn),
      (11, 30, PagesFeedEdition.midday),
      (17, 29, PagesFeedEdition.midday),
      (17, 30, PagesFeedEdition.dusk),
      (23, 59, PagesFeedEdition.dusk),
    ]) {
      expect(
        PagesFeedRotation.editionAt(DateTime(2026, 9, 28, value.$1, value.$2)),
        value.$3,
      );
    }
    expect(
      PagesFeedRotation.nextBoundary(DateTime(2026, 9, 28, 17, 30)),
      DateTime(2026, 9, 29, 5),
    );
    expect(
      PagesFeedRotation.nextBoundary(DateTime(2026, 9, 28, 5)),
      DateTime(2026, 9, 28, 11, 30),
    );
  });
  test('one local timer stops when hidden and recalculates on resume', () {
    fakeAsync((time) {
      final start = DateTime(2026, 9, 28, 11, 29, 59);
      final rotation = PagesFeedRotation(now: () => start.add(time.elapsed));
      var notifications = 0;
      rotation.addListener(() => notifications++);
      rotation.setActive(true);
      expect(time.nonPeriodicTimerCount, 1);
      time.elapse(const Duration(seconds: 2));
      expect(rotation.edition, PagesFeedEdition.midday);
      expect(notifications, 1);
      expect(time.nonPeriodicTimerCount, 1);
      rotation.setActive(false);
      expect(time.nonPeriodicTimerCount, 0);
      time.elapse(const Duration(hours: 7));
      expect(notifications, 1);
      rotation.setActive(true);
      expect(rotation.edition, PagesFeedEdition.dusk);
      expect(notifications, 2);
      rotation.dispose();
      expect(time.nonPeriodicTimerCount, 0);
    });
  });
  test('each edition ranks useful eligible content with honest fallbacks', () {
    final commons = home([room('a')]);
    final dawn = DateTime(2026, 9, 28, 7),
        midday = DateTime(2026, 9, 28, 12),
        dusk = DateTime(2026, 9, 28, 19);
    expect(
      selectPagesFeedEdition(
        now: dawn,
        question: question,
        commons: commons,
      ).display,
      PagesFeedDisplay.question,
    );
    expect(
      selectPagesFeedEdition(
        now: midday,
        question: question,
        commons: commons,
      ).display,
      PagesFeedDisplay.practice,
    );
    expect(
      selectPagesFeedEdition(
        now: dusk,
        question: question,
        commons: commons,
      ).display,
      PagesFeedDisplay.publicRhythm,
    );
    expect(
      selectPagesFeedEdition(
        now: dawn,
        question: answered,
        commons: commons,
      ).display,
      PagesFeedDisplay.practice,
    );
    expect(
      selectPagesFeedEdition(
        now: midday,
        question: question,
        commons: home([]),
      ).display,
      PagesFeedDisplay.question,
    );
    expect(
      selectPagesFeedEdition(
        now: dawn,
        question: answered,
        commons: home([]),
      ).display,
      PagesFeedDisplay.publicRhythm,
    );
    final flagOnly = CommonsQuestion(
      id: 'today',
      question: question.question,
      answers: [
        CommonsAnswer(
          id: 'a',
          questionId: 'today',
          userId: 'v',
          bodyText: 'Saved',
          isMine: true,
        ),
      ],
    );
    expect(
      selectPagesFeedEdition(
        now: dawn,
        question: flagOnly,
        commons: home([]),
      ).display,
      PagesFeedDisplay.publicRhythm,
    );
  });
  test('permission and lifecycle exclusions do not become discovery', () {
    for (final fields in [
      {'visibility': 'private'},
      {'visibility': 'unlisted'},
      {'status': 'ended'},
      {'join_policy': 'closed'},
      {'viewer_can_request_join': false},
      {'viewer_is_member': true},
      {'viewer_can_manage': true},
      {'viewer_request_status': 'pending'},
      {'viewer_request_status': 'blocked'},
      {'viewer_request_status': 'approved'},
      {'member_count': 1},
      {'id': ''},
    ]) {
      final selected = selectPagesFeedEdition(
        now: DateTime(2026, 9, 28, 12),
        question: question,
        commons: home([room('a', fields)]),
      );
      expect(selected.display, PagesFeedDisplay.question, reason: '$fields');
      expect(selected.practice, isNull);
    }
    final duplicate = home(
      [room('a')],
      mine: [
        room('a', {'viewer_is_member': true}),
      ],
    );
    expect(
      selectPagesFeedEdition(
        now: DateTime(2026, 9, 28, 12),
        question: question,
        commons: duplicate,
      ).practice,
      isNull,
    );
  });
  test('selection is stable across repaint, payload reordering and reopen', () {
    final date = DateTime(2026, 9, 28, 12),
        rooms = [room('a'), room('b'), room('c')];
    final first = selectPagesFeedEdition(
      now: date,
      question: question,
      commons: home(rooms),
    );
    final later = selectPagesFeedEdition(
      now: date.add(const Duration(hours: 2)),
      question: question,
      commons: home(rooms.reversed.toList()),
    );
    expect(first.practice?.id, later.practice?.id);
    final withoutSelected = rooms
        .where((r) => r.id != first.practice?.id)
        .toList();
    expect(
      selectPagesFeedEdition(
        now: date,
        question: question,
        commons: home(withoutSelected),
      ).practice?.id,
      isNot(first.practice?.id),
    );
  });
}
