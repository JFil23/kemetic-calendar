import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/snapshot/calendar_snapshot_runtime.dart';
import 'package:mobile/features/onboarding/guided_onboarding_overlay.dart';
import 'package:mobile/features/onboarding/onboarding_progress.dart';
import 'package:mobile/features/pages/pages_page.dart';
import 'package:mobile/main.dart' show routeObserver;
import 'package:mobile/services/restoration_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/maat_flow_visual_test_fonts.dart';

const _owner = 'bd3f58ef-efdf-4990-b9a6-42ebf82aa8c8';
const _other = '27d63169-a28a-4550-a0a0-8fee0e8e7b95';

enum _Entry { portrait, landscape, pages }

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory storage;
  final server = _Server();
  final scenarios =
      <({String name, Future<void> Function(WidgetTester) run})>[];
  void routeScenario(String name, Future<void> Function(WidgetTester) run) =>
      scenarios.add((name: name, run: run));

  setUpAll(() async {
    storage = await Directory.systemTemp.createTemp('quick_add_navigation.');
    Hive.init(storage.path);
    await calendarSnapshotStore.initialize();
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'com.llfbandit.app_links/messages',
      'com.llfbandit.app_links/events',
      'receive_sharing_intent/messages',
      'receive_sharing_intent/events-media',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), (call) async {
        if (channel.contains('/events') && call.method == 'listen') {
          scheduleMicrotask(
            () => messenger.handlePlatformMessage(channel, null, (_) {}),
          );
        }
        return null;
      });
    }
    await Supabase.initialize(
      url: 'https://example.supabase.test',
      anonKey: 'fixture',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(server.respond),
    );
    await loadMaatFlowVisualTestFonts();
  });

  Future<void> resetFixture() async {
    server.reset();
    SharedPreferences.setMockInitialValues({
      'onboarding_v1_completed:$_owner': true,
      'onboarding_v1_completed:$_other': true,
    });
    await Supabase.instance.client.auth.recoverSession(_session(_owner));
    debugPrint('[quick-add fixture] recovered account; saving progress');
    OnboardingHelperCompletionService.resetForTesting(remoteStore: _Helpers());
    await OnboardingProgressStorage().saveRequired(
      _owner,
      const OnboardingProgress().copyWith(
        completedOnboarding: true,
        currentStep: TrueOnboardingStep.complete,
        seenHelpers: OnboardingHelperIds.normalizeCompletedHelperKeys(
          OnboardingHelperIds.all,
        ),
      ),
    );
    GuidedOnboardingController.instance.clear();
    GuidedOnboardingController.instance.setExternalOverlaySuppressed(false);
    CalendarEventDetailSheetCoordinator.debugResetForTests();
    CalendarPage.debugCalendarTodayForTesting = DateTime.now();
    debugPrint('[quick-add fixture] ready');
  }

  tearDown(() {
    CalendarPage.debugCalendarTodayForTesting = null;
    GuidedOnboardingController.instance.clear();
    CalendarEventDetailSheetCoordinator.debugResetForTests();
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
    // As in guest_first_account_onboarding_test, these process-owned stores
    // remain alive until this isolated Flutter worker exits. Closing Hive while
    // disposal writes are draining races the actual Calendar storage owner.
  });

  for (final scenario in [
    (_Entry.portrait, false),
    (_Entry.landscape, true),
    (_Entry.pages, false),
    (_Entry.pages, true),
  ]) {
    routeScenario(
      '${scenario.$1.name} ${scenario.$2 ? 'all-day' : 'timed'} add opens its exact future event after ACK',
      (tester) async {
        final host = await _host(tester, scenario.$1);
        final gate = Completer<void>();
        server.writeHold = gate;
        final allDay = scenario.$2;
        await _submit(
          tester,
          scenario.$1,
          allDay
              ? 'Road trip on March 15'
              : 'meet James on March 15 at 10pm in Beverly Hills',
        );
        await _until(
          tester,
          () => server.upserts.isNotEmpty,
          'event upsert reached transport',
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          _quickAdd(),
          findsNothing,
          reason: 'Retain optimistic editor dismissal.',
        );
        expect(
          find.byType(DayViewPage),
          findsNothing,
          reason: 'A held write is not a successful add.',
        );
        final payload = server.upserts.single;
        final expectedDay = _march15();
        final start = DateTime.parse(payload['starts_at'] as String).toLocal();
        expect(DateUtils.dateOnly(start), expectedDay);
        expect(start.hour, allDay ? 9 : 22);
        expect(payload['all_day'], allDay);
        if (!allDay) expect(payload['location'], 'Beverly Hills');
        gate.complete();
        await _until(
          tester,
          () => find.byType(CalendarEventDetailSheet).evaluate().isNotEmpty,
          'canonical Day View restored the acknowledged event',
        );
        expect(host.router.state.uri.path, '/');
        expect(find.byType(DayViewPage, skipOffstage: false), findsOneWidget);
        final saved = server.rows.single;
        final event = tester
            .widget<CalendarEventDetailSheet>(
              find.byType(CalendarEventDetailSheet),
            )
            .initialTarget;
        final date = KemeticMath.fromGregorian(expectedDay);
        expect(
          (event.ky, event.km, event.kd),
          (date.kYear, date.kMonth, date.kDay),
        );
        expect(event.event.clientEventId, saved['client_event_id']);
        expect(
          event.event.clientEventId,
          isNot(payload['client_event_id']),
          reason: 'Navigation must use the acknowledged CID, not predict it.',
        );
        expect(event.event.title, allDay ? 'Road trip' : 'meet James');
        expect(event.event.allDay, allDay);
        expect(event.event.startMin, allDay ? 9 * 60 : 22 * 60);
        if (!allDay) expect(event.event.location, 'Beverly Hills');
        await host.close(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }

  routeScenario(
    'adding from existing Day View reuses that owner and changes its focused day',
    (tester) async {
      final host = await _host(tester, _Entry.portrait);
      await _submit(tester, _Entry.portrait, 'First activity today at 9am');
      await _until(
        tester,
        () => find.byType(CalendarEventDetailSheet).evaluate().isNotEmpty,
        'first event is visible in Day View',
      );
      final dayState = tester.state(find.byType(DayViewPage));
      Navigator.of(tester.element(find.byType(CalendarEventDetailSheet))).pop();
      await tester.pump(const Duration(milliseconds: 400));
      await _submit(
        tester,
        _Entry.portrait,
        'Second activity on March 15 at 2pm',
      );
      await _until(tester, () {
        final details = find.byType(CalendarEventDetailSheet).evaluate();
        return details.isNotEmpty &&
            (details.single.widget as CalendarEventDetailSheet)
                    .initialTarget
                    .event
                    .title ==
                'Second activity';
      }, 'existing Day View follows its exact event request');
      expect(find.byType(DayViewPage, skipOffstage: false), findsOneWidget);
      expect(tester.state(find.byType(DayViewPage)), same(dayState));
      final target = tester
          .widget<CalendarEventDetailSheet>(
            find.byType(CalendarEventDetailSheet),
          )
          .initialTarget;
      final day = KemeticMath.fromGregorian(_march15());
      expect(
        (target.ky, target.km, target.kd),
        (day.kYear, day.kMonth, day.kDay),
      );
      expect(target.event.clientEventId, server.rows.last['client_event_id']);
      await host.close(tester);
      expect(tester.takeException(), isNull);
    },
  );

  for (final entry in [_Entry.portrait, _Entry.pages]) {
    routeScenario(
      '${entry.name} write failure keeps the current route and never opens Day View',
      (tester) async {
        final host = await _host(tester, entry);
        server.failWrite = true;
        await _submit(tester, entry, 'Failed activity on March 15 at 2pm');
        await _until(
          tester,
          () =>
              find.textContaining('Failed to save note:').evaluate().isNotEmpty,
          'failed persistence is reported',
        );
        expect(server.rows, isEmpty);
        expect(find.byType(DayViewPage, skipOffstage: false), findsNothing);
        expect(
          host.router.state.uri.path,
          entry == _Entry.pages ? '/pages' : '/',
        );
        await host.close(tester);
        expect(tester.takeException(), isNull);
      },
    );

    routeScenario(
      '${entry.name} A to B to A after event ACK cannot navigate from the disposed editor',
      (tester) async {
        final host = await _host(tester, entry);
        final analytics = Completer<void>();
        server.analyticsHold = analytics;
        await _submit(
          tester,
          entry,
          'Account-bound activity on March 15 at 2pm',
        );
        await _until(
          tester,
          () => server.analyticsStarted,
          'event ACK has completed and its existing completion work is held',
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          server.rows,
          hasLength(1),
          reason: 'Exercise the navigation fence after repository ACK.',
        );
        expect(_quickAdd(), findsNothing);
        expect(find.byType(DayViewPage), findsNothing);
        await Supabase.instance.client.auth.recoverSession(_session(_other));
        await tester.pump();
        await Supabase.instance.client.auth.recoverSession(_session(_owner));
        await tester.pump();
        analytics.complete();
        for (var frame = 0; frame < 15; frame++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byType(DayViewPage, skipOffstage: false), findsNothing);
        expect(find.byType(CalendarEventDetailSheet), findsNothing);
        expect(
          host.router.state.uri.path,
          entry == _Entry.pages ? '/pages' : '/',
        );
        await host.close(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }

  routeScenario(
    'departing at the actual Day View route push prevents its first event build',
    (tester) async {
      final transition = Completer<void>();
      var pushes = 0;
      final observer = _DrillPushObserver(() {
        pushes++;
        if (pushes != 1) return;
        unawaited(
          () async {
            await Supabase.instance.client.auth.recoverSession(
              _session(_other),
            );
            await Supabase.instance.client.auth.recoverSession(
              _session(_owner),
            );
          }().then<void>(
            (_) => transition.complete(),
            onError: (Object error, StackTrace stack) =>
                transition.completeError(error, stack),
          ),
        );
      });
      final host = await _host(tester, _Entry.portrait, observer: observer);
      await _submit(
        tester,
        _Entry.portrait,
        'Route-bound activity on March 15 at 2pm',
      );
      await _until(
        tester,
        () => transition.isCompleted,
        'account departs during the canonical drill-in route push',
      );
      await transition.future;
      for (var frame = 0; frame < 15; frame++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(pushes, 1);
      expect(server.rows, hasLength(1));
      // didPush ran synchronously before the account departure. The already
      // pushed canonical route stays; its original account fence must reject
      // the requested event when the route first builds and data arrives.
      expect(find.byType(DayViewPage, skipOffstage: false), findsOneWidget);
      final dayView = tester.widget<DayViewPage>(find.byType(DayViewPage));
      expect(dayView.eventDetailAccountIsCurrent, isNotNull);
      expect(dayView.eventDetailAccountIsCurrent!(), isFalse);
      expect(
        dayView.initialEventDetailRestorationState?.identityType,
        'clientEventId',
      );
      expect(
        dayView.initialEventDetailRestorationState?.identityValue,
        server.rows.single['client_event_id'],
      );
      expect(find.byType(CalendarEventDetailSheet), findsNothing);
      await host.close(tester);
      expect(tester.takeException(), isNull);
    },
  );

  routeScenario(
    'Pages queued saved-event handoff is fenced during cold home hydration',
    (tester) async {
      final host = await _host(tester, _Entry.pages);
      final coldHome = Completer<void>();
      server.coldHomeHold = coldHome;
      await _submit(
        tester,
        _Entry.pages,
        'Cold handoff activity on March 15 at 2pm',
      );
      await _until(
        tester,
        () => host.router.state.uri.path == '/' && server.coldHomeStarted,
        'the acknowledged event is queued on a cold Calendar awaiting hydration',
      );
      expect(server.rows, hasLength(1));
      expect(find.byType(CalendarPage), findsOneWidget);
      expect(find.byType(DayViewPage, skipOffstage: false), findsNothing);
      await Supabase.instance.client.auth.recoverSession(_session(_other));
      await tester.pump();
      await Supabase.instance.client.auth.recoverSession(_session(_owner));
      await tester.pump();
      coldHome.complete();
      for (var frame = 0; frame < 30; frame++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        find.byType(DayViewPage, skipOffstage: false),
        findsNothing,
        reason:
            'The departed account cannot resume an old queued event, including A to B to A.',
      );
      expect(find.byType(CalendarEventDetailSheet), findsNothing);
      await host.close(tester);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Quick Add real routes retain all eleven acknowledgement and account boundaries',
    (tester) async {
      expect(scenarios, hasLength(11));
      for (final scenario in scenarios) {
        await resetFixture();
        debugPrint('[quick-add scenario START] ${scenario.name}');
        await scenario.run(tester);
        debugPrint('[quick-add scenario PASS] ${scenario.name}');
      }
    },
  );
}

Future<_Host> _host(
  WidgetTester tester,
  _Entry entry, {
  NavigatorObserver? observer,
}) async {
  var scopeCleared = false;
  Object? scopeError;
  StackTrace? scopeStack;
  unawaited(
    calendarSnapshotStore
        .deleteUserScope(_owner)
        .then<void>(
          (_) => scopeCleared = true,
          onError: (Object error, StackTrace stack) {
            scopeError = error;
            scopeStack = stack;
            scopeCleared = true;
          },
        ),
  );
  await _until(
    tester,
    () => scopeCleared,
    'clear test snapshot with real I/O and active fake clock',
  );
  if (scopeError != null) Error.throwWithStackTrace(scopeError!, scopeStack!);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = entry == _Entry.landscape
      ? const Size(844, 390)
      : const Size(390, 844);
  addTearDown(tester.view.reset);
  final harness = entry == _Entry.pages
      ? null
      : CalendarBoundaryHarnessController(
          expansionLevel: MonthExpansionLevel.compact,
          content: CalendarBoundaryHarnessContent.empty,
          instrumentation: CalendarBoundaryInstrumentation.timingOnly,
        );
  final router = GoRouter(
    initialLocation: entry == _Entry.pages ? '/pages' : '/',
    observers: [routeObserver, if (observer != null) observer],
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            CalendarPage(calendarBoundaryHarnessController: harness),
      ),
      GoRoute(path: '/pages', builder: (_, _) => const PagesPage()),
    ],
  );
  final host = _Host(router, harness);
  addTearDown(() => host.close(tester));
  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
  );
  await _until(
    tester,
    () => find
        .byTooltip(
          entry == _Entry.landscape
              ? 'Add note, reminder, or flow'
              : 'New note',
        )
        .evaluate()
        .isNotEmpty,
    'canonical entry + is visible',
  );
  if (entry == _Entry.pages) {
    expect(find.byType(CalendarPage, skipOffstage: false), findsNothing);
  }
  return host;
}

Future<void> _submit(WidgetTester tester, _Entry entry, String input) async {
  await tester.tap(
    find.byTooltip(
      entry == _Entry.landscape ? 'Add note, reminder, or flow' : 'New note',
    ),
  );
  await _until(
    tester,
    () => find.byKey(const ValueKey('quick-add-input')).evaluate().isNotEmpty,
    'shared Quick Add is open',
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.enterText(find.byKey(const ValueKey('quick-add-input')), input);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.ensureVisible(
    find.byKey(const ValueKey('quick-add-submit-button')),
  );
  await tester.pump(const Duration(milliseconds: 100));
  expect(
    find.byKey(const ValueKey('quick-add-submit-button')).hitTestable(),
    findsOneWidget,
  );
  await tester.tap(find.byKey(const ValueKey('quick-add-submit-button')));
  await tester.pump();
}

Finder _quickAdd() => find.byWidgetPredicate(
  (widget) => widget.runtimeType.toString() == '_QuickAddSheet',
);

Future<void> _until(
  WidgetTester tester,
  bool Function() condition,
  String reason,
) async {
  for (var frame = 0; frame < 100 && !condition(); frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(condition(), isTrue, reason: reason);
}

DateTime _march15() {
  final now = DateTime.now();
  final date = DateTime(now.year, 3, 15);
  return date.isBefore(DateUtils.dateOnly(now))
      ? DateTime(now.year + 1, 3, 15)
      : date;
}

class _Host {
  _Host(this.router, this.harness);
  final GoRouter router;
  final CalendarBoundaryHarnessController? harness;
  bool _closed = false;
  Future<void> close(WidgetTester tester) async {
    if (_closed) return;
    // The exact detail can appear on the first animation frame. Let its route
    // and Hero flights finish before rotating or dismissing either route.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    tester.view.physicalSize = const Size(390, 844);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    final calendar = find.byType(CalendarPage, skipOffstage: false);
    if (calendar.evaluate().isNotEmpty) {
      Navigator.of(
        tester.element(calendar),
        rootNavigator: true,
      ).popUntil((route) => route.isFirst);
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    var drained = false;
    Object? drainError;
    StackTrace? drainStack;
    unawaited(
      RestorationCoordinator.instance
          .flush()
          .then((_) => calendarSnapshotStore.deleteUserScope(_owner))
          .then<void>(
            (_) => drained = true,
            onError: (Object error, StackTrace stack) {
              drainError = error;
              drainStack = stack;
              drained = true;
            },
          ),
    );
    for (var attempt = 0; attempt < 100 && !drained; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      drained,
      isTrue,
      reason:
          'Drain actual disposal I/O before leaving the test FakeAsync zone.',
    );
    if (drainError != null) Error.throwWithStackTrace(drainError!, drainStack!);
    for (var attempt = 0; attempt < 5; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(seconds: 1));
    }
    expect(harness?.isAttached ?? false, isFalse);
    harness?.dispose();
    router.dispose();
    _closed = true;
  }
}

class _DrillPushObserver extends NavigatorObserver {
  _DrillPushObserver(this.onPush);
  final VoidCallback onPush;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.runtimeType.toString().contains('CalendarDrillInRoute')) onPush();
  }
}

class _Server {
  final rows = <Map<String, dynamic>>[];
  final upserts = <Map<String, dynamic>>[];
  Completer<void>? writeHold, analyticsHold, coldHomeHold;
  bool failWrite = false, analyticsStarted = false, coldHomeStarted = false;
  void reset() {
    rows.clear();
    upserts.clear();
    writeHold = analyticsHold = coldHomeHold = null;
    failWrite = analyticsStarted = coldHomeStarted = false;
  }

  Future<http.Response> respond(http.Request request) async {
    final table = request.url.pathSegments.last;
    Object? data = [];
    var status = 200;
    if (table == 'profiles') {
      data = {
        'id': Supabase.instance.client.auth.currentUser?.id ?? _owner,
        'display_name': 'Calendar fixture',
        'onboarding_completed_at': '2026-10-01T00:00:00Z',
        'timezone': 'America/Los_Angeles',
        'telemetry_enabled': true,
      };
    }
    if (table == 'read_journal_state_v1') {
      data = {'revision': 0, 'row': null, 'recovery': []};
    }
    if (table == 'get_together_inbox' ||
        table == 'get_commons_together_home_cards') {
      data = {};
    }
    if (table == 'get_calendar_standalone_events_v2' &&
        request.method == 'POST') {
      // This is the deployed cold-home hydration owner, rather than the
      // direct user_events lookup used by an already mounted Calendar.
      final params = jsonDecode(request.body) as Map<String, dynamic>;
      final start = DateTime.parse(params['p_start_utc'] as String);
      final end = DateTime.parse(params['p_end_utc'] as String);
      final offset = params['p_page_offset'] as int;
      final limit = params['p_page_limit'] as int;
      final token = (request.headers['authorization'] ?? '').split(' ').last;
      final claims =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(token.split('.')[1])),
                ),
              )
              as Map<String, dynamic>;
      final requestOwner = claims['sub'];
      if (coldHomeHold != null && rows.isNotEmpty) {
        coldHomeStarted = true;
        await coldHomeHold!.future;
      }
      final readable =
          rows
              .where((row) {
                final eventStart = DateTime.parse(row['starts_at'] as String);
                return row['user_id'] == requestOwner &&
                    !eventStart.isBefore(start) &&
                    eventStart.isBefore(end);
              })
              .map(
                (row) => <String, dynamic>{
                  ...row,
                  'item_kind': 'note',
                  'filed_flow_id': null,
                  'calendar_is_personal': true,
                },
              )
              .toList()
            ..sort((a, b) {
              final byStart = (a['starts_at'] as String).compareTo(
                b['starts_at'] as String,
              );
              return byStart != 0
                  ? byStart
                  : (a['id'] as String).compareTo(b['id'] as String);
            });
      data = readable.skip(offset).take(limit).toList();
    }
    if (table == 'app_events' && request.method == 'POST') {
      final body = jsonDecode(request.body);
      final event = body is List
          ? (body.first as Map)['event']
          : (body as Map)['event'];
      if (event == 'note_created') {
        analyticsStarted = true;
        await analyticsHold?.future;
      }
    }
    if (table == 'user_events' && request.method == 'POST') {
      final payload = Map<String, dynamic>.from(
        jsonDecode(request.body) as Map,
      );
      upserts.add(payload);
      await writeHold?.future;
      if (failWrite) {
        status = 503;
        data = {'code': '503', 'message': 'Fixture write unavailable'};
      } else {
        final row = <String, dynamic>{
          ...payload,
          'id':
              '00000000-0000-4000-8000-${rows.length.toString().padLeft(12, '0')}',
          'client_event_id': 'ack:${payload['client_event_id']}',
          'user_id': _owner,
          'calendar_is_personal': true,
          'event_revision': 1,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };
        rows.add(row);
        data = row;
      }
    } else if (table == 'user_events' && request.method == 'GET') {
      if (coldHomeHold != null && rows.isNotEmpty) {
        coldHomeStarted = true;
        await coldHomeHold!.future;
      }
      var matches = rows.where((row) {
        for (final field in [
          'id',
          'client_event_id',
          'user_id',
          'flow_local_id',
        ]) {
          final filter = request.url.queryParameters[field];
          if (filter != null &&
              filter.startsWith('eq.') &&
              '${row[field]}' != filter.substring(3)) {
            return false;
          }
        }
        final start = DateTime.parse(row['starts_at'] as String);
        for (final filter
            in request.url.queryParametersAll['starts_at'] ?? <String>[]) {
          final dot = filter.indexOf('.');
          if (dot < 0) continue;
          final boundary = DateTime.tryParse(filter.substring(dot + 1));
          if (boundary == null) continue;
          if (filter.startsWith('gte.') && start.isBefore(boundary)) {
            return false;
          }
          if (filter.startsWith('lt.') && !start.isBefore(boundary)) {
            return false;
          }
          if (filter.startsWith('lte.') && start.isAfter(boundary)) {
            return false;
          }
        }
        return true;
      }).toList();
      final accept = request.headers['accept'] ?? '';
      data = accept.contains('pgrst.object') && matches.length == 1
          ? matches.single
          : matches;
    }
    return http.Response(
      jsonEncode(data),
      status,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}

class _Helpers implements OnboardingHelperCompletionRemoteStore {
  @override
  Future<Set<String>> loadCompletedHelperKeys(String userId) async =>
      OnboardingHelperIds.normalizeCompletedHelperKeys(OnboardingHelperIds.all);
  @override
  Future<void> markCompleted(
    String userId,
    Iterable<String> completionKeys,
  ) async {}
}

String _session(String owner) {
  final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return jsonEncode({
    'access_token':
        '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'sub': owner, 'exp': expiry})}.signature',
    'refresh_token': 'fixture',
    'token_type': 'bearer',
    'expires_at': expiry,
    'expires_in': 3600,
    'user': {
      'id': owner,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'fixture@example.test',
      'app_metadata': {},
      'user_metadata': {},
      'created_at': '2026-01-01T00:00:00Z',
    },
  });
}
