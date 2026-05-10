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
