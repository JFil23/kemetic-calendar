import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/external_calendar_repository.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/calendar_invalidation.dart';
import 'package:mobile/features/calendar/snapshot/calendar_snapshot_runtime.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/pages_resource_test.dart' show session;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final externalReads = <Completer<void>>[];
  final day = DateTime(2026, 10, 9, 8);
  final outsideDay = DateTime(2026, 11, 15, 9);
  var externalReady = false;
  var failExternal = false;
  final selectedSources = {'fixture-source', 'retained-source'};
  var standaloneReads = 0;
  var catalogReads = 0;
  Completer<void>? heldCatalog;
  Completer<void>? heldCatalogStarted;
  var changedCatalog = false;
  final standaloneWindows = <(DateTime, DateTime)>[];

  bool includesDay(http.Request request, [DateTime? at]) {
    final params = jsonDecode(request.body) as Map;
    final start = DateTime.parse(
      (params['p_start_utc'] ?? params['p_from']) as String,
    );
    final end = DateTime.parse(
      (params['p_end_utc'] ?? params['p_until']) as String,
    );
    final instant = (at ?? day).toUtc();
    return !instant.isBefore(start) && instant.isBefore(end);
  }

  setUpAll(() async {
    await Hive.openBox<String>(
      'calendar_snapshot_store_v1',
      bytes: Uint8List(0),
    );
    await calendarSnapshotStore.initialize();
    SharedPreferences.setMockInitialValues({
      'app:has_seen_onboarding': true,
      'app:onboarding:completed': true,
    });
    AppRestorationService.debugUserIdResolver = () => null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'com.llfbandit.app_links/messages',
      'com.llfbandit.app_links/events',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'fixture-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        Object response = [];
        if (request.url.path.endsWith('/flows_with_calendars')) {
          catalogReads++;
          final wait = heldCatalog;
          if (wait != null) {
            heldCatalog = null;
            heldCatalogStarted!.complete();
            await wait.future;
          }
          if (changedCatalog) {
            response = [
              {
                'id': 427,
                'user_id': Supabase.instance.client.auth.currentUser!.id,
                'name': 'Changed catalog fixture',
                'color': 0x445566,
                'active': false,
                'is_saved': false,
                'rules': [],
              },
            ];
          }
        }
        if (request.url.path.endsWith('/get_calendar_standalone_events_v2')) {
          standaloneReads++;
          final window = jsonDecode(request.body) as Map;
          standaloneWindows.add((
            DateTime.parse(window['p_start_utc'] as String),
            DateTime.parse(window['p_end_utc'] as String),
          ));
          if (includesDay(request)) {
            response = [
              {
                'id': 'authored-event',
                'client_event_id': 'manual:existing',
                'item_kind': 'note',
                'title': 'Existing authored note',
                'all_day': false,
                'starts_at': day.toUtc().toIso8601String(),
                'ends_at': day
                    .add(const Duration(hours: 1))
                    .toUtc()
                    .toIso8601String(),
              },
            ];
          }
        }
        if (request.url.path.endsWith('/read_external_calendar_events_v1')) {
          if (!externalReady) {
            final pending = Completer<void>();
            externalReads.add(pending);
            await pending.future;
          }
          if (failExternal) {
            return http.Response(
              '{"message":"offline","code":"503"}',
              503,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }
          response = [
            for (final entry in [
              ('imported-event', day, 'fixture-source', 'Imported appointment'),
              (
                'outside-event',
                outsideDay,
                'fixture-source',
                'Imported appointment',
              ),
              (
                'retained-event',
                outsideDay,
                'retained-source',
                'Another selected calendar',
              ),
            ])
              if (selectedSources.contains(entry.$3) &&
                  includesDay(request, entry.$2))
                {
                  'id': entry.$1,
                  'client_event_id': 'external:fixture:${entry.$1}',
                  'source_id': entry.$3,
                  'title': entry.$4,
                  'detail':
                      'Reminder: bring insurance card\n\n'
                      'To see detailed information for automatically created events like this one, '
                      'use the official Google Calendar app. https://g.co/calendar\n\n'
                      'This event was created from an email you received in Gmail. '
                      'https://mail.google.com/mail?extsrc=cal&plid=example',
                  'all_day': false,
                  'starts_at': entry.$2.toUtc().toIso8601String(),
                  'ends_at': entry.$2
                      .add(const Duration(hours: 1))
                      .toUtc()
                      .toIso8601String(),
                  'calendar_name': 'Google fixture',
                },
          ];
        }
        return http.Response(
          jsonEncode(response),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await Supabase.instance.client.auth.recoverSession(session());
    setExternalCalendarRepositoryForTesting(
      Supabase.instance.client,
      ExternalCalendarRepository(Supabase.instance.client, lane: 'staging'),
    );
    CalendarPage.debugCalendarTodayForTesting = DateTime(2026, 10, 2);
  });

  tearDownAll(() async {
    CalendarPage.debugCalendarTodayForTesting = null;
    AppRestorationService.debugUserIdResolver = null;
    setExternalCalendarRepositoryForTesting(Supabase.instance.client, null);
    await Supabase.instance.dispose();
    await Hive.close();
  });

  Future<void> drain(WidgetTester tester, [int turns = 12]) async {
    for (var i = 0; i < turns; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets(
    'late external projection reaches the live calendar with unchanged flow catalog',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = CalendarPage.globalKey;
      await tester.pumpWidget(MaterialApp(home: CalendarPage(key: key)));
      await drain(tester, 40);
      final state = key.currentState!;
      final date = KemeticMath.fromGregorian(day);
      List<String> titles() => state
          .notesForDayForTesting(date.kYear, date.kMonth, date.kDay)
          .map((note) => note.title)
          .toList();
      expect(externalReads, isNotEmpty);
      expect(titles(), contains('Existing authored note'));
      expect(titles(), isNot(contains('Imported appointment')));
      unawaited(CalendarPage.openSearchFromAnyContext(state.context));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Imported appointment');
      await tester.pumpAndSettle();
      expect(find.text('No matches found'), findsOneWidget);
      final before = standaloneReads;
      final imported = CalendarInvalidationBus.instance.stream.first;
      externalReady = true;
      for (final read in externalReads) {
        read.complete();
      }
      await tester.runAsync(() => imported.timeout(const Duration(seconds: 2)));
      CalendarInvalidationBus.instance.publish(
        const CalendarInvalidated(
          reason: CalendarInvalidationReason.flowStudioPersisted,
        ),
      );
      await drain(tester, 35);
      expect(
        titles(),
        containsAll(['Existing authored note', 'Imported appointment']),
      );
      expect(
        titles().where((title) => title == 'Imported appointment'),
        hasLength(1),
      );
      final outsideDate = KemeticMath.fromGregorian(outsideDay);
      expect(
        state
            .notesForDayForTesting(
              outsideDate.kYear,
              outsideDate.kMonth,
              outsideDate.kDay,
            )
            .map((note) => note.clientEventId),
        contains('external:fixture:outside-event'),
        reason:
            'Late background range copies must reach off-screen months and search too',
      );
      expect(standaloneReads, greaterThan(before));
      expect(catalogReads, greaterThan(0));
      expect(
        find.text('Imported appointment'),
        findsWidgets,
        reason:
            'Open search must update when its live calendar projection changes',
      );
      expect(find.text('No matches found'), findsNothing);
      expect(find.textContaining('external_calendar'), findsNothing);
      expect(
        find.textContaining('official Google Calendar', findRichText: true),
        findsNothing,
      );
      await tester.enterText(
        find.byType(TextField),
        'official Google Calendar',
      );
      await tester.pumpAndSettle();
      expect(find.text('No matches found'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'insurance card');
      await tester.pumpAndSettle();
      expect(
        find.text('Imported appointment'),
        findsWidgets,
        reason:
            'Provider prose must not pass through authored metadata cleanup',
      );
      expect(find.text('No matches found'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Imported appointment');
      await tester.pumpAndSettle();

      final repository = externalCalendarRepository(Supabase.instance.client);
      failExternal = true;
      repository.projectionChanged();
      await drain(tester);
      expect(
        titles(),
        containsAll(['Existing authored note', 'Imported appointment']),
      );
      expect(
        find.text('No matches found'),
        findsNothing,
        reason: 'A failed passive read must retain confirmed imported copies',
      );

      failExternal = false;
      selectedSources.remove('fixture-source');
      repository.projectionChanged(
        removedSources: true,
        removedSourceIds: const ['fixture-source'],
      );
      await drain(tester, 25);
      expect(titles(), ['Existing authored note']);
      expect(
        state
            .notesForDayForTesting(
              outsideDate.kYear,
              outsideDate.kMonth,
              outsideDate.kDay,
            )
            .map((note) => note.title),
        ['Another selected calendar'],
        reason:
            'Source removal must clear off-screen copies while preserving other sources',
      );
      expect(
        find.text('No matches found'),
        findsOneWidget,
        reason: 'An already-open search must remove revoked source copies',
      );
      selectedSources.add('fixture-source');
      await repository.projectionChanged(removedSources: true);
      await drain(tester, 30);
      expect(
        titles(),
        containsAll(['Existing authored note', 'Imported appointment']),
      );
      expect(
        titles().where((title) => title == 'Imported appointment'),
        hasLength(1),
      );
      expect(
        state
            .notesForDayForTesting(
              outsideDate.kYear,
              outsideDate.kMonth,
              outsideDate.kDay,
            )
            .map((note) => note.title),
        containsAll(['Imported appointment', 'Another selected calendar']),
      );
      expect(
        find.text('No matches found'),
        findsNothing,
        reason:
            'Reselecting an acknowledged source must restore its copies once',
      );
      // Exercise the real engine across navigation while its catalog await is
      // held: the restarted data refresh must read the new Day View window.
      await tester.enterText(
        find.byType(TextField),
        'Another selected calendar',
      );
      await tester.pumpAndSettle();
      final catalogGate = Completer<void>();
      heldCatalog = catalogGate;
      heldCatalogStarted = Completer<void>();
      changedCatalog = true;
      CalendarInvalidationBus.instance.publish(
        const CalendarInvalidated(
          reason: CalendarInvalidationReason.eventSaved,
        ),
      );
      await drain(tester, 5);
      expect(heldCatalogStarted!.isCompleted, isTrue);
      standaloneWindows.clear();
      await tester.tap(
        find.widgetWithText(ListTile, 'Another selected calendar'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      catalogGate.complete();
      await drain(tester, 20);
      final nextDayStart = DateTime(
        outsideDay.year,
        outsideDay.month,
        outsideDay.day,
      ).toUtc();
      final nextDayEnd = DateTime(
        outsideDay.year,
        outsideDay.month,
        outsideDay.day + 1,
      ).toUtc();
      expect(standaloneWindows.length, greaterThanOrEqualTo(2));
      expect(
        standaloneWindows.take(2),
        everyElement((nextDayStart, nextDayEnd)),
        reason:
            'Viewport navigation and the preempted data refresh must both '
            'read the current Day View, even when the flow catalog changes',
      );
      expect(
        standaloneWindows,
        everyElement((nextDayStart, nextDayEnd)),
        reason:
            'The later confirmed-import invalidation must retain the active '
            'Day View instead of resetting hydration to the month behind it',
      );
      expect(
        state
            .notesForDayForTesting(
              outsideDate.kYear,
              outsideDate.kMonth,
              outsideDate.kDay,
            )
            .map((note) => note.title),
        containsAll(['Imported appointment', 'Another selected calendar']),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await drain(tester, 3);
      await tester.runAsync(() async {
        final client = Supabase.instance.client;
        await client.removeAllChannels();
        await client.realtime.disconnect();
        client.realtime.reconnectTimer.reset();
      });
    },
  );
}
