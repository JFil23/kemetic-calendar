import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/flow_visibility.dart';

void main() {
  test('active flow stays active through its local end date', () {
    expect(
      isFlowActiveLocally(
        active: true,
        endDate: DateTime(2026, 4, 28),
        now: DateTime(2026, 4, 28, 23, 59),
      ),
      isTrue,
    );
  });

  test('inactive flow is never active locally', () {
    expect(
      isFlowActiveLocally(
        active: false,
        endDate: DateTime(2026, 4, 30),
        now: DateTime(2026, 4, 28, 12),
      ),
      isFalse,
    );
  });

  test('hidden flow is excluded from active flow lists', () {
    expect(
      isFlowVisibleLocally(
        active: true,
        isHidden: true,
        endDate: DateTime(2026, 4, 30),
        now: DateTime(2026, 4, 28, 12),
      ),
      isFalse,
    );
  });

  test('visible flow must be active, unhidden, and not locally ended', () {
    expect(
      isFlowVisibleLocally(
        active: true,
        isHidden: false,
        endDate: DateTime(2026, 4, 28),
        now: DateTime(2026, 4, 28, 12),
      ),
      isTrue,
    );

    expect(
      isFlowVisibleLocally(
        active: true,
        isHidden: false,
        endDate: DateTime(2026, 4, 28),
        now: DateTime(2026, 4, 29, 0, 0, 1),
      ),
      isFalse,
    );
  });
}
