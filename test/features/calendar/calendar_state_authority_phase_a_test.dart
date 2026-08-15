import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Behavior-preserving guards for calendar state-authority work.
///
/// Grows with each independently revertable commit. Phase 0 is the harness;
/// later commits add their control-point assertions.
void main() {
  late String calendarPageSource;

  setUpAll(() async {
    calendarPageSource =
        await File('lib/features/calendar/calendar_page.dart').readAsString() +
        await File(
          'lib/features/calendar/hydration/calendar_hydration_engine.dart',
        ).readAsString() +
        await File(
          'lib/features/calendar/snapshot/calendar_presentation_page_adapter.dart',
        ).readAsString();
  });

  test('Phase 0 baseline encoder exists for CI capture', () {
    expect(calendarPageSource, contains('debugCanonicalHydrationBaselineJson'));
    expect(calendarPageSource, contains("copy.remove('resolvedColor')"));
    expect(
      File(
        'test/features/calendar/fixtures/hydration_baseline.json',
      ).existsSync(),
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

  test('PR2 signedOut clears live maps and in-memory end guards', () {
    final block = calendarPageSource.substring(
      calendarPageSource.indexOf('if (event == AuthChangeEvent.signedOut) {'),
      calendarPageSource.indexOf('// Construct the journal controller now'),
    );
    expect(
      block,
      contains('_calendarPresentationCoordinator.changeUserScope(null)'),
    );
    final clearScope = calendarPageSource.substring(
      calendarPageSource.indexOf('void _clearCalendarPresentationScope('),
    );
    expect(clearScope, contains('_flows.clear()'));
    expect(clearScope, contains('_notes.clear()'));
    expect(block, contains('_manualDeleteTombstones.clear()'));
    expect(block, contains('_pendingDeletes.clear()'));
    expect(block, contains('_endedReminderIds.clear()'));
    expect(block, contains('_manualTombstonesLoaded = false'));
    expect(block, contains('_manualTombstonesLoad = null'));
    expect(
      calendarPageSource.contains('_loadEndedReminderIds'),
      isFalse,
      reason: 'ended reminder authority belongs to the account-backed flow',
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
      calendarPageSource.indexOf(
        'Future<void> _refreshCalendarStateFromServer() async {',
      ),
    );
    expect(
      restore.indexOf('_warmStartRestoreInFlightForUserId = userId'),
      lessThan(restore.indexOf('await _loadOccurrenceExclusions()')),
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

  test('PR5 routes tombstone and reminder lists through user-scoped prefs', () {
    expect(
      calendarPageSource,
      contains('CalendarUserScopedPrefs.readStringList'),
    );
    expect(
      calendarPageSource,
      contains('CalendarUserScopedPrefs.writeStringList'),
    );
    expect(
      File(
        'lib/features/calendar/calendar_user_scoped_prefs.dart',
      ).existsSync(),
      isTrue,
    );
  });

  test('hydration controller and scheduler replace the legacy coordinator', () {
    expect(
      File('lib/features/calendar/calendar_load_coordinator.dart').existsSync(),
      isFalse,
    );
    expect(
      calendarPageSource,
      contains('CalendarHydrationScheduler _hydrationScheduler'),
    );
    expect(
      calendarPageSource,
      contains('CalendarHydrationController _hydrationController'),
    );
    expect(calendarPageSource, contains('_hydrationController.signOut()'));
    expect(
      calendarPageSource,
      contains('_hydrationController.commitViewport('),
    );
    expect(
      calendarPageSource,
      contains('_hydrationController.commitBackgroundInterval('),
    );
  });

  test('PR7 wires unconfirmed ledger after PR6 commit guards', () {
    expect(
      File(
        'lib/features/calendar/calendar_unconfirmed_notes.dart',
      ).existsSync(),
      isTrue,
    );
    expect(
      calendarPageSource,
      contains("part 'calendar_unconfirmed_notes.dart';"),
    );
    expect(calendarPageSource, contains('_UnconfirmedNoteLedger _unconfirmed'));
    expect(calendarPageSource, contains('_unconfirmed.clear()'));
    expect(
      calendarPageSource,
      contains('confirmation: NoteConfirmation.unconfirmed'),
    );
    expect(
      RegExp(
        r'confirmation:\s*NoteConfirmation\.unconfirmed',
      ).allMatches(calendarPageSource).length,
      3,
      reason:
          'optimistic standalone saves, their reconciliation fallback, and '
          'staged Ma_at joins must survive hydration',
    );
    final commitStart = calendarPageSource.indexOf(
      'Future<void> commitVisibleCalendarState(',
    );
    final commitSlice = calendarPageSource.substring(
      commitStart,
      calendarPageSource.indexOf('hydrationPassSucceeded =', commitStart),
    );
    expect(commitSlice.indexOf('_unconfirmed.mergeInto('), isNonNegative);
    expect(
      commitSlice.indexOf('_unconfirmed.mergeInto('),
      lessThan(commitSlice.indexOf('_hydrationController.commitViewport(')),
      reason: 'the non-mutating overlay preview precedes controller commit',
    );
    expect(
      commitSlice.indexOf('_unconfirmed.forgetCids('),
      greaterThan(commitSlice.indexOf('if (!accepted) {')),
      reason: 'confirmed overlay rows retire only after acceptance',
    );
  });

  test('PR10a drops full hydrate on early-success single-note delete', () {
    expect(
      calendarPageSource.contains("await _loadFromDisk(source: 'delete')"),
      isFalse,
    );
    expect(calendarPageSource, contains("reason: 'repeat_scope_delete_"));
    final earlySuccessArm = calendarPageSource.substring(
      calendarPageSource.indexOf('[delete-note] ✅ SUCCESS: Deleted by id='),
      calendarPageSource.indexOf(
        'Priority 3: Pre-fetch events from Supabase to gather other possible flowIds',
      ),
    );
    expect(earlySuccessArm.contains('_loadFromDisk('), isFalse);
    expect(earlySuccessArm, contains('return true;'));
  });

  test('staged flow producers share one local rollback helper', () {
    expect(calendarPageSource, contains('_rollbackStagedFlowLocally'));
    expect(
      RegExp(
        r'await (?:state\.)?_rollbackStagedFlowLocally\(',
      ).allMatches(calendarPageSource).length,
      3,
      reason:
          'Ma_at, Flow Studio, and shared import failures use the centralized rollback',
    );
    final helper = calendarPageSource.substring(
      calendarPageSource.indexOf('Future<void> _rollbackStagedFlowLocally('),
      calendarPageSource.indexOf(
        'int _removeLocalNotesForFlowReplacement(int flowId)',
      ),
    );
    expect(helper, contains('_flows.removeWhere'));
    expect(
      helper,
      contains('notes.removeWhere((note) => note.flowId == serverFlowId)'),
    );
    expect(helper, contains('await repo.deleteFlow(serverFlowId)'));
    expect(helper, contains('await repo.deleteByFlowId('));
    expect(
      helper.contains('_removeLocalNotesForFlowReplacement('),
      isFalse,
      reason: 'inline prune must not call the flowId<=0 guard helper',
    );
    expect(
      calendarPageSource.contains(
        '_flows.removeWhere((flow) => flow.id == serverFlowId);\n'
        '        final emptyKeys = <String>[];',
      ),
      isFalse,
      reason: 'inline maat rollback bodies must be gone',
    );
  });
}
