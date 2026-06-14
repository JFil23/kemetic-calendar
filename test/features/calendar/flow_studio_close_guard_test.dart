import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flow Studio close handler cannot delete persisted AI flows', () {
    final source = File(
      'lib/features/calendar/calendar_flow_studio_page.dart',
    ).readAsStringSync();
    final closeStart = source.indexOf('Future<void> _handleClose() async');
    final closeEnd = source.indexOf('// ---------- build ----------');

    expect(closeStart, isNonNegative);
    expect(closeEnd, greaterThan(closeStart));

    final closeHandler = source.substring(closeStart, closeEnd);
    expect(closeHandler, isNot(contains('deleteByFlowId')));
    expect(closeHandler, isNot(contains('FlowsRepo')));
    expect(closeHandler, isNot(contains('Delete AI Flow?')));
  });

  test(
    'Flow Studio route close delegates Ma at list back and editor close',
    () {
      final source = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();

      final routeStart = source.indexOf('class _FlowStudioRoutePageState');
      final routeEnd = source.indexOf('class _SharedCalendarsRoutePage');
      expect(routeStart, isNonNegative);
      expect(routeEnd, greaterThan(routeStart));
      final routeSection = source.substring(routeStart, routeEnd);
      expect(routeSection, contains('_flowStudioNavigatorKey'));
      expect(routeSection, contains('_routeCloseRequested'));
      expect(routeSection, contains("closeOrReturn(context, '/')"));
      expect(routeSection, isNot(contains("context.go('/');")));
      expect(routeSection, contains('bool _handleSystemBack()'));
      expect(routeSection, contains('nestedNavigator.pop();'));
      expect(routeSection, contains('onBackPressed: _handleSystemBack'));
      expect(routeSection, contains('key: _flowStudioNavigatorKey'));
      expect(routeSection, contains('onClose: _closeRoute'));
      expect(routeSection, contains('_returnToFlowStudioHubRoute'));
      expect(routeSection, contains("context.go('/flows')"));
      expect(
        routeSection,
        contains('onReturnToHub: _returnToFlowStudioHubRoute'),
      );

      final rootStart = source.indexOf(
        'static Widget _buildDetachedFlowStudioRoot',
      );
      final rootEnd = source.indexOf(
        'static List<Route<dynamic>> _detachedFlowStudioInitialRoutes',
      );
      expect(rootStart, isNonNegative);
      expect(rootEnd, greaterThan(rootStart));
      final rootSection = source.substring(rootStart, rootEnd);
      expect(rootSection, contains('VoidCallback? onClose'));
      expect(rootSection, contains('onRouteClose: onClose'));
      expect(rootSection, contains('onClose: onClose'));

      final listStart = source.indexOf(
        'static Widget _buildDetachedMaatFlowsListPage',
      );
      final listEnd = source.indexOf(
        'static Widget _buildDetachedFlowStudioRoot',
      );
      expect(listStart, isNonNegative);
      expect(listEnd, greaterThan(listStart));
      final listSection = source.substring(listStart, listEnd);
      expect(listSection, contains('VoidCallback? onClose'));
      expect(listSection, contains('if (navigator.canPop())'));
      expect(listSection, contains('navigator.pop();'));
      expect(listSection, contains('onClose();'));

      final initialRoutesSection = source.substring(rootEnd, routeStart);
      expect(initialRoutesSection, contains('VoidCallback? onReturnToHub'));
      expect(initialRoutesSection, contains('hubRoute(), listRoute'));
      expect(
        initialRoutesSection,
        contains('hubRoute(), listRoute, detailRoute'),
      );
    },
  );

  test('Android app opts in to OnBackInvokedCallback', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:enableOnBackInvokedCallback="true"'));
  });

  test('replacement deletes do not create client-suppressing tombstones', () {
    final calendarSource = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final inboxSource = File(
      'lib/repositories/inbox_repo.dart',
    ).readAsStringSync();
    final shareSource = File('lib/data/share_repo.dart').readAsStringSync();

    expect(
      _deleteCallFor(
        calendarSource,
        "sourceFeature: 'CalendarPage._persistFlowStudioResult'",
      ),
      contains('suppressesClient: false'),
    );
    expect(
      _deleteCallFor(
        calendarSource,
        "sourceFeature: 'CalendarPage.scheduleFlowNotes'",
      ),
      contains('suppressesClient: false'),
    );
    expect(
      _deleteCallFor(
        inboxSource,
        "sourceFeature: 'InboxRepo._scheduleImportedFlow'",
      ),
      contains('suppressesClient: false'),
    );
    expect(
      _deleteCallFor(
        shareSource,
        "sourceFeature: 'ShareRepo._importSharedFlow'",
      ),
      contains('suppressesClient: false'),
    );
  });

  test('itinerary import helper copy stays out of saved overview content', () {
    final parserSource = File(
      'lib/features/ai_generation/itinerary_prompt_parser.dart',
    ).readAsStringSync();
    final studioSource = File(
      'lib/features/calendar/calendar_flow_studio_page.dart',
    ).readAsStringSync();

    final overviewStart = parserSource.indexOf(
      'String _buildOverviewSummary()',
    );
    final overviewEnd = parserSource.indexOf(
      'ItineraryParseResult? parseItineraryPrompt',
    );
    expect(overviewStart, isNonNegative);
    expect(overviewEnd, greaterThan(overviewStart));
    final overviewBuilder = parserSource.substring(overviewStart, overviewEnd);

    expect(overviewBuilder, isNot(contains('Detected: Itinerary / Schedule')));
    expect(overviewBuilder, isNot(contains('Review the extracted schedule')));
    expect(overviewBuilder, contains('Hotel:'));
    expect(overviewBuilder, contains('Setup:'));
    expect(studioSource, contains('Widget _itineraryImportBadge()'));
    expect(studioSource, contains('Detected: Itinerary / Schedule'));
  });

  test(
    'Flow Studio import calendar selection remains editable and persists',
    () {
      final source = File(
        'lib/features/calendar/calendar_flow_studio_page.dart',
      ).readAsStringSync();

      final importStart = source.indexOf(
        'Future<void> _initializeFromImport(ImportFlowData data) async',
      );
      final importEnd = source.indexOf('/// Helper to load a flow from DB');
      expect(importStart, isNonNegative);
      expect(importEnd, greaterThan(importStart));
      final importInit = source.substring(importStart, importEnd);
      expect(importInit, contains('await _ensureCalendarChoicesLoaded();'));
      expect(
        importInit,
        contains(
          '_selectedCalendarId = data.calendarId ?? _defaultCalendarId();',
        ),
      );

      final buildStart = source.indexOf('Widget build(BuildContext context)');
      final buildEnd = source.length;
      expect(buildStart, isNonNegative);
      expect(buildEnd, greaterThan(buildStart));
      final buildSection = source.substring(buildStart, buildEnd);
      expect(
        buildSection,
        isNot(contains('onTap: _editableCalendars.isEmpty')),
      );
      expect(buildSection, contains('await _ensureCalendarChoicesLoaded();'));
      expect(buildSection, contains('final calendars = _editableCalendars;'));
      expect(buildSection, contains('_selectedCalendarId = chosenId;'));

      final saveStart = source.indexOf('Future<void> _save() async');
      final saveEnd = source.indexOf('void _delete()');
      expect(saveStart, isNonNegative);
      expect(saveEnd, greaterThan(saveStart));
      final saveSection = source.substring(saveStart, saveEnd);
      expect(saveSection, contains('calendarId: selectedCalendarId,'));

      final calendarPageSource = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final persistStart = calendarPageSource.indexOf(
        'Future<int?> _persistFlowStudioResult(_FlowStudioResult r) async',
      );
      final persistEnd = calendarPageSource.indexOf(
        'Future<({String clientEventId, String eventId})> _saveSingleNoteOnly',
      );
      expect(persistStart, isNonNegative);
      expect(persistEnd, greaterThan(persistStart));
      final persistSection = calendarPageSource.substring(
        persistStart,
        persistEnd,
      );
      expect(
        persistSection,
        contains(
          'final flowCalendarId = saved?.calendarId ?? r.savedFlow?.calendarId;',
        ),
      );
      expect(persistSection, contains('calendarId: flowCalendarId,'));
    },
  );
}

String _deleteCallFor(String source, String sourceFeatureNeedle) {
  final featureIndex = source.indexOf(sourceFeatureNeedle);
  expect(featureIndex, isNonNegative);

  final callStart = source.lastIndexOf('deleteByFlowId(', featureIndex);
  expect(callStart, isNonNegative);

  final callEnd = source.indexOf(');', featureIndex);
  expect(callEnd, isNonNegative);

  return source.substring(callStart, callEnd);
}
