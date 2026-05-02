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
        unorderedEquals(<String>['lib/services/session_resume_service.dart']),
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
