import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'legacy generic hydration pipeline is absent from the shipped build',
    () {
      final page = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      expect(page, isNot(contains('CalendarLoadCoordinator')));
      expect(page, isNot(contains('_loadFromDisk(')));
      expect(page, isNot(contains('_runStartupPipeline')));
      expect(page, isNot(contains('_runProgressiveStartupBackfill')));
      expect(page, isNot(contains('_startupHydrationLaneBudget')));
      expect(page, isNot(contains('fastStartupMode')));
      expect(page, isNot(contains('warmStartBackfillMode')));
      expect(
        File(
          'lib/features/calendar/calendar_load_coordinator.dart',
        ).existsSync(),
        isFalse,
      );
    },
  );

  test('page hydration reads are routed through the typed scheduler seam', () {
    final pagePath = 'lib/features/calendar/calendar_page.dart';
    final pageSource = File(pagePath).readAsStringSync();
    final page = <String>[
      pagePath,
      'lib/features/calendar/hydration/calendar_hydration_page_adapter.dart',
      'lib/features/calendar/hydration/calendar_hydration_engine.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    expect(page, contains('CalendarHydrationScheduler _hydrationScheduler'));
    expect(page, contains('CalendarHydrationController _hydrationController'));
    expect(page, contains('_CalendarHydrationRequest.provisionalViewport'));
    expect(page, contains('_CalendarHydrationRequest.catalogReconcile'));
    expect(page, contains('_CalendarHydrationRequest.background'));
    expect(page, contains('_CalendarHydrationRequest.targeted'));
    expect(pageSource, isNot(contains('.getAllFlows(')));
    expect(pageSource, isNot(contains('.getEventsForFlowIds(')));
    expect(pageSource, isNot(contains('.getStandaloneEventsForDateRangeAll(')));
  });

  test('repository use is confined to the hydration engine and repository', () {
    final calendarDirectory = Directory('lib/features/calendar');
    final offenders = <String>[];
    for (final entity in calendarDirectory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final normalized = entity.path.replaceAll('\\', '/');
      if (normalized.endsWith('hydration/calendar_hydration_repository.dart') ||
          normalized.endsWith('hydration/calendar_hydration_engine.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      if (source.contains('CalendarHydrationRepository')) {
        offenders.add(normalized);
      }
    }
    expect(offenders, isEmpty);
  });

  test('page-owned network maintenance cannot race visible startup', () {
    final page = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final initState = _sourceBetween(
      page,
      '  @override\n'
          '  void initState() {\n'
          '    super.initState();\n'
          '    EndFlowAuthReadiness.instance',
      '  void _scheduleDaySheetResumeRestore()',
    );
    final background = _sourceBetween(
      page,
      '  Future<void> _runBackgroundHydration({',
      '  Future<void> _refreshHydrationAccounting()',
    );

    expect(page, isNot(contains('_migrateOldClientEventIds')));
    expect(page, isNot(contains('legacyMigration')));
    expect(initState, isNot(contains('_journalController.init().then')));
    expect(initState, isNot(contains('_maybePresentOnboarding()')));
    expect(
      background,
      contains('CalendarHydrationIntentKind.journalMaintenance'),
    );
    expect(
      background,
      contains('CalendarHydrationIntentKind.onboardingMaintenance'),
    );
    expect(
      background.indexOf('post_viewport_journal'),
      lessThan(background.indexOf('_hydrateFullHorizon(')),
    );
  });

  test('viewport movement cannot remain provisional indefinitely', () {
    final page = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final refresh = _sourceBetween(
      page,
      '  Future<CalendarHydrationJobDisposition> _refreshVisibleViewport({',
      '  HydrationSelectedDaySnapshot _hydrationSelectedDaySnapshot(',
    );

    expect(refresh, contains('_CalendarHydrationRequest.provisionalViewport'));
    expect(refresh, contains('_CalendarHydrationRequest.catalogReconcile'));
    expect(refresh, contains('state.authority =='));
    expect(
      page,
      contains(
        '_refreshVisibleViewport(\n            reason: \'viewport_\$reason\'',
      ),
    );
    expect(page, contains("reason: 'day_view_open'"));
    expect(page, contains("reason: 'day_view_navigated'"));
  });
}

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(startIndex, greaterThanOrEqualTo(0), reason: 'missing $start');
  expect(endIndex, greaterThan(startIndex), reason: 'missing $end');
  return source.substring(startIndex, endIndex);
}
