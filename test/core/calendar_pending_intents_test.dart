import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/calendar_pending_intents.dart';

void main() {
  test('database id and cid are aliases for one pending delete', () {
    final ledger = CalendarPendingDeleteLedger();
    final token = ledger.register(
      identity: CalendarMutationIdentity.userEvent(
        databaseId: 'db-1',
        clientEventId: 'cid-1',
      ),
      localDate: DateTime(2026, 8, 15),
    );

    expect(
      ledger.suppress(
        CalendarMutationIdentity.userEvent(clientEventId: 'cid-1'),
      ),
      isTrue,
    );
    expect(
      ledger.suppress(CalendarMutationIdentity.userEvent(databaseId: 'db-1')),
      isTrue,
    );
    expect(token, greaterThan(0));
  });

  test('accepted delete survives passes that still observe the row', () {
    final ledger = CalendarPendingDeleteLedger();
    final identity = CalendarMutationIdentity.userEvent(
      databaseId: 'db-2',
      clientEventId: 'cid-2',
    );
    final token = ledger.register(
      identity: identity,
      localDate: DateTime(2026, 8, 15),
    );
    ledger.acknowledge(token, currentHydrationEpoch: 4);
    ledger.suppress(identity, observedInHydrationEpoch: 5);

    expect(
      ledger.reconcileAcceptedHydration(
        hydrationEpoch: 5,
        windowStartUtc: DateTime(2026, 8, 15).toUtc(),
        windowEndUtc: DateTime(2026, 8, 16).toUtc(),
      ),
      0,
    );
    expect(ledger.length, 1);
  });

  test('accepted later pass retires delete only after observing absence', () {
    final ledger = CalendarPendingDeleteLedger();
    final token = ledger.register(
      identity: CalendarMutationIdentity.userEvent(clientEventId: 'cid-3'),
      localDate: DateTime(2026, 8, 15),
    );
    ledger.acknowledge(token, currentHydrationEpoch: 7);

    expect(
      ledger.reconcileAcceptedHydration(
        hydrationEpoch: 7,
        windowStartUtc: DateTime(2026, 8, 15).toUtc(),
        windowEndUtc: DateTime(2026, 8, 16).toUtc(),
      ),
      0,
    );
    expect(
      ledger.reconcileAcceptedHydration(
        hydrationEpoch: 8,
        windowStartUtc: DateTime(2026, 8, 15).toUtc(),
        windowEndUtc: DateTime(2026, 8, 16).toUtc(),
      ),
      1,
    );
    expect(ledger.isEmpty, isTrue);
  });

  test('fallback identity is used only without a stable alias', () {
    final stable = CalendarMutationIdentity.userEvent(
      databaseId: 'db-4',
      fallbackKey: 'same-shape',
    );
    final fallback = CalendarMutationIdentity.userEvent(
      fallbackKey: 'same-shape',
    );

    expect(stable.matches(fallback), isFalse);
    expect(fallback.aliases, <String>{'fallback:same-shape'});
  });
}
