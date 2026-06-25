import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/navigation_persistence_policy.dart';
import 'package:mobile/core/route_location_sanitizer.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> _ensureSupabaseInitialized() async {
  try {
    Supabase.instance.client;
    return;
  } catch (_) {}

  await Supabase.initialize(
    url: 'https://example.supabase.co',
    anonKey: 'anon-key-0123456789012345678901234567890123456789',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await _ensureSupabaseInitialized();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('edit flow route is web-safe durable detail state', () {
    const route = '/flows/42/edit?calendarId=shared-1&fallback=%2F';

    expect(stableRouteLocationForContinuity(route), '/flows/42/edit');
    expect(routeLocationContainsOneShotIntent(route), isTrue);
    expect(
      stableRouteLocationForContinuity(
        '/flows/42/edit?calendarId=shared-1&fallback=%2Fshared-flow%2Fby-flow%2F42',
      ),
      '/flows/42/edit',
    );
  });

  test('Flow Studio submode routes are durable and constrained', () {
    expect(
      stableRouteLocationForContinuity('/flows?mode=myFlows'),
      '/flows?mode=myFlows',
    );
    expect(
      stableRouteLocationForContinuity('/flows?mode=maatFlows'),
      '/flows?mode=maatFlows',
    );
    expect(
      stableRouteLocationForContinuity(
        '/flows?mode=maatTemplate&templateKey=the-weighing',
      ),
      '/flows?mode=maatTemplate&templateKey=the-weighing',
    );
    expect(stableRouteLocationForContinuity('/flows?mode=unknown'), '/flows');
    expect(
      stableRouteLocationForContinuity('/flows?mode=maatFlows&_launch=1'),
      '/flows?mode=maatFlows',
    );

    const policy = NavigationPersistencePolicy();
    for (final route in const <String>[
      '/flows?mode=myFlows',
      '/flows?mode=maatFlows',
    ]) {
      final classification = policy.classifyRoute(
        route,
        NavigationSource.programmatic,
      );
      expect(classification.accepted, isTrue, reason: route);
      expect(classification.canRestoreAsSurface, isTrue, reason: route);
      expect(classification.canonicalRoute, route, reason: route);
      expect(classification.routeClass, NavigationRouteClass.utility);
    }
  });

  test('router exposes a flow edit route backed by Flow Studio', () {
    final main = File('lib/main.dart').readAsStringSync();
    final route = _sourceBetween(
      main,
      "path: '/flows/:flowId/edit'",
      "path: '/profile/:userId/followers'",
    );
    const policy = NavigationPersistencePolicy();
    final editClassification = policy.classifyRoute(
      '/flows/42/edit?calendarId=shared-1&fallback=%2F',
      NavigationSource.programmatic,
    );

    expect(route, contains('CalendarPage.buildFlowEditorRoutePage'));
    expect(route, contains("state.uri.queryParameters['calendarId']"));
    expect(route, contains("state.uri.queryParameters['fallback']"));
    expect(editClassification.accepted, isTrue);
    expect(editClassification.canRestoreAsSurface, isTrue);
    expect(editClassification.canRecordPrimarySelection, isFalse);
    expect(editClassification.canonicalRoute, '/flows/42/edit');
    expect(editClassification.routeClass, NavigationRouteClass.transient);
  });

  test('Flow Studio route page is initialized from route submode URI', () {
    final main = File('lib/main.dart').readAsStringSync();
    final calendar = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final flowsRoute = _sourceBetween(
      main,
      "path: '/flows'",
      "path: '/calendars'",
    );
    final routePage = _sourceBetween(
      calendar,
      'class _FlowStudioRoutePage extends StatefulWidget',
      'class _SharedCalendarsRoutePage extends StatelessWidget',
    );

    expect(flowsRoute, contains('location: state.uri.toString()'));
    expect(
      flowsRoute,
      contains('CalendarPage.buildFlowStudioRoutePage(routeUri: state.uri)'),
    );
    expect(routePage, contains('final Uri? routeUri'));
    expect(routePage, contains('CalendarPage._flowStudioRouteStateFromUri'));
    expect(routePage, contains("parentRoute: '/flows'"));
    expect(routePage, contains('UtilitySheetRouteScaffold'));
    expect(routePage, contains('Navigator('));
    expect(routePage, contains('_flowStudioNavigatorKey'));
    expect(routePage, contains('_detachedFlowStudioInitialRoutes'));
    expect(routePage, contains('onReturnToHub: _returnToFlowStudioHubRoute'));
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
    expect(opener, contains('openDetailRoute<void>(context, route)'));
    expect(opener, contains('kIsWeb'));
    expect(opener, contains('await _clearFlowStudioTransientState();'));
    expect(
      opener,
      contains(
        'await _removeCalendarOverlayKinds({_kCalendarOverlayKindEventDetail});',
      ),
    );
    expect(opener, contains('_openFlowEditorDirectly(flowId)'));
    expect(opener, contains('_openDetachedFlowStudioSheet'));

    final callback = _sourceBetween(
      calendar,
      'void Function(int? flowId) _getMyFlowsCallback()',
      '// Flow Studio callback that opens the Flow Hub',
    );
    expect(callback, contains('CalendarPage.openFlowEditorFromAnyContext'));
    expect(callback, contains("source: 'calendar_detail'"));

    final studioCallback = _sourceBetween(
      calendar,
      'void Function(int? flowId) _getFlowStudioCallback()',
      'void _openFlowEditorDirectly(int flowId)',
    );
    expect(
      studioCallback,
      contains('CalendarPage.openFlowEditorFromAnyContext'),
    );
    expect(studioCallback, contains("source: 'flow_studio_callback'"));

    final dayView = File(
      'lib/features/calendar/day_view.dart',
    ).readAsStringSync();
    final landscape = File(
      'lib/features/calendar/landscape_month_view.dart',
    ).readAsStringSync();
    final grid = File(
      'lib/features/calendar/calendar_grid_widgets.dart',
    ).readAsStringSync();
    final sharedDetailManageFlow = _sourceBetween(
      dayView,
      "value == 'edit' && flow != null && actionableFlow",
      "value == 'save' && flow != null && actionableFlow",
    );
    final landscapeDetailCaller = _sourceBetween(
      landscape,
      'builder: (sheetContext) => CalendarEventDetailSheet(',
      'onEditNote: widget.onEditNote,',
    );
    final gridDetailCaller = _sourceBetween(
      grid,
      'builder: (_) => CalendarEventDetailSheet(',
      'onEditNote: onEditNote,',
    );
    expect(
      sharedDetailManageFlow,
      contains('await Navigator.of(sheetContext).maybePop();'),
    );
    expect(
      sharedDetailManageFlow,
      contains('widget.onManageFlows?.call(flow.id)'),
    );
    expect(
      landscapeDetailCaller,
      contains('onManageFlows: widget.onManageFlows'),
    );
    expect(gridDetailCaller, contains('onManageFlows: onManageFlows'));

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
    expect(calendar, contains('Navigator.of(context, rootNavigator: true)'));
    expect(calendar, contains('rootNavigator.canPop()'));
    expect(calendar, contains('popOrGo(context, _fallbackLocation'));
    expect(calendar, contains('_clearFlowStudioTransientState'));
  });

  testWidgets('edit flow route close navigates to fallback route', (
    tester,
  ) async {
    await AppRestorationService.instance.saveOverlayStack([
      <String, dynamic>{'kind': 'calendar.flowStudio', 'mode': 'myFlows'},
    ]);
    await AppRestorationService.instance.saveEditorState(
      'calendar.flowStudio.draft',
      <String, dynamic>{'name': 'stale draft'},
    );

    final router = GoRouter(
      initialLocation: '/flows/42/edit?fallback=%2Ffallback',
      routes: [
        GoRoute(
          path: '/flows/:flowId/edit',
          builder: (context, state) {
            final flowId = int.parse(state.pathParameters['flowId']!);
            return CalendarPage.buildFlowEditorRoutePage(
              flowId: flowId,
              fallbackLocation: state.uri.queryParameters['fallback'],
            );
          },
        ),
        GoRoute(
          path: '/fallback',
          builder: (context, state) =>
              const Scaffold(body: Text('Fallback route')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    expect(find.text('Flow Studio'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pump();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/fallback',
    );
    await tester.pump();

    expect(find.text('Fallback route'), findsOneWidget);
    expect(await AppRestorationService.instance.readOverlayStack(), isEmpty);
    expect(
      await AppRestorationService.instance.readEditorState(
        'calendar.flowStudio.draft',
      ),
      isNull,
    );
  });
}

String _sourceBetween(String source, String startNeedle, String endNeedle) {
  final start = source.indexOf(startNeedle);
  expect(start, isNonNegative, reason: 'Missing start marker: $startNeedle');
  final end = source.indexOf(endNeedle, start + startNeedle.length);
  expect(end, isNonNegative, reason: 'Missing end marker: $endNeedle');
  return source.substring(start, end);
}
