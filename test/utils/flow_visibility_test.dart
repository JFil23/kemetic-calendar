import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/flow_visibility.dart';

void main() {
  test('enabled flow is controlled by the active flag', () {
    expect(isFlowEnabled(active: true), isTrue);
    expect(isFlowEnabled(active: false), isFalse);
  });

  test('hidden flow is excluded from active flow lists', () {
    expect(isFlowVisibleInLists(active: true, isHidden: true), isFalse);
  });

  test('list visibility ignores end date and follows active plus hidden', () {
    expect(isFlowVisibleInLists(active: true, isHidden: false), isTrue);

    expect(isFlowVisibleInLists(active: false, isHidden: false), isFalse);
  });

  test('schedule-open helper keeps end date local and inclusive', () {
    expect(
      isFlowScheduleOpenLocally(
        active: true,
        endDate: DateTime(2026, 4, 28),
        now: DateTime(2026, 4, 28, 23, 59),
      ),
      isTrue,
    );

    expect(
      isFlowScheduleOpenLocally(
        active: true,
        endDate: DateTime(2026, 4, 28),
        now: DateTime(2026, 4, 29, 0, 0, 1),
      ),
      isFalse,
    );
  });
}
