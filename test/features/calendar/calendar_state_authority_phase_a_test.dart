import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Behavior-preserving guards for calendar state-authority work.
///
/// Grows with each independently revertable commit. Phase 0 is the harness;
/// later commits add their control-point assertions.
void main() {
  late String calendarPageSource;

  setUpAll(() async {
    calendarPageSource = await File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsString();
  });

  test('Phase 0 baseline encoder exists for CI capture', () {
    expect(
      calendarPageSource,
      contains('debugCanonicalHydrationBaselineJson'),
    );
    expect(calendarPageSource, contains("copy.remove('resolvedColor')"));
    expect(
      File('test/features/calendar/fixtures/hydration_baseline.json').existsSync(),
      isTrue,
    );
  });

  test('PR1 keeps _nextFlowId monotonic at warm-start and load commit', () {
    expect(
      calendarPageSource,
      contains('_nextFlowId = math.max(_nextFlowId, nextFlowId)'),
    );
    expect(
      calendarPageSource.contains('_nextFlowId = nextFlowId;\n'),
      isFalse,
      reason: 'load commit must not assign nextFlowId outright',
    );
  });

  test('PR2 signedOut clears live maps and tombstone load-once only', () {
    final block = calendarPageSource.substring(
      calendarPageSource.indexOf('if (event == AuthChangeEvent.signedOut) {'),
      calendarPageSource.indexOf('// Initialize journal controller'),
    );
    expect(block, contains('_flows.clear()'));
    expect(block, contains('_notes.clear()'));
    expect(block, contains('_manualDeleteTombstones.clear()'));
    expect(block, contains('_pendingDeleteKeys.clear()'));
    expect(block, contains('_endedReminderIds.clear()'));
    expect(block, contains('_manualTombstonesLoaded = false'));
    expect(block, contains('_manualTombstonesLoad = null'));
    expect(
      block.contains('_endedReminderIdsLoaded'),
      isFalse,
      reason: '_loadEndedReminderIds has no load-once guard',
    );
  });

  test('PR3 warm-start persist revalidates user after prefs await', () {
    final persist = calendarPageSource.substring(
      calendarPageSource.indexOf('Future<void> _persistWarmStartCacheNow({'),
      calendarPageSource.indexOf(
        'Future<void> _restoreWarmStartCacheIfAvailable({',
      ),
    );
    expect(
      persist,
      contains('final prefs = await SharedPreferences.getInstance()'),
    );
    expect(persist, contains('final currentUserId = _activeWarmStartUserId()'));
    expect(persist, contains('currentUserId != resolvedUserId'));
  });

  test('PR4 warm-start claims slot and abandons when server hydration won', () {
    expect(calendarPageSource, contains('_warmStartRestoreInFlightForUserId'));
    expect(calendarPageSource, contains('_serverHydrationCommittedForUserId'));
    final restore = calendarPageSource.substring(
      calendarPageSource.indexOf(
        'Future<void> _restoreWarmStartCacheIfAvailable({',
      ),
      calendarPageSource.indexOf('Future<void> _loadCalendarState() async {'),
    );
    expect(
      restore.indexOf('_warmStartRestoreInFlightForUserId = userId'),
      lessThan(restore.indexOf('await _loadEndedReminderIds()')),
    );
    expect(restore, contains('_serverHydrationCommittedForUserId == userId'));
    expect(restore, contains('finally {'));

    const commitMarker =
        '_serverHydrationCommittedForUserId = _activeWarmStartUserId()';
    expect(calendarPageSource, contains(commitMarker));
    expect(
      restore.contains(commitMarker),
      isFalse,
      reason: 'warm-start must not set the server-hydration sentinel',
    );
  });

  test('PR5 routes tombstone and reminder prefs through CalendarUserScopedPrefs', () {
    expect(
      calendarPageSource,
      contains('CalendarUserScopedPrefs.readStringList'),
    );
    expect(
      calendarPageSource,
      contains('CalendarUserScopedPrefs.writeStringList'),
    );
    expect(calendarPageSource, contains('CalendarUserScopedPrefs.readBool'));
    expect(
      File('lib/features/calendar/calendar_user_scoped_prefs.dart').existsSync(),
      isTrue,
    );
  });
}
