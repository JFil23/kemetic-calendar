import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('user-flow appearance stays out of authored Ma_at owners', () async {
    const authoredOwners = <String>[
      'lib/features/calendar/presentation/instrument_event_presentation_frame.dart',
      'lib/features/calendar/presentation/maat_flow_detail_shell.dart',
      'lib/features/calendar/follow_the_sky',
      'lib/features/calendar/the_offering_table',
      'lib/features/calendar/the_reading_house',
      'lib/features/calendar/the_djed',
      'lib/features/calendar/the_kar',
    ];

    for (final path in authoredOwners) {
      final entity = FileSystemEntity.typeSync(path);
      final files = switch (entity) {
        FileSystemEntityType.file => <File>[File(path)],
        FileSystemEntityType.directory =>
          Directory(path)
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))
              .toList(growable: false),
        _ => <File>[],
      };
      for (final file in files) {
        final source = await file.readAsString();
        expect(
          source,
          isNot(contains('UserFlowAppearance')),
          reason: '${file.path} must remain an authored-flow owner',
        );
        expect(
          source,
          isNot(contains("data/flow_appearance.dart")),
          reason: '${file.path} must not depend on user-flow appearance',
        );
      }
    }
  });

  test(
    'custom appearance is additive and explicitly excludes Ma_at flows',
    () async {
      final detail = await File(
        'lib/features/calendar/calendar_flow_pages.dart',
      ).readAsString();
      final dayView = await File(
        'lib/features/calendar/day_view.dart',
      ).readAsString();

      expect(
        detail,
        contains('meta.maatKey == null && !flow.appearance.isEmpty'),
      );
      expect(
        detail,
        contains("'flow-dashboard-\${flow.id}-\${widget.mode.name}'"),
      );
      expect(detail, isNot(contains('_buildAppearanceDashboardBody')));
      expect(detail, isNot(contains('_buildUserFlowKemeticCalendar')));
      expect(detail, isNot(contains('_buildAppearanceOccurrence')));
      expect(detail, isNot(contains('MaatFlowDetailShell(')));
      expect(detail, isNot(contains('MaatFlowThirtyDayCalendar(')));
      expect(dayView, contains('!isMaatFlow && !flow.appearance.isEmpty'));
      expect(dayView, contains('user-flow-day-sheet-fixed-appearance'));
      expect(dayView, contains('user-flow-day-sheet-foreground-scroll'));
      expect(
        dayView,
        contains('_maatFlowCompletionContextForEvent(event, flow) == null'),
      );
    },
  );
}
