import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/rhythm/event_todo_builder.dart';

void main() {
  group('buildEventTodoDrafts', () {
    test('simplifies guidance-heavy flow events to one practice task', () {
      final drafts = buildEventTodoDrafts(
        const EventTodoSource(
          title: 'Lymphatic Healing Flow',
          detail:
              'Ensure your space is comfortable and free of distractions. '
              'Engage in movements that promote healing. Use this link: '
              'https://www.youtube.com/watch?v=6l_2Lc9f-b0. '
              'Focus on fluidity in your movements.',
          location: 'https://www.youtube.com/watch?v=6l_2Lc9f-b0',
          isFlow: true,
        ),
      );

      expect(drafts, hasLength(1));
      expect(drafts.single.title, 'Do Lymphatic Healing Flow');
      expect(drafts.single.notes, contains('https://www.youtube.com'));
    });

    test('splits explicit bullet lists into multiple tasks', () {
      final drafts = buildEventTodoDrafts(
        const EventTodoSource(
          title: 'Errands',
          detail: '- Buy candles\n- Call the venue\n- Pack journal',
        ),
      );

      expect(drafts.map((draft) => draft.title), [
        'Buy candles',
        'Call the venue',
        'Pack journal',
      ]);
    });

    test('keeps noun-only bullet items as separate tasks', () {
      final drafts = buildEventTodoDrafts(
        const EventTodoSource(
          title: 'Shopping',
          detail: '- Candles\n- Incense\n- Journal',
        ),
      );

      expect(drafts.map((draft) => draft.title), [
        'Candles',
        'Incense',
        'Journal',
      ]);
    });

    test('splits compound instructions into separate tasks', () {
      final drafts = buildEventTodoDrafts(
        const EventTodoSource(
          title: 'Party prep',
          detail: 'Buy candles, call the venue, and pack journal.',
        ),
      );

      expect(drafts.map((draft) => draft.title), [
        'Buy candles',
        'Call the venue',
        'Pack journal',
      ]);
      expect(drafts.every((draft) => draft.notes == null), isTrue);
    });

    test('keeps explanatory clauses out of generated task titles', () {
      final drafts = buildEventTodoDrafts(
        const EventTodoSource(
          title: 'Setup',
          detail:
              'Buy candles because the room will be dark, call the venue so you can confirm access, and pack journal.',
        ),
      );

      expect(drafts.map((draft) => draft.title), [
        'Buy candles',
        'Call the venue',
        'Pack journal',
      ]);
      expect(drafts.first.notes, contains('Because the room will be dark'));
      expect(drafts.first.notes, contains('So you can confirm access'));
    });

    test('keeps standalone notes as context instead of tasks', () {
      final drafts = buildEventTodoDrafts(
        const EventTodoSource(
          title: 'Rehearsal',
          detail:
              'Note that the side door code is 4321. Email Ana and print programs.',
        ),
      );

      expect(drafts.map((draft) => draft.title), [
        'Email Ana',
        'Print programs',
      ]);
      expect(drafts.first.notes, contains('The side door code is 4321'));
    });

    test('splits comma-separated task blocks into separate tasks', () {
      final drafts = buildEventTodoDrafts(
        const EventTodoSource(
          title: 'Follow up',
          detail: 'Tasks: email Ana, schedule rehearsal, and print programs',
        ),
      );

      expect(drafts.map((draft) => draft.title), [
        'Email Ana',
        'Schedule rehearsal',
        'Print programs',
      ]);
    });

    test('turns learning-flow instructions into separate practice tasks', () {
      final drafts = buildEventTodoDrafts(
        const EventTodoSource(
          title: 'Starter signs and reading direction',
          detail:
              'Start with these ten Medu Neter unilateral signs: reed leaf = i/y, '
              'quail chick = w/u, owl = m, water ripple = n, mouth = r, '
              'stool = p, foot = b, basket handle = k, bread loaf = t, '
              'and hand = d. Copy each sign three times, say the value aloud, '
              'and note that many signs face the beginning of the text, so you '
              'read toward the faces of people, animals, or birds. You are done '
              'when you can cover the values and identify at least 7 of the 10 '
              'signs from memory.',
          isFlow: true,
        ),
      );

      expect(drafts.map((draft) => draft.title), [
        'Copy each Medu Neter sign 3 times',
        'Say each Medu Neter sign value aloud',
        'Identify at least 7 of 10 Medu Neter signs from memory',
      ]);
      expect(drafts.first.notes, contains('Reference: reed leaf = i/y'));
      expect(
        drafts.first.notes,
        contains('Many signs face the beginning of the text'),
      );
      expect(drafts.first.notes, contains('read toward the faces'));
      expect(drafts.first.notes, isNot(contains('Steps:')));
      expect(drafts.first.notes, isNot(contains('Start with these ten')));
      expect(drafts.skip(1).every((draft) => draft.notes == null), isTrue);
    });

    test('uses reminder title directly when it is already actionable', () {
      final drafts = buildEventTodoDrafts(
        const EventTodoSource(title: 'journal every night', isReminder: true),
      );

      expect(drafts, hasLength(1));
      expect(drafts.single.title, 'Journal every night');
      expect(drafts.single.notes, isNull);
    });

    test('turns located notes into go-to tasks', () {
      final drafts = buildEventTodoDrafts(
        const EventTodoSource(
          title: 'Theater',
          location: 'Hollywood Lutheran Church',
        ),
      );

      expect(drafts.single.title, 'Go to Theater');
      expect(drafts.single.notes, 'Location: Hollywood Lutheran Church');
    });
  });
}
