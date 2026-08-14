import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hydration publication cannot be vetoed by snapshot persistence', () {
    final source = File(
      'lib/features/calendar/hydration/calendar_hydration_engine.dart',
    ).readAsStringSync();
    final commitStart = source.indexOf(
      'Future<void> commitVisibleCalendarState(',
    );
    final commitEnd = source.indexOf('hydrationPassSucceeded =', commitStart);
    expect(commitStart, greaterThanOrEqualTo(0));
    expect(commitEnd, greaterThan(commitStart));
    final commit = source.substring(commitStart, commitEnd);

    final preparedAt = commit.indexOf('_buildCalendarSnapshotCommit(');
    final publishAt = commit.indexOf(
      '_calendarPresentationCoordinator.publish(',
    );
    final controllerAt = commit.indexOf('_hydrationController.commitViewport(');
    final acceptedAt = commit.indexOf('if (!accepted) {');
    final persistenceAt = commit.indexOf(
      '_enqueueCalendarSnapshotPersistence(',
    );
    expect(preparedAt, greaterThanOrEqualTo(0));
    expect(publishAt, greaterThan(preparedAt));
    expect(controllerAt, greaterThan(publishAt));
    expect(acceptedAt, greaterThan(controllerAt));
    expect(persistenceAt, greaterThan(acceptedAt));
    expect(commit, isNot(contains('await _commitCalendarSnapshotCandidate(')));
    expect(commit, isNot(contains('snapshot_durable_commit_rejected')));
    expect(commit, isNot(contains('_bumpDataVersion')));
    expect(commit, isNot(contains('jumpTo(')));
    expect(commit, isNot(contains('setState(')));
  });

  test('startup prefers the complete snapshot inside one restore flight', () {
    final adapter = File(
      'lib/features/calendar/snapshot/calendar_snapshot_page_adapter.dart',
    ).readAsStringSync();
    final page = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    expect(
      RegExp(
        r'_restoreCalendarSnapshotStoreIfAvailable\(',
      ).allMatches(adapter).length,
      1,
      reason: 'the lossless reader has one implementation',
    );
    final restoreStart = page.indexOf(
      'Future<void> _restoreWarmStartCacheIfAvailable(',
    );
    final restoreEnd = page.indexOf(
      'Future<void> _refreshCalendarStateFromServer()',
      restoreStart,
    );
    expect(restoreStart, greaterThanOrEqualTo(0));
    expect(restoreEnd, greaterThan(restoreStart));
    final restore = page.substring(restoreStart, restoreEnd);
    final snapshotAt = restore.indexOf(
      '_restoreCalendarSnapshotStoreIfAvailable(',
    );
    final legacyPrefsAt = restore.indexOf(
      'final prefs = await SharedPreferences.getInstance()',
    );
    expect(snapshotAt, greaterThanOrEqualTo(0));
    expect(legacyPrefsAt, greaterThan(snapshotAt));
    expect(restore, contains('if (restoredSnapshot)'));
  });

  test('legacy cache failure cannot fail a successful hydration job', () {
    final page = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final engine = File(
      'lib/features/calendar/hydration/calendar_hydration_engine.dart',
    ).readAsStringSync();
    expect(page, contains('Future<void> _persistWarmStartCacheBestEffort('));
    expect(
      page,
      contains('Persistence is deliberately outside presentation authority'),
    );
    expect(engine, contains('_persistWarmStartCacheBestEffort('));
    expect(engine, isNot(contains('await _persistWarmStartCacheNow(')));
  });

  test('startup shell is independent while hydration awaits warm restore', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    expect(source, contains('_loadPersistedViewState();'));
    expect(
      source,
      contains(
        "unawaited(_restoreWarmStartCacheIfAvailable(reason: 'initState'))",
      ),
    );
    expect(source, isNot(contains('_restoreCalendarLocalStartupState(')));

    final restoreStart = source.indexOf(
      'Future<void> _restoreWarmStartCacheIfAvailable(',
    );
    final restoreEnd = source.indexOf(
      'Future<void> _refreshCalendarStateFromServer()',
      restoreStart,
    );
    expect(restoreStart, greaterThanOrEqualTo(0));
    expect(restoreEnd, greaterThan(restoreStart));
    expect(
      source.substring(restoreStart, restoreEnd),
      contains('_restoreCalendarSnapshotStoreIfAvailable('),
    );
  });

  test(
    'server authority never derives from the visible overlay projection',
    () {
      final page = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final notifyStart = page.indexOf(
        'void _notifyDayViewDataChanged({bool scheduleCacheSave = true})',
      );
      final notifyEnd = page.indexOf(
        'void _setHydrationAuthorityScope(',
        notifyStart,
      );
      expect(notifyStart, greaterThanOrEqualTo(0));
      expect(notifyEnd, greaterThan(notifyStart));
      expect(
        page.substring(notifyStart, notifyEnd),
        isNot(contains('_calendarAuthoritativeNotesByDay =')),
      );

      final hydration = File(
        'lib/features/calendar/hydration/calendar_hydration_engine.dart',
      ).readAsStringSync();
      expect(hydration, contains('authoritativeCandidateNotes'));
      expect(hydration, contains('notesByDay: authoritativeNotes'));
      expect(
        hydration,
        contains('for (final entry in authoritativeNotes.entries)'),
      );
    },
  );

  test('refresh failure cannot mutate authority or mount calendar chrome', () {
    final page = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final engine = File(
      'lib/features/calendar/hydration/calendar_hydration_engine.dart',
    ).readAsStringSync();
    final failureStart = page.indexOf('void _recordCalendarRefreshFailure()');
    final failureEnd = page.indexOf(
      'void _handleHydrationControllerStateChanged(',
      failureStart,
    );
    expect(failureStart, greaterThanOrEqualTo(0));
    expect(failureEnd, greaterThan(failureStart));
    final failure = page.substring(failureStart, failureEnd);
    expect(failure, isNot(contains('setState(')));
    expect(failure, isNot(contains('_hydrationController')));
    expect(page, isNot(contains('CalendarHydrationStatusBanner')));
    expect(page, isNot(contains('CalendarHydrationAvailability')));
    expect(engine, isNot(contains('_markCalendarHydrationIncomplete')));
    expect(
      RegExp(r'_recordCalendarRefreshFailure\(\)').allMatches(engine),
      hasLength(1),
      reason: 'only terminal scheduler failure may publish refresh failure',
    );
  });
}
