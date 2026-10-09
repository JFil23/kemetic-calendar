import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/account_view_cache.dart';
import 'package:mobile/data/pages_read_repository.dart';
import 'package:mobile/data/warm_state/pages_warm_resources.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/snapshot/calendar_snapshot_runtime.dart';
import 'package:mobile/features/pages/pages_board.dart';
import 'package:mobile/features/pages/pages_controller.dart';
import 'package:mobile/features/pages/pages_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages_resource_test.dart' show uid, session;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  var calendarReads = 0;
  Completer<void>? holdRead;
  final cache = AccountViewCache.instance;
  SupabaseClient getClient() => Supabase.instance.client;
  setUpAll(() async {
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family']);
      for (final asset in font['fonts']) {
        loader.addFont(rootBundle.load(asset['asset']));
      }
      await loader.load();
    }
    directory = await Directory.systemTemp.createTemp(
      'pages-calendar-refresh-',
    );
    Hive.init(directory.path);
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'fixture-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('user_event_filing_items_client')) {
          calendarReads++;
          await holdRead?.future;
          return http.Response(
            jsonEncode([
              {
                'id': 'fallback',
                'client_event_id': 'fallback',
                'title': 'Only filed item',
                'starts_at': DateTime.now().toUtc().toIso8601String(),
                'all_day': true,
                'calendar_is_personal': true,
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (request.url.path.contains('/auth/')) {
          return http.Response(
            '{}',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        throw StateError('Unrelated background read is offline');
      }),
    );
  });
  setUp(() async {
    await getClient().auth.recoverSession(session());
    cache.enterAccount('reset');
    cache.enterAccount(uid);
    WarmSnapshotStore.instance.invalidate(uid, prefix: 'pages.calendar.');
    await calendarSnapshotStore.deleteUserScope(uid);
    calendarReads = 0;
    holdRead = null;
  });
  tearDownAll(() async {
    await Supabase.instance.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<CalendarPageState> mountCalendar(
    WidgetTester tester,
    Widget preview,
  ) async {
    final key = CalendarPage.globalKey;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Offstage(
                child: CalendarPage(
                  key: key,
                  calendarBoundaryHarnessController:
                      CalendarBoundaryHarnessController(
                        expansionLevel: MonthExpansionLevel.compact,
                        content: CalendarBoundaryHarnessContent.empty,
                        instrumentation:
                            CalendarBoundaryInstrumentation.timingOnly,
                      ),
                ),
              ),
              preview,
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final state = key.currentState!;
    final day = KemeticMath.fromGregorian(DateTime.now());
    for (var i = 0; i < 5; i++) {
      state.debugAddNote(
        day.kYear,
        day.kMonth,
        day.kDay,
        'Calendar event $i',
        '',
        clientEventId: 'canonical-$i',
        notify: false,
      );
    }
    await tester.runAsync(
      () => state.debugPersistWarmStartCacheForTesting(uid),
    );
    CalendarPage.publishPagesSnapshot();
    await tester.pumpAndSettle();
    return state;
  }

  Future<List<int>> pixels(WidgetTester tester, GlobalKey key) async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return (await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return bytes!.buffer.asUint8List().toList();
    }))!;
  }

  testWidgets(
    'repeated passive refresh preserves complete Calendar pixels and count; real changes publish',
    (tester) async {
      final controller = PagesController(getClient(), cache: cache);
      final card = controller.cards[PagesDestination.calendar.index];
      final key = GlobalKey();
      final state = await mountCalendar(
        tester,
        RepaintBoundary(
          key: key,
          child: SizedBox(
            width: 190,
            child: ValueListenableBuilder<PagesCard>(
              valueListenable: card,
              builder: (_, value, _) => PagesTile(card: value, onTap: () {}),
            ),
          ),
        ),
      );
      expect(card.value.meta, startsWith('5 today'));
      final before = await pixels(tester, key);
      var publications = 0;
      card.addListener(() => publications++);
      final resources = PagesWarmResources(getClient(), cache, () => true);
      cache.publish(uid, 'pages.flows', const <PagesFlow>[]);
      cache.publish(uid, 'pages.hiddenCalendars', <String>{});
      for (var i = 0; i < 6; i++) {
        cache.beginRefreshCycle();
        await tester.runAsync(
          () => cache.load<Object>(
            uid,
            'pages.calendar',
            () async => (await resources.reads(
              cachedOnly: false,
            )['pages.calendar']!())!,
            mayFetch: () => true,
            stale: true,
          ),
        );
        expect(card.value.meta, startsWith('5 today'));
        CalendarPage.publishPagesSnapshot();
        await tester.pump(const Duration(milliseconds: 40));
        expect(card.value.meta, startsWith('5 today'));
        expect(await pixels(tester, key), before);
      }
      expect(calendarReads, 0);
      expect(publications, 0);
      final capture = Platform.environment['HAW_CALENDAR_CAPTURE_DIR'];
      if (capture != null) {
        await tester.runAsync(() async {
          await Directory(capture).create(recursive: true);
          await File('$capture/pages-calendar-stable.png').writeAsBytes(before);
        });
      }
      final day = KemeticMath.fromGregorian(DateTime.now());
      state.debugReplaceLiveNotesFromReadOnlyProjectionForTesting(
        kYear: day.kYear,
        kMonth: day.kMonth,
        kDay: day.kDay,
        title: 'Remaining event',
        clientEventId: 'remaining',
      );
      CalendarPage.publishPagesSnapshot();
      await tester.pump();
      expect(card.value.meta, startsWith('1 today'));
      expect(publications, 1);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets('a fallback already in flight yields to Calendar hydration', (
    tester,
  ) async {
    holdRead = Completer<void>();
    final repo = PagesReadRepository(getClient(), mayFetch: () => true);
    late Future<PagesCard> pending;
    await tester.runAsync(() async {
      pending = repo.calendar(DateTime.now(), const [], const {});
    });
    await tester.pump();
    await tester.runAsync(() async {
      for (var i = 0; i < 20 && calendarReads == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await mountCalendar(tester, const SizedBox());
    holdRead!.complete();
    final result = await tester.runAsync(() => pending);
    expect(result!.meta, startsWith('5 today'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  test(
    'cold Pages still loads; an account departure cancels its fallback',
    () async {
      final repo = PagesReadRepository(getClient(), mayFetch: () => true);
      expect(
        (await repo.calendar(DateTime.now(), const [], const {})).meta,
        '1 today',
      );
      WarmSnapshotStore.instance.invalidate(uid, prefix: 'pages.calendar.');
      holdRead = Completer<void>();
      final pending = repo.calendar(DateTime.now(), const [], const {});
      final checked = expectLater(
        pending,
        throwsA(anyOf(isA<ViewReadCancelled>(), isA<WarmReadCancelled>())),
      );
      while (calendarReads < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await getClient().auth.signOut(scope: SignOutScope.local);
      await getClient().auth.recoverSession(session());
      holdRead!.complete();
      await checked;
    },
  );
}
