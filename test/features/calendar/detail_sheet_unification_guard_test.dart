import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String dayView;
  late String calendarPage;
  late String calendarGridWidgets;
  late String landscapeMonthView;

  setUpAll(() {
    dayView = File('lib/features/calendar/day_view.dart').readAsStringSync();
    calendarPage = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    calendarGridWidgets = File(
      'lib/features/calendar/calendar_grid_widgets.dart',
    ).readAsStringSync();
    landscapeMonthView = File(
      'lib/features/calendar/landscape_month_view.dart',
    ).readAsStringSync();
  });

  test(
    'Day View, Main Calendar, and Landscape all use the shared detail sheet',
    () {
      expect(
        dayView,
        contains('class CalendarEventDetailSheet extends StatefulWidget'),
      );

      final dayViewOpener = _sourceBetween(
        dayView,
        '  // Show event detail sheet\n  void _showEventDetail(',
        '\n}\n\nclass _TheCourseDayCardPanel',
      );
      final mainCalendarOpener = _sourceBetween(
        calendarPage,
        '  Future<void> _openCalendarEventDetailSheet(',
        '  Future<bool> _restoreCalendarEventDetailOverlay(',
      );
      final mainGridChipOpener = _sourceBetween(
        calendarGridWidgets,
        '  void _showEventDetailFromNote(',
        '\n}\n\nclass _ColorDot',
      );
      final landscapeOpener = _sourceBetween(
        landscapeMonthView,
        '  void _showEventDetail(',
        '  Map<EventItem, int> _assignColumns(',
      );

      for (final opener in <String>[
        dayViewOpener,
        mainCalendarOpener,
        mainGridChipOpener,
        landscapeOpener,
      ]) {
        expect(opener, contains('CalendarEventDetailSheet('));
        expect(opener, contains('backgroundColor: Colors.transparent'));
        expect(opener, contains('onAppendToJournal:'));
        expect(opener, contains('onWriteJournalResponse:'));
        expect(opener, contains('onRecordCompletion:'));
        expect(opener, contains('onUnrecordCompletion:'));
        expect(opener, contains('onRemoveCompletionBadge:'));
      }

      expect(calendarPage, isNot(contains('_MainCalendarEventDetailSheet')));
      expect(
        calendarGridWidgets,
        isNot(contains('_MainCalendarEventDetailSheet')),
      );
      expect(
        calendarGridWidgets,
        isNot(contains('_buildEventDetailSheetPage')),
      );
      expect(landscapeMonthView, isNot(contains('_buildEventDetailSheetPage')));
      expect(
        landscapeMonthView,
        isNot(contains('_buildEventDetailTopActionRow')),
      );
      expect(
        landscapeMonthView,
        isNot(contains('_buildEventDetailBottomActionRow')),
      );
    },
  );

  test('shared detail sheet frame owns the matte backplate', () {
    final frame = _sourceBetween(
      dayView,
      'class DayViewBottomSheetFrame extends StatelessWidget',
      'class CalendarEventDetailSheet extends StatefulWidget',
    );
    expect(frame, contains('Positioned.fill'));
    expect(frame, contains('IgnorePointer'));
    expect(frame, contains('Color(0xF7070605)'));
    expect(frame, contains('Color(0xFA050403)'));
    expect(frame, contains('BoxShadow'));

    final sharedSheetHost = _sourceBetween(
      dayView,
      '  Widget _buildSheet(BuildContext context, Object? completionReloadSignal) {',
      '  String _formatTimeRange(int startMin, int endMin) {',
    );
    expect(sharedSheetHost, contains('DayViewBottomSheetFrame('));

    final detailCardBuilder = _sourceBetween(
      dayView,
      '  Widget _buildEventDetailSheetPage({',
      '  Widget _buildEventDetailTopActionRow({',
    );
    expect(detailCardBuilder, isNot(contains('DayViewBottomSheetFrame(')));
  });

  test('Main Calendar keeps rendering behind detail and quick-add sheets', () {
    final overlayGate = _sourceBetween(
      calendarPage,
      '  static bool get _hasCalendarOwnedTransientOverlayOpenOrOpening {',
      '  static Future<void> dismissAppOwnedTransientOverlaysForRouteChange(',
    );
    expect(
      overlayGate,
      contains('CalendarEventDetailSheetCoordinator.isOpenOrOpening'),
    );
    expect(overlayGate, contains('_calendarOwnedTransientRouteDepth > 0'));
    expect(
      overlayGate,
      contains('(mountedState?._daySheetOpenOrOpening ?? false)'),
    );
    expect(
      overlayGate,
      contains('(mountedState?._quickAddSheetOpenOrOpening ?? false)'),
    );

    final buildGate = _sourceBetween(
      calendarPage,
      '    final routeIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;',
      '    final scaffold = Scaffold(',
    );
    expect(buildGate, contains('final routeShouldRemainRendered ='));
    expect(
      buildGate,
      contains('CalendarPage._hasCalendarOwnedTransientOverlayOpenOrOpening'),
    );
    expect(buildGate, contains('if (!routeShouldRemainRendered)'));
  });

  test('Main Calendar quick-add sheet uses transparent route background', () {
    final quickAddOpener = _sourceBetween(
      calendarPage,
      '  Future<void> _openQuickAddSheet() async {',
      '  /* ───── UI ───── */',
    );
    expect(quickAddOpener, contains('backgroundColor: Colors.transparent'));
    expect(quickAddOpener, contains('_quickAddSheetOpenOrOpening = true'));
    expect(quickAddOpener, contains('_quickAddSheetOpenOrOpening = false'));

    final quickAddSheet = _sourceBetween(
      calendarPage,
      'class _QuickAddSheetState extends State<_QuickAddSheet> {',
      'enum MonthExpansionLevel',
    );
    expect(quickAddSheet, contains('Material('));
    expect(quickAddSheet, contains('color: Colors.black'));
    expect(quickAddSheet, contains('clipBehavior: Clip.antiAlias'));
  });
}

String _sourceBetween(String source, String startNeedle, String endNeedle) {
  final start = source.indexOf(startNeedle);
  expect(start, isNonNegative, reason: startNeedle);
  final end = source.indexOf(endNeedle, start + startNeedle.length);
  expect(end, isNonNegative, reason: endNeedle);
  return source.substring(start, end);
}
