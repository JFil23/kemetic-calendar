import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hydration publishes only after a verified durable candidate', () {
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

    final durableAt = commit.indexOf('await _commitCalendarSnapshotCandidate(');
    final publishAt = commit.indexOf(
      '_calendarPresentationCoordinator.publish(',
    );
    final controllerAt = commit.indexOf('_hydrationController.commitViewport(');
    expect(durableAt, greaterThanOrEqualTo(0));
    expect(publishAt, greaterThan(durableAt));
    expect(controllerAt, greaterThan(publishAt));
    expect(commit, isNot(contains('_bumpDataVersion')));
    expect(commit, isNot(contains('jumpTo(')));
    expect(commit, isNot(contains('setState(')));
  });

  test('snapshot restore cannot overwrite a newer projection', () {
    final source = File(
      'lib/features/calendar/snapshot/calendar_snapshot_page_adapter.dart',
    ).readAsStringSync();
    expect(source, contains('projectionRevisionAtStart'));
    expect(source, contains('snapshot_restore_superseded'));
    expect(source, isNot(contains('setState(')));
    expect(source, contains('_publishCalendarMonthProjections('));
    expect(source, contains('_activeCalendarCoverage ='));
  });

  test('startup resolves local data authority before opening first paint', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final bootstrapStart = source.indexOf(
      'Future<void> _restoreCalendarLocalStartupState(',
    );
    final bootstrapEnd = source.indexOf(
      'void _scheduleDaySheetResumeRestore()',
      bootstrapStart,
    );
    expect(bootstrapStart, greaterThanOrEqualTo(0));
    expect(bootstrapEnd, greaterThan(bootstrapStart));
    final bootstrap = source.substring(bootstrapStart, bootstrapEnd);
    final snapshotAt = bootstrap.indexOf(
      'await _restoreWarmStartCacheIfAvailable(',
    );
    final viewAt = bootstrap.indexOf('await _loadPersistedViewState()');
    expect(snapshotAt, greaterThanOrEqualTo(0));
    expect(viewAt, greaterThan(snapshotAt));
    expect(
      source,
      isNot(
        contains(
          "unawaited(_restoreWarmStartCacheIfAvailable(reason: 'initState'))",
        ),
      ),
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

  test('sync banner is listenable-owned and never page-setState-owned', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final failureStart = source.indexOf(
      'void _markCalendarHydrationIncomplete()',
    );
    final failureEnd = source.indexOf(
      'void _handleHydrationControllerStateChanged(',
      failureStart,
    );
    expect(failureStart, greaterThanOrEqualTo(0));
    expect(failureEnd, greaterThan(failureStart));
    final failure = source.substring(failureStart, failureEnd);
    expect(failure, isNot(contains('setState(')));
    expect(source, contains('ValueListenableBuilder<CalendarHydrationStatus>'));
    expect(source, contains('visibleViewportComplete:'));
    expect(source, contains('lastSuccessfulRefreshAtUtc:'));
    expect(source, contains('latestRefreshStatus:'));
  });
}
