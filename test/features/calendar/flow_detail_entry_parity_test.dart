import 'package:mobile/data/account_view_cache.dart';
import 'package:mobile/data/share_repo.dart';
import 'package:mobile/data/shared_practice_models.dart';
import 'package:mobile/features/pages/pages_page.dart';
import 'package:mobile/features/pages/pages_board.dart';
import 'package:mobile/features/pages/pages_layout.dart';
import 'package:mobile/features/pages/pages_models.dart';
import 'package:mobile/features/inbox/inbox_page.dart';
import 'package:mobile/features/inbox/inbox_activity_target.dart';
import 'package:mobile/features/nodes/library_read_state.dart';
import 'package:mobile/features/nodes/kemetic_node_reader_page.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/main.dart' show routeObserver;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/flow_post_model.dart';
import 'package:mobile/data/share_models.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import 'package:mobile/features/calendar/calendar_invalidation.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/follow_sky_detail_page.dart';
import 'package:mobile/features/calendar/flow_detail_calendar_scope.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/follow_sky_calendar_preview.dart';
import 'package:mobile/main.dart' show createAppRouterForTesting;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/maat_flow_visual_test_fonts.dart';
import '../profile/flow_post_owned_detail_test.dart'
    show owner, visitor, session;

const captureKey = ValueKey('universal-flow-detail-capture');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> flow;
  late List<Map<String, dynamic>> events;
  var offline = false;
  List<Map<String, dynamic>> follows = [];
  var denied = false;
  var calendarReads = 0;
  var detailReads = 0;
  Completer<void>? readHold;
  Completer<void>? flowReadHold;
  const personalTitle = 'Dinner with family';
  final today = DateUtils.dateOnly(DateTime.now());

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    for (final name in ['messages', 'events']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('com.llfbandit.app_links/$name'),
            (_) async => null,
          );
    }
    await loadMaatFlowVisualTestFonts();
    await Supabase.initialize(
      url: 'https://example.supabase.test',
      anonKey: 'fixture',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final table = request.url.path.split('/').last;
        Object? data = [];
        var status = 200;
        if (table == 'flows') {
          if (request.url.queryParameters.containsKey('id')) {
            detailReads++;
            await flowReadHold?.future;
          }
          data = request.url.queryParameters.containsKey('origin_flow_id')
              ? []
              : flow;
        }
        if (table == 'get_my_filed_flows_v1') data = [flow];
        if (table == 'user_event_filing_items_client') {
          final detail = request.url.queryParameters.containsKey(
            'filed_flow_id',
          );
          if (detail) await flowReadHold?.future;
          if (!detail) {
            calendarReads++;
            await readHold?.future;
          }
          if (offline || denied) {
            status = denied ? 403 : 503;
            data = {
              'code': denied ? '42501' : '503',
              'message': 'fixture unavailable',
            };
          } else {
            final all = detail
                ? events.where((e) => e['filed_flow_id'] == 42).toList()
                : events;
            final offset =
                int.tryParse(request.url.queryParameters['offset'] ?? '') ?? 0;
            final limit =
                int.tryParse(request.url.queryParameters['limit'] ?? '') ??
                1000;
            data = all.skip(offset).take(limit).toList();
          }
        }
        if (table == 'follows') data = follows;
        if (table == 'get_together_inbox' ||
            table == 'get_commons_together_home_cards') {
          data = {};
        }
        if (table == 'logout') data = {};
        return http.Response(
          jsonEncode(data),
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  Future<void> resetFixtures() async {
    SharedPreferences.setMockInitialValues({});
    follows = [];
    offline = false;
    denied = false;
    readHold = null;
    flowReadHold = null;
    calendarReads = 0;
    detailReads = 0;
    await Supabase.instance.client.auth.recoverSession(session(owner));
    await WarmSnapshotStore.instance.forgetAccount(owner);
    await WarmSnapshotStore.instance.forgetAccount(visitor);
    flow = {
      'id': 42,
      'user_id': owner,
      'calendar_id': 'personal',
      'name': 'Evening practice',
      'color': 0x8fa88a,
      'active': true,
      'visible_in_active_list': true,
      'is_saved': false,
      'is_hidden': false,
      'start_date': today.toIso8601String(),
      'end_date': today.add(const Duration(days: 120)).toIso8601String(),
      'notes': 'mode=gregorian;ov=An%20evening%20practice',
      'rules': [],
    };
    events = [
      for (var i = 0; i < 120; i++)
        {
          'id': 'personal-$i',
          'user_id': owner,
          'calendar_id': 'personal',
          'client_event_id': 'personal-$i',
          'title': personalTitle,
          'all_day': false,
          'starts_at': DateTime(
            today.year,
            today.month,
            today.day + i,
            18,
          ).toUtc().toIso8601String(),
          'ends_at': DateTime(
            today.year,
            today.month,
            today.day + i,
            19,
          ).toUtc().toIso8601String(),
          'item_kind': 'note',
          'lifecycle': 'active',
          'live_on_calendar': true,
          'calendar_color': 0x4285f4,
        },
      {
        'id': 'practice',
        'client_event_id': 'practice',
        'user_id': owner,
        'title': 'Read and reflect',
        'all_day': true,
        'starts_at': today.toUtc().toIso8601String(),
        'filed_flow_id': 42,
        'flow_local_id': 42,
        'flow_active': true,
        'item_kind': 'flow',
        'lifecycle': 'active',
        'live_on_calendar': true,
      },
    ];
  }

  setUp(resetFixtures);
  tearDownAll(() async => Supabase.instance.dispose());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 25; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  Future<GoRouter> mountPages(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    AppRestorationService.debugUserIdResolver = () => null;
    addTearDown(() => AppRestorationService.debugUserIdResolver = null);
    final app = createAppRouterForTesting();
    addTearDown(app.dispose);
    final router = GoRouter(
      initialLocation: '/pages',
      observers: [routeObserver],
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold()),
        ...app.configuration.routes.whereType<GoRoute>().where(
          (r) => [
            '/pages',
            '/shared-flow/by-flow/:flowId',
            '/inbox',
            '/nodes/:nodeId',
          ].contains(r.path),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'GentiumPlus'),
        routerConfig: router,
        builder: (_, child) => RepaintBoundary(key: captureKey, child: child!),
      ),
    );
    await settle(tester);
    return router;
  }

  Finder tile(PagesDestination destination) => find.byWidgetPredicate(
    (w) => w is PagesTile && w.card.destination == destination,
  );

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_PAGES_ENTRY')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(captureKey),
    );
    await tester.runAsync(() async {
      final bitmap = await boundary.toImage(pixelRatio: 1);
      final bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
      await Directory('/tmp/haw-pages-entry').create(recursive: true);
      await File(
        '/tmp/haw-pages-entry/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      bitmap.dispose();
    });
  }

  Future<void> checkPagesFlow(WidgetTester tester) async {
    final now = DateTime.now();
    final targetTime = now.add(const Duration(hours: 2));
    final base = Map<String, dynamic>.from(events.last);
    events = [
      ...events.where((e) => e['filed_flow_id'] != 42),
      {
        ...base,
        'id': 'earlier',
        'client_event_id': 'earlier-client',
        'title': 'Daily Math',
        'detail': 'Earlier occurrence detail',
        'starts_at': now
            .subtract(const Duration(hours: 2))
            .toUtc()
            .toIso8601String(),
      },
      {
        ...base,
        'id': 'target',
        'client_event_id': 'target-client',
        'title': 'Daily Math',
        'detail': 'Displayed occurrence detail',
        'starts_at': targetTime.toUtc().toIso8601String(),
      },
    ];
    AccountViewCache.instance.enterAccount(owner);
    AccountViewCache.instance.evictPrefix(owner, '');
    final router = await mountPages(tester);
    final pages = tester.state(find.byType(PagesPage));
    final studio = tile(PagesDestination.studio);
    await tester.ensureVisible(studio);
    await tester.pumpAndSettle();
    expect(
      tester.widget<PagesTile>(studio).card.event?.clientEventId,
      'target-client',
    );
    final layout = tester.state(find.byType(PagesLayout));
    final position = tester.getTopLeft(studio);
    await capture(tester, 'pages-before-tap');
    await tester.tap(studio);
    await settle(tester);
    expect(router.state.uri.path, '/shared-flow/by-flow/42');
    expect(router.state.uri.queryParameters['occurrence'], 'target-client');
    expect(
      find.byKey(const ValueKey('user-flow-detail-surface-42')),
      findsOneWidget,
    );
    expect(
      find
          .text('Displayed occurrence detail', findRichText: true)
          .hitTestable(),
      findsOneWidget,
    );
    expect(
      find.text('Earlier occurrence detail', findRichText: true).hitTestable(),
      findsNothing,
    );
    expect(find.byType(FlowDetailCalendarScope), findsOneWidget);
    await capture(tester, 'displayed-event-expanded');
    await tester.tap(find.byKey(const ValueKey('user-flow-detail-back')));
    await settle(tester);
    expect(router.state.uri.path, '/pages');
    expect(tester.state(find.byType(PagesPage)), same(pages));
    expect(tester.state(find.byType(PagesLayout)), same(layout));
    expect(tester.getTopLeft(studio), position);

    // A priority-warmed complete snapshot must paint and expand the exact
    // occurrence while both canonical repository refreshes are still pending.
    final refresh = flowReadHold = Completer<void>();
    await tester.tap(studio);
    var frames = 0;
    final expanded = find
        .text('Displayed occurrence detail', findRichText: true)
        .hitTestable();
    while (expanded.evaluate().isEmpty && frames < 40) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      frames++;
    }
    expect(refresh.isCompleted, isFalse);
    expect(
      find.byKey(const ValueKey('user-flow-detail-surface-42')),
      findsOneWidget,
    );
    expect(expanded, findsOneWidget);
    debugPrint(
      'PAGES_FLOW_OPEN warm_expanded_frames=$frames server_refresh_pending=true',
    );
    await capture(tester, 'priority-warm-expanded');
    refresh.complete();
    flowReadHold = null;
    await settle(tester);
    expect(expanded, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('user-flow-detail-back')));
    await settle(tester);
    expect(tester.state(find.byType(PagesPage)), same(pages));
    expect(tester.getTopLeft(studio), position);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await Supabase.instance.client.removeAllChannels();
      await Supabase.instance.client.realtime.disconnect();
      Supabase.instance.client.realtime.reconnectTimer.reset();
    });
    await settle(tester);
    await WarmSnapshotStore.instance.flushed;
    router.dispose();
  }

  Future<void> checkPagesInbox(WidgetTester tester) async {
    final time = DateTime.now().toUtc();
    follows = [
      {
        'created_at': time.toIso8601String(),
        'follower_id': visitor,
        'profiles': {'display_name': 'Alton Chisholm', 'handle': 'alton'},
      },
    ];
    AccountViewCache.instance.enterAccount(owner);
    AccountViewCache.instance.evictPrefix(owner, '');
    final activity = (await tester.runAsync(
      () => ShareRepo(Supabase.instance.client).getRecentActivity(),
    ))!;
    AccountViewCache.instance.publish(
      owner,
      'social.together',
      const TogetherInboxSnapshot(),
    );
    AccountViewCache.instance.publish(
      owner,
      'social.inbox',
      <InboxShareItem>[],
    );
    final router = await mountPages(tester);
    final pages = tester.state(find.byType(PagesPage));
    final inbox = tile(PagesDestination.inbox);
    await tester.ensureVisible(inbox);
    await tester.pumpAndSettle();
    expect(
      tester.widget<PagesTile>(inbox).card.inboxActivity?.actorId,
      visitor,
    );
    await tester.tap(inbox);
    await settle(tester);
    expect(
      router.state.uri.queryParameters['activity'],
      inboxActivityIdentity(activity.single),
    );
    expect(find.byType(InboxPage), findsOneWidget);
    expect(find.text('Community'), findsOneWidget);
    expect(
      find.text('Alton Chisholm started following you').hitTestable(),
      findsOneWidget,
    );
    await capture(tester, 'inbox-displayed-alert');
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Community'), findsNothing);
    await tester.tap(find.byTooltip('Close Inbox'));
    await settle(tester);
    expect(tester.state(find.byType(PagesPage)), same(pages));
    // Warm re-entry still shows the same alert, then account departure clears it.
    await tester.tap(inbox);
    await settle(tester);
    expect(find.text('Community'), findsOneWidget);
    await Supabase.instance.client.auth.recoverSession(session(visitor));
    await settle(tester);
    expect(find.text('Alton Chisholm started following you'), findsNothing);
    await Supabase.instance.client.auth.recoverSession(session(owner));
    await settle(tester);
    expect(find.text('Alton Chisholm started following you'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await Supabase.instance.client.removeAllChannels();
      await Supabase.instance.client.realtime.disconnect();
      Supabase.instance.client.realtime.reconnectTimer.reset();
    });
    await settle(tester);
    await WarmSnapshotStore.instance.flushed;
    router.dispose();
  }

  Future<void> checkPagesLibrary(WidgetTester tester) async {
    AccountViewCache.instance.enterAccount(owner);
    AccountViewCache.instance.evictPrefix(owner, '');
    AccountViewCache.instance.publish(
      owner,
      'library.progress',
      LibraryReadSnapshot(
        progressByNodeId: {
          'ptah': LibraryNodeProgress(
            nodeId: 'ptah',
            progressPercent: 8,
            lastReadAt: DateTime.now(),
          ),
        },
      ),
    );
    final router = await mountPages(tester);
    final library = tile(PagesDestination.library);
    await tester.ensureVisible(library);
    await tester.pumpAndSettle();
    expect(tester.widget<PagesTile>(library).card.libraryNodeId, 'ptah');
    await tester.tap(library);
    await settle(tester);
    expect(router.state.uri.path, '/nodes/ptah');
    expect(find.byType(KemeticNodeReaderPage), findsOneWidget);
    await capture(tester, 'library-continued-reading');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await Supabase.instance.client.removeAllChannels();
      await Supabase.instance.client.realtime.disconnect();
      Supabase.instance.client.realtime.reconnectTimer.reset();
    });
    await settle(tester);
    await WarmSnapshotStore.instance.flushed;
    router.dispose();
  }

  InboxShareItem share({bool sent = true, bool imported = false}) =>
      InboxShareItem(
        shareId: 'shared-flow',
        kind: InboxShareKind.flow,
        senderId: sent ? owner : visitor,
        recipientId: sent ? visitor : owner,
        payloadId: '42',
        title: flow['name'] as String,
        createdAt: today,
        viewedAt: today,
        currentlyActiveImportedFlowId: imported ? 42 : null,
        payloadJson: {
          'name': flow['name'],
          'notes': flow['notes'],
          'color': flow['color'],
          'start_date': flow['start_date'],
          'rules': [],
          'events': [
            {'title': 'Read and reflect', 'offset_days': 0, 'all_day': true},
          ],
        },
      );
  FlowPost post() => FlowPost.fromJson({
    'id': 'flow-post',
    'flow_id': 42,
    'user_id': owner,
    'name': flow['name'],
    'color': flow['color'],
    'rules': [],
    'created_at': today.toIso8601String(),
    'payload': share().payloadJson,
  });

  testWidgets(
    'universal details: complete route visuals, calendar coverage, warm refresh and account boundaries',
    (tester) async {
      // One widget clock owns the static cache write chain throughout.
      await checkPagesFlow(tester);
      await resetFixtures();
      await checkPagesInbox(tester);
      await resetFixtures();
      await checkPagesLibrary(tester);
      await resetFixtures();

      // Keep the cancellation scenarios and visual parity in one widget clock.
      for (final departure in ['none', 'route', 'account']) {
        detailReads = 0;
        expect(
          WarmSnapshotStore.instance.peek(owner, 'flow.detail.42'),
          isNull,
        );
        var warming = true;
        final held = Completer<void>();
        final priorRead = WarmSnapshotStore.instance
            .refresh(owner, 'flow.detail.42', () async {
              await held.future;
              return flow;
            }, isCurrent: () => warming)
            .then<void>(
              (_) => fail('The departed warm owner must be fenced'),
              onError: (Object error) =>
                  expect(error, isA<WarmReadCancelled>()),
            );
        final app = createAppRouterForTesting();
        final route = app.configuration.routes.whereType<GoRoute>().singleWhere(
          (r) => r.path == '/shared-flow/by-flow/:flowId',
        );
        final router = GoRouter(
          initialLocation: '/launch',
          routes: [
            GoRoute(path: '/launch', builder: (_, _) => const Scaffold()),
            route,
          ],
        );
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        unawaited(router.push('/shared-flow/by-flow/42'));
        await settle(tester);
        expect(
          detailReads,
          0,
          reason: 'The route coalesces the held warm read',
        );
        expect(
          find.byKey(const ValueKey('user-flow-detail-surface-42')),
          findsNothing,
        );
        if (departure == 'route') {
          router.pop();
          await settle(tester);
        } else if (departure == 'account') {
          await Supabase.instance.client.auth.recoverSession(session(visitor));
          await tester.pump();
          await Supabase.instance.client.auth.recoverSession(session(owner));
          await tester.pump();
        }
        warming = false;
        held.complete();
        await settle(tester);
        await priorRead;
        if (departure == 'none') {
          expect(
            detailReads,
            1,
            reason: 'The still-current route owns one fresh read',
          );
          expect(
            find.byKey(const ValueKey('user-flow-detail-surface-42')),
            findsOneWidget,
          );
          expect(find.text('Manage flow'), findsOneWidget);
          expect(find.textContaining('Error:'), findsNothing);
        } else {
          expect(
            detailReads,
            0,
            reason: 'Departed routes/accounts never restart reads',
          );
          expect(
            find.byKey(const ValueKey('user-flow-detail-surface-42')),
            findsNothing,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        app.dispose();
        await settle(tester);
        await WarmSnapshotStore.instance.forgetAccount(owner);
        await WarmSnapshotStore.instance.forgetAccount(visitor);
      }
      for (final sky in [false, true]) {
        WarmSnapshotStore.instance.invalidate(owner);

        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        if (sky) {
          flow['name'] = 'Follow the Sky';
          flow['notes'] = 'maat=track-the-sky';
        }
        final app = createAppRouterForTesting();
        final routes = app.configuration.routes
            .whereType<GoRoute>()
            .where(
              (r) => [
                '/shared-flow/:shareId',
                '/shared-flow/by-flow/:flowId',
                '/flow-post/:postId',
              ].contains(r.path),
            )
            .toList();
        expect(routes, hasLength(3));
        final references = <String, ui.Image>{};
        for (final entry in [
          'pages',
          'inbox-sent',
          'inbox-imported',
          'profile',
          'feed',
        ]) {
          final router = GoRouter(
            initialLocation: '/launch',
            routes: [
              GoRoute(path: '/launch', builder: (_, _) => const Scaffold()),
              ...routes,
            ],
          );
          await tester.pumpWidget(
            MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(fontFamily: 'GentiumPlus'),
              routerConfig: router,
              builder: (context, child) =>
                  RepaintBoundary(key: captureKey, child: child!),
            ),
          );
          if (entry == 'pages') {
            unawaited(router.push('/shared-flow/by-flow/42'));
          } else if (entry.startsWith('inbox')) {
            unawaited(
              router.push(
                '/shared-flow/shared-flow',
                extra: share(
                  sent: entry == 'inbox-sent',
                  imported: entry == 'inbox-imported',
                ),
              ),
            );
          } else {
            unawaited(router.push('/flow-post/flow-post', extra: post()));
          }
          await settle(tester);
          expect(
            find.byType(FlowDetailCalendarScope),
            findsOneWidget,
            reason: entry,
          );
          if (sky) {
            final surface = tester.widget<FollowSkyDetailSurface>(
              find.byType(FollowSkyDetailSurface),
            );
            expect(surface.existingFlowId, 42, reason: entry);
            expect(surface.isJoined, isTrue, reason: entry);
            expect(
              surface.calendarPreview.rows.any((r) => r.title == personalTitle),
              isTrue,
              reason: entry,
            );
          } else {
            expect(
              find.byKey(const ValueKey('user-flow-detail-surface-42')),
              findsOneWidget,
              reason: entry,
            );
            expect(find.text(personalTitle), findsWidgets, reason: entry);
          }
          expect(tester.takeException(), isNull, reason: entry);
          final scroll = tester
              .widget<CustomScrollView>(
                find.byKey(
                  ValueKey(
                    sky ? 'follow-sky-scroll' : 'user-flow-detail-scroll-42',
                  ),
                ),
              )
              .controller!;
          for (final phase in {
            'hero': 0.0,
            'calendar': 550.0,
            'schedule': 1050.0,
            'end': scroll.position.maxScrollExtent,
          }.entries) {
            scroll.jumpTo(
              phase.value.clamp(0.0, scroll.position.maxScrollExtent),
            );
            await tester.pumpAndSettle();
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(captureKey),
            );
            final rendered = (await tester.runAsync(() => boundary.toImage()))!;
            final reference = references[phase.key];
            if (reference == null) {
              references[phase.key] = rendered;
            } else {
              await expectLater(
                rendered,
                matchesReferenceImage(reference),
                reason: '$entry ${phase.key}',
              );
              rendered.dispose();
            }
            final folder = Platform.environment['HAW_FLOW_DETAIL_CAPTURE_DIR'];
            if (folder != null && entry == 'pages') {
              await tester.runAsync(() async {
                final bytes = await references[phase.key]!.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await Directory(folder).create(recursive: true);
                await File(
                  '$folder/${sky ? 'sky' : 'custom'}-${phase.key}-390x844.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
              });
            }
          }
          await tester.pumpWidget(const SizedBox());
          router.dispose();
          await settle(tester);
        }
        for (final reference in references.values) {
          reference.dispose();
        }
        app.dispose();
      }
      // Receiving a snapshot uses the same Sky view and the viewer's calendar,
      // but does not bind the sender's ID or offer owned-flow actions.
      final invitationApp = createAppRouterForTesting();
      final shareRoute = invitationApp.configuration.routes
          .whereType<GoRoute>()
          .singleWhere((r) => r.path == '/shared-flow/:shareId');
      final invitationRouter = GoRouter(
        initialLocation: '/launch',
        routes: [
          GoRoute(path: '/launch', builder: (_, _) => const Scaffold()),
          shareRoute,
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: invitationRouter),
      );
      unawaited(
        invitationRouter.push(
          '/shared-flow/shared-flow',
          extra: share(sent: false),
        ),
      );
      await settle(tester);
      final invitation = tester.widget<FollowSkyDetailSurface>(
        find.byType(FollowSkyDetailSurface),
      );
      expect(invitation.existingFlowId, isNull);
      expect(invitation.isJoined, isFalse);
      expect(invitation.existingFlowNotes, flow['notes']);
      expect(
        invitation.calendarPreview.rows.any((r) => r.title == personalTitle),
        isTrue,
      );
      expect(find.text('Import Flow'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('flow-detail-start-date')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('flow-detail-start-date')));
      await tester.pumpAndSettle();
      expect(find.text('Gregorian Calendar'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      invitationRouter.dispose();
      invitationApp.dispose();
      await settle(tester);
      calendarReads = 0;
      WarmSnapshotStore.instance.invalidate(owner);

      // Force more than one filing page; calendar context must not stop at a cap.
      events = [
        for (var i = 0; i < 1002; i++)
          {...events.first, 'id': 'event-$i', 'client_event_id': 'event-$i'},
      ];
      FollowSkyCalendarPreview? preview;
      Widget scope() => MaterialApp(
        home: FlowDetailCalendarScope(
          start: today,
          end: today.add(const Duration(days: 29)),
          builder: (_, value) {
            preview = value;
            return Text('${value.rows.length}');
          },
        ),
      );
      await tester.pumpWidget(scope());
      await settle(tester);
      expect(preview!.rows, hasLength(1002));
      expect(calendarReads, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      offline = true;
      await tester.pumpWidget(scope());
      await settle(tester);
      expect(preview!.rows, hasLength(1002));
      expect(preview!.supply, CalendarPreviewSupply.loaded);
      offline = false;
      events = [
        {...events.first, 'title': 'Acknowledged edit'},
      ];
      CalendarInvalidationBus.instance.publish(
        const CalendarInvalidated(
          reason: CalendarInvalidationReason.eventSaved,
        ),
      );
      await settle(tester);
      expect(preview!.rows.single.title, 'Acknowledged edit');
      // An in-flight old-account read cannot paint after an A -> B -> A change.
      readHold = Completer<void>();
      CalendarInvalidationBus.instance.publish(
        const CalendarInvalidated(
          reason: CalendarInvalidationReason.eventSaved,
        ),
      );
      await tester.pump(const Duration(milliseconds: 80));
      await Supabase.instance.client.auth.recoverSession(session(visitor));
      await tester.pump();
      expect(preview!.rows, isEmpty);
      await Supabase.instance.client.auth.recoverSession(session(owner));
      readHold!.complete();
      readHold = null;
      await settle(tester);
      denied = true;
      CalendarInvalidationBus.instance.publish(
        const CalendarInvalidated(
          reason: CalendarInvalidationReason.eventSaved,
        ),
      );
      await settle(tester);
      expect(preview!.supply, CalendarPreviewSupply.unavailable);
      expect(preview!.rows, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
