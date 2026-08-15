import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/calendar_occurrence_identity.dart';

void main() {
  test('reminder identity preserves existing canonical CID', () {
    final identity = CalendarOccurrenceIdentity.reminder(
      reminderId: 'rule-1',
      localDate: DateTime(2026, 8, 15, 19, 30),
    );

    expect(identity.localDate, DateTime(2026, 8, 15));
    expect(identity.canonicalKey, 'reminder:rule-1:2026-08-15');
    expect(
      CalendarOccurrenceIdentity.tryParse(identity.canonicalKey),
      identity,
    );
  });

  test('reminder ids containing colons round-trip', () {
    final identity = CalendarOccurrenceIdentity.tryParse(
      'reminder:nutrition:water:2026-08-15',
    );

    expect(identity, isNotNull);
    expect(identity!.sourceId, 'nutrition:water');
    expect(identity.canonicalKey, 'reminder:nutrition:water:2026-08-15');
  });

  test('invalid or series-only reminder identities are rejected', () {
    expect(CalendarOccurrenceIdentity.tryParse('reminder:rule-1'), isNull);
    expect(
      CalendarOccurrenceIdentity.tryParse('reminder:rule-1:2026-02-30'),
      isNull,
    );
  });
}
