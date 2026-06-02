import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/route_location_sanitizer.dart';

void main() {
  test('edit flow route is web-safe and preserves stable query state', () {
    const route = '/flows/42/edit?calendarId=shared-1&fallback=%2F';

    expect(stableRouteLocationForContinuity(route), route);
    expect(routeLocationContainsOneShotIntent(route), isFalse);
  });

  test('router exposes a flow edit route backed by Flow Studio', () {
    final main = File('lib/main.dart').readAsStringSync();
    final route = _sourceBetween(
      main,
      "path: '/flows/:flowId/edit'",
      "path: '/profile/:userId/followers'",
    );
    final continuity = _sourceBetween(
      main,
      'bool _isContinuityRouteLocation(String location)',
      'Map<String, dynamic>? _pushIntentDataFromQuery',
    );

    expect(route, contains('CalendarPage.buildFlowEditorRoutePage'));
    expect(route, contains("state.uri.queryParameters['calendarId']"));
    expect(route, contains("state.uri.queryParameters['fallback']"));
    expect(continuity, contains("path.startsWith('/flows/')"));
  });

  test('Edit Flow actions use edit-by-id route on web', () {
    final calendar = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final sharedFlowDetails = File(
      'lib/features/inbox/shared_flow_details_page.dart',
    ).readAsStringSync();
    final studio = File(
      'lib/features/calendar/calendar_flow_studio_page.dart',
    ).readAsStringSync();

    final opener = _sourceBetween(
      calendar,
      'static Future<void> openFlowEditorFromAnyContext',
      'static Widget buildFlowEditorRoutePage',
    );
    expect(opener, contains('context.go(route);'));
    expect(opener, contains('kIsWeb'));
    expect(opener, contains('_openFlowEditorDirectly(flowId)'));
    expect(opener, contains('_openDetachedFlowStudioSheet'));

    final callback = _sourceBetween(
      calendar,
      'void Function(int? flowId) _getMyFlowsCallback()',
      '// Flow Studio callback that opens the Flow Hub',
    );
    expect(callback, contains('CalendarPage.openFlowEditorFromAnyContext'));
    expect(callback, contains("source: 'calendar_detail'"));

    expect(
      sharedFlowDetails,
      contains('CalendarPage.openFlowEditorFromAnyContext'),
    );
    expect(sharedFlowDetails, contains("source: 'shared_flow_details'"));
    expect(sharedFlowDetails, isNot(contains('openMyFlowsFromAnyContext')));

    expect(studio, contains('this.onRouteResult'));
    expect(studio, contains('this.initialCalendarId'));
    expect(studio, contains('String? _routeInitialCalendarId()'));
    expect(studio, contains('Future<void> _finishWithResult'));
    expect(studio, contains('await routeResultHandler(result);'));
    expect(calendar, contains('initialCalendarId: widget.calendarId'));
  });
}

String _sourceBetween(String source, String startNeedle, String endNeedle) {
  final start = source.indexOf(startNeedle);
  expect(start, isNonNegative, reason: 'Missing start marker: $startNeedle');
  final end = source.indexOf(endNeedle, start + startNeedle.length);
  expect(end, isNonNegative, reason: 'Missing end marker: $endNeedle');
  return source.substring(start, end);
}
