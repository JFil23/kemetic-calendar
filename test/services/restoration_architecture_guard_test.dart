import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('restoration architecture guard', () {
    test('scoped session persistence stays in the approved files', () async {
      final matches = await _filesContainingAny(<String>[
        'SessionResumeService.saveScopedState',
        'SessionResumeService.readScopedState',
      ]);

      expect(
        matches,
        unorderedEquals(<String>[
          'lib/features/calendar/calendar_page.dart',
          'lib/features/rhythm/pages/todays_alignment_page.dart',
        ]),
      );
    });

    test('permanent restoration writes stay in the approved files', () async {
      final saveCalendarMatches = await _filesContainingAny(<String>[
        'AppRestorationService.instance.saveCalendarState',
      ]);
      expect(
        saveCalendarMatches,
        unorderedEquals(<String>['lib/features/calendar/calendar_page.dart']),
      );

      final saveDayViewMatches = await _filesContainingAny(<String>[
        'AppRestorationService.instance.saveDayViewState',
      ]);
      expect(
        saveDayViewMatches,
        unorderedEquals(<String>['lib/features/calendar/calendar_page.dart']),
      );

      final saveDaySheetMatches = await _filesContainingAny(<String>[
        'AppRestorationService.instance.saveDaySheetState',
      ]);
      expect(
        saveDaySheetMatches,
        unorderedEquals(<String>['lib/features/calendar/calendar_page.dart']),
      );

      final saveRouteMatches = await _filesContainingAny(<String>[
        'AppRestorationService.instance.saveRouteLocation',
      ]);
      expect(
        saveRouteMatches,
        unorderedEquals(<String>['lib/services/restoration_coordinator.dart']),
      );
    });

    test('calendar action entrypoints stay centralized', () async {
      final menuMatches = await _filesContainingAny(<String>[
        'showActionsMenuFromOutside(',
        'openQuickAddFromOutside(',
      ]);
      expect(
        menuMatches,
        unorderedEquals(<String>['lib/features/calendar/calendar_page.dart']),
      );

      final unavailableMatches = await _filesContainingAny(<String>[
        'Menu is unavailable right now.',
        'Calendar actions are unavailable right now.',
        'New note is unavailable right now.',
      ]);
      expect(unavailableMatches, isEmpty);
    });

    test('today toolbar actions use the calendar glyph', () async {
      final deprecatedTodayIconMatches = await _filesContainingAny(<String>[
        'Icons.calendar_today_outlined',
      ]);
      expect(deprecatedTodayIconMatches, isEmpty);

      final calendarIconMatches = await _filesContainingAny(<String>[
        'Icons.today',
      ]);
      expect(
        calendarIconMatches,
        containsAll(<String>[
          'lib/features/calendar/calendar_page.dart',
          'lib/features/calendar/day_view_chrome.dart',
          'lib/features/profile/profile_page.dart',
          'lib/features/rhythm/pages/todays_alignment_page.dart',
        ]),
      );
    });

    test('calendar sheet continuity keeps the boot retry restorer', () async {
      final main = await File('lib/main.dart').readAsString();
      final calendar = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();

      expect(main, contains('_restoreDetachedCalendarOverlayAfterBoot'));
      expect(main, contains('restoreDetachedCalendarOverlayFromAnyContext'));
      expect(
        calendar,
        contains('RestorationCoordinator.instance.readBestSnapshot'),
      );
      expect(main, isNot(contains('CalendarContinuityOverlayHost')));
      expect(calendar, isNot(contains('CalendarContinuityOverlayHost')));
    });

    test(
      'calendar sheet continuity retries after route and auth settle',
      () async {
        final main = await File('lib/main.dart').readAsString();
        final bootRetry = _sourceBetween(
          main,
          'Future<void> _restoreDetachedCalendarOverlayAfterBoot() async',
          'Future<void> _dismissOverlay() async',
        );
        final authResume = _sourceBetween(
          main,
          'Future<void> _maybeResumeSessionRoute() async',
          '// -- Log app_open once per cold start after auth is present',
        );

        expect(
          main,
          contains('unawaited(_restoreDetachedCalendarOverlayAfterBoot())'),
        );
        expect(bootRetry, contains('attempt < 30'));
        expect(bootRetry, contains('Duration(milliseconds: 150)'));
        expect(bootRetry, contains('_rootNavigatorKey.currentContext'));
        expect(bootRetry, contains('currentConfiguration.uri'));
        expect(
          bootRetry,
          contains('restoreDetachedCalendarOverlayFromAnyContext'),
        );
        expect(bootRetry, contains('currentLocation: currentLocation'));

        expect(authResume, contains('restorableOverlayParentRouteFromStack'));
        expect(authResume, contains('readOverlayStack()'));
        expect(authResume, contains('readRouteLocation('));
        expect(authResume, contains('includeRemote: true'));
        expect(authResume, contains('_router.go(savedLocation)'));
        expect(authResume, contains('addPostFrameCallback'));
        expect(
          authResume,
          contains('restoreDetachedCalendarOverlayFromAnyContext'),
        );
        expect(authResume, contains('currentLocation: savedLocation'));
      },
    );

    test(
      'calendar sheets save and restore from atomic overlay snapshots',
      () async {
        final calendar = await File(
          'lib/features/calendar/calendar_page.dart',
        ).readAsString();
        final saveDetached = _sourceBetween(
          calendar,
          'static Future<void> _saveDetachedCalendarOverlayState({',
          'static Future<void> _clearDetachedCalendarOverlayState',
        );
        final clearDetached = _sourceBetween(
          calendar,
          'static Future<void> _clearDetachedCalendarOverlayState',
          'static Future<void> showActionsMenuFromAnyContext',
        );
        final restoreDetached = _sourceBetween(
          calendar,
          'static Future<bool> restoreDetachedCalendarOverlayFromAnyContext',
          'static Future<void> shareFlowFromEvent',
        );
        final rootRestore = _sourceBetween(
          calendar,
          'Future<void> _restorePersistentCalendarOverlayWithRetries',
          'Future<void> _restoreFlowStudioOverlay',
        );

        expect(saveDetached, contains('recordRouteLocationWithOverlayStack'));
        expect(saveDetached, contains("'parentRoute': normalizedParentRoute"));
        expect(
          saveDetached,
          contains('SessionResumeService.saveRouteLocation'),
        );
        expect(saveDetached, contains('RestorationCoordinator.instance.flush'));

        expect(
          clearDetached,
          contains('shouldPreserveOverlayForLifecycleClose'),
        );
        expect(clearDetached, contains('readOverlayStack()'));
        expect(clearDetached, contains('saveOverlayStack(next)'));

        expect(restoreDetached, contains('readBestSnapshot'));
        expect(
          restoreDetached,
          contains(
            'includeRemote: Supabase.instance.client.auth.currentSession != null',
          ),
        );
        expect(
          restoreDetached,
          contains('_sameRouteLocation(activeLocation, parentRoute)'),
        );
        expect(
          restoreDetached,
          contains('_lastDetachedCalendarOverlayRestoreKey'),
        );
        expect(restoreDetached, contains('_openDetachedSharedCalendarsSheet'));
        expect(restoreDetached, contains('_openDetachedFlowStudioSheet'));

        expect(rootRestore, contains('attempt < 30'));
        expect(rootRestore, contains('Duration(milliseconds: 150)'));
        expect(rootRestore, contains('readBestSnapshot'));
        expect(rootRestore, contains('_openSharedCalendarsSheet'));
        expect(rootRestore, contains('_restoreFlowStudioOverlay'));
      },
    );
  });
}

Future<List<String>> _filesContainingAny(List<String> needles) async {
  final matches = <String>[];
  await for (final entity in Directory('lib').list(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    final contents = await entity.readAsString();
    if (needles.any(contents.contains)) {
      matches.add(_normalizePath(entity.path));
    }
  }
  matches.sort();
  return matches;
}

String _normalizePath(String path) => path.replaceAll('\\', '/');

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNot(-1), reason: 'Missing source marker: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNot(-1), reason: 'Missing source marker: $end');
  return source.substring(startIndex, endIndex);
}
