import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/flow_appearance_store.dart';
import 'package:mobile/data/flow_post_model.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import 'package:mobile/features/calendar/calendar_invalidation.dart';
import 'package:mobile/features/calendar/presentation/user_flow_appearance_visual.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/follow_sky_detail_page.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_detail_page.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_detail_page.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_detail_page.dart';
import 'package:mobile/features/calendar/the_kar/presentation/kar_detail_surface.dart';
import 'package:mobile/features/calendar/the_kar/the_kar_models.dart';
import 'package:mobile/features/profile/flow_post_detail_page.dart';
import 'package:mobile/features/sharing/share_flow_sheet.dart';
import 'package:mobile/main.dart' show createAppRouterForTesting;
import 'package:mobile/widgets/utility_sheet_route_scaffold.dart';
import 'package:mobile/features/calendar/presentation/archived_maat_flow_detail_view.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../support/maat_flow_visual_test_fonts.dart';

const owner = '40bef9d0-2209-4fe3-9132-d5a385fbc418';
const visitor = '50bef9d0-2209-4fe3-9132-d5a385fbc418';
const id = 177;
String session(String user) {
  final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  String enc(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return jsonEncode({
    'access_token':
        '${enc({'alg': 'HS256', 'typ': 'JWT'})}.${enc({'sub': user, 'exp': exp})}.signature',
    'refresh_token': 'fixture',
    'expires_in': 3600,
    'token_type': 'bearer',
    'user': {
      'id': user,
      'app_metadata': {},
      'user_metadata': {},
      'aud': 'authenticated',
      'created_at': '2026-01-01T00:00:00Z',
    },
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> flow;
  late Map<String, dynamic> post;
  late List<Map<String, dynamic>> events;
  final requests = <http.Request>[];
  var serial = 0;
  var sourceMissing = false;
  var sourceFailure = false;
  Completer<void>? sourceHold;
  Completer<void>? journalHold;
  late Uint8List image;

  http.Response reply(http.Request request, Object? data, [int status = 200]) =>
      http.Response(
        jsonEncode(data),
        status,
        request: request,
        headers: {'content-type': 'application/json'},
      );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    image = File(
      'assets/profile/day_cycle_registered_v3_jpg/7am.jpg',
    ).readAsBytesSync();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'com.llfbandit.app_links/messages',
      'com.llfbandit.app_links/events',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (_) async => null,
      );
    }
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'fixture-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        final table = request.url.path.split('/').last;
        if (request.url.path.contains('/storage/v1/')) {
          return http.Response.bytes(
            image,
            200,
            request: request,
            headers: {'content-type': 'image/jpeg'},
          );
        }
        if (table == 'flows') {
          if (request.url.queryParameters.containsKey('origin_flow_id')) {
            return reply(request, []);
          }
          if (request.method == 'PATCH') {
            flow.addAll(jsonDecode(request.body) as Map<String, dynamic>);
          }
          await sourceHold?.future;
          if (sourceFailure) {
            return reply(request, {
              'code': '57014',
              'message': 'fixture failure',
            }, 503);
          }
          return reply(request, sourceMissing ? null : flow);
        }
        if (table == 'user_event_filing_items_client') {
          return reply(request, events);
        }
        if (table == 'flow_posts') return reply(request, post);
        if (table == 'kar_shrines') {
          final shrine =
              KarShrine(
                id: 'fixture-shrine',
                netjer: KarNetjer.djehuty,
                revision: 2,
                cycles: const [],
              ).beginCycle(
                cycleId: 'fixture-cycle',
                anchorDate: DateTime.parse(flow['start_date'] as String),
                flowId: id,
              );
          return reply(request, {
            'id': shrine.id,
            'user_id': owner,
            'netjer_key': shrine.netjer.key,
            'revision': shrine.revision,
            'state': shrine.toStateJson(),
          });
        }
        if (table == 'journal_entries') {
          if (request.method == 'GET') {
            await journalHold?.future;
            return reply(request, null);
          }
          return reply(request, {});
        }
        return reply(request, []);
      }),
    );
    await loadMaatFlowVisualTestFonts();
    await rootBundle.loadString(
      'assets/follow_the_sky/sky_catalog_v2_graphics_v1.json',
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() async {
    serial++;
    SharedPreferences.setMockInitialValues({});
    await Supabase.instance.client.auth.recoverSession(session(owner));
    WarmSnapshotStore.instance.invalidate(owner);
    WarmSnapshotStore.instance.invalidate(visitor);
    final today = DateUtils.dateOnly(DateTime.now());
    flow = {
      'id': id,
      'user_id': owner,
      'calendar_id': 'personal-calendar',
      'name': 'Live autumn practice',
      'color': 0xD34F22,
      'active': true,
      'is_saved': false,
      'is_hidden': false,
      'start_date': today.toIso8601String(),
      'end_date': today.add(const Duration(days: 1)).toIso8601String(),
      'notes': 'mode=gregorian;ov=An%20autumn%20practice',
      'rules': [],
      'appearance': {'version': 1, 'image_object_path': '$owner/live.jpg'},
    };
    events = [
      for (var i = 0; i < 2; i++)
        {
          'id': 'event-$i',
          'user_id': owner,
          'client_event_id': 'original-$i',
          'filed_flow_id': id,
          'flow_local_id': id,
          'item_kind': 'flow',
          'title': 'Autumn day ${i + 1}',
          'detail': 'Existing note',
          'all_day': true,
          'starts_at': today.add(Duration(days: i)).toUtc().toIso8601String(),
          'ends_at': today.add(Duration(days: i + 1)).toUtc().toIso8601String(),
        },
    ];
    post = {
      'id': 'post-$serial',
      'user_id': owner,
      'flow_id': id,
      'name': 'Published autumn practice',
      'color': 0xD34F22,
      'rules': [],
      'created_at': '2026-10-05T00:00:00Z',
      'payload': {
        'name': 'Published autumn practice',
        'color': 0xD34F22,
        'notes': 'Published overview',
        'rules': [],
        'events': [
          {'offset_days': 0, 'title': 'Published day', 'all_day': true},
        ],
        'appearance': {'version': 1, 'image_object_path': '$owner/old.jpg'},
      },
    };
    sourceMissing = sourceFailure = false;
    sourceHold = journalHold = null;
    requests.clear();
    FlowAppearanceStore.debugResetImageCacheForTesting();
    final store = FlowAppearanceStore(Supabase.instance.client);
    store.rememberImageBytes('$owner/live.jpg', image);
    store.rememberImageBytes('$owner/new.jpg', image);
    store.rememberImageBytes('$owner/old.jpg', image);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> choose(WidgetTester tester, String action) async {
    await tester.tap(
      find.byKey(const ValueKey('user-flow-detail-options')).hitTestable(),
    );
    await settle(tester);
    await tester.tap(find.byKey(ValueKey('flow-detail-action-$action')));
    await settle(tester);
  }

  Future<void> pump(
    WidgetTester tester, {
    bool isOwner = true,
    List<FlowPost>? sequence,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final selected = FlowPost.fromJson(post);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'GentiumPlus'),
        home: RepaintBoundary(
          key: const ValueKey('posted-detail-capture'),
          child: UtilitySheetRouteScaffold(
            semanticLabel: 'Flow details',
            maxWidth: 640,
            onClose: () {},
            child: FlowPostDetailPage(
              post: selected,
              posts: sequence,
              isOwner: isOwner,
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final folder = Platform.environment['HAW_CANONICAL_POST_CAPTURE_DIR'];
    if (folder == null) return;
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pump();
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('posted-detail-capture')),
      );
      final rendered = await boundary.toImage();
      final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
      await Directory(folder).create(recursive: true);
      await File('$folder/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      rendered.dispose();
    });
  }

  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(820, 1180),
    const Size(1180, 820),
  ]) {
    testWidgets(
      'real posted source matches canonical detail geometry at $size',
      (tester) async {
        if (size == const Size(844, 390)) {
          flow['name'] = 'autumn ideas for the month of October!!';
        }
        await pump(tester, size: size);
        final bounds = tester.getRect(find.byType(MaatFlowDetailShell));
        expect(bounds.width, size.width > 640 ? 640 : size.width);
        expect(bounds.center.dx, size.width / 2);
        expect(
          find.byKey(utilitySheetRouteCloseButtonKey).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.byKey(utilitySheetRouteDragHandleKey).hitTestable(),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('user-flow-manage')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('user-flow-detail-options')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<UserFlowAppearanceHero>(
                find.byKey(const ValueKey('user-flow-detail-appearance')),
              )
              .appearance
              .imageObjectPath,
          '$owner/live.jpg',
        );
        await capture(
          tester,
          'actual-post-${size.width.toInt()}x${size.height.toInt()}',
        );
        if (size == const Size(844, 390)) {
          final manage = find.byKey(const ValueKey('user-flow-manage'));
          final caption = tester.getRect(
            find.byKey(const ValueKey('user-flow-detail-caption')),
          );
          final title = tester.getRect(
            find.byKey(const ValueKey('user-flow-detail-title')),
          );
          final back = tester.getRect(
            find.byKey(const ValueKey('user-flow-detail-back')),
          );
          final options = tester.getRect(
            find.byKey(const ValueKey('user-flow-detail-options')),
          );
          expect(caption.top, greaterThanOrEqualTo(back.bottom + 8));
          expect(caption.top, greaterThanOrEqualTo(options.bottom + 8));
          expect(title.top, greaterThanOrEqualTo(caption.bottom + 6.9));
          expect(title.bottom, lessThan(tester.getRect(manage).top));
          expect(manage.hitTestable(), findsOneWidget);
          final manageBounds = tester.getRect(manage);
          expect(manageBounds.bottom, lessThanOrEqualTo(size.height));
          await tester.tap(
            find.byKey(const ValueKey('user-flow-detail-options')),
          );
          await settle(tester);
          for (final action in [
            'journal',
            'edit',
            'share',
            'save',
            'remove-profile-post',
          ]) {
            expect(
              find.byKey(ValueKey('flow-detail-action-$action')).hitTestable(),
              findsOneWidget,
            );
          }
          await tester.tapAt(const Offset(1, 1));
          await settle(tester);
          final scroll = find.byKey(
            const ValueKey('user-flow-detail-scroll-177'),
          );
          final position = tester
              .state<ScrollableState>(
                find.descendant(of: scroll, matching: find.byType(Scrollable)),
              )
              .position;
          final before = position.pixels;
          await tester.drag(scroll, const Offset(0, -260));
          await settle(tester);
          expect(position.pixels, greaterThan(before));
          expect(manage.hitTestable(), findsOneWidget);
          await capture(tester, 'actual-post-844x390-scrolled');
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'owned profile flow uses active source image and the My Flows menu',
    (tester) async {
      await pump(tester);
      expect(find.text('Live autumn practice'), findsWidgets);
      expect(find.text('Published autumn practice'), findsNothing);
      final hero = tester.widget<UserFlowAppearanceHero>(
        find.byKey(const ValueKey('user-flow-detail-appearance')),
      );
      expect(hero.appearance.imageObjectPath, '$owner/live.jpg');
      expect(find.textContaining('SAVED ·'), findsNothing);
      expect(find.byKey(const ValueKey('user-flow-manage')), findsOneWidget);
      expect(find.text('Remove from profile'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('user-flow-detail-options')));
      await settle(tester);
      for (final label in [
        'Done / Add to journal',
        'Edit Flow',
        'Share Flow',
        'Save Flow',
        'Remove from profile',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(requests.where((r) => r.method != 'GET'), isEmpty);
    },
  );

  testWidgets(
    'profile edit opens exact source route and refreshes source on return',
    (tester) async {
      String? editedId;
      String? editedCalendar;
      final app = createAppRouterForTesting();
      final route = app.configuration.routes.whereType<GoRoute>().singleWhere(
        (r) => r.path == '/flow-post/:postId',
      );
      final router = GoRouter(
        initialLocation: '/profile/me',
        routes: [
          GoRoute(
            path: '/profile/me',
            builder: (_, _) => const Scaffold(body: Text('Profile')),
          ),
          route,
          GoRoute(
            path: '/flows/:flowId/edit',
            builder: (context, state) {
              editedId = state.pathParameters['flowId'];
              editedCalendar = state.uri.queryParameters['calendarId'];
              return Scaffold(
                body: TextButton(
                  onPressed: () {
                    flow['name'] = 'Edited autumn practice';
                    flow['appearance'] = {
                      'version': 1,
                      'image_object_path': '$owner/new.jpg',
                    };
                    WarmSnapshotStore.instance.invalidate(
                      owner,
                      prefix: 'flow.',
                    );
                    CalendarInvalidationBus.instance.publish(
                      const CalendarInvalidated(
                        reason: CalendarInvalidationReason.flowStudioPersisted,
                        flowId: id,
                      ),
                    );
                    context.pop(true);
                  },
                  child: Text('Save source ${state.pathParameters['flowId']}'),
                ),
              );
            },
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      unawaited(
        router.push('/flow-post/${post['id']}', extra: FlowPost.fromJson(post)),
      );
      await settle(tester);
      await choose(tester, 'edit');
      expect(editedId, '177');
      expect(editedCalendar, 'personal-calendar');
      expect(find.text('Save source 177'), findsOneWidget);
      await tester.tap(find.text('Save source 177'));
      await settle(tester);
      expect(find.text('Edited autumn practice'), findsWidgets);
      expect(
        tester
            .widget<UserFlowAppearanceHero>(
              find.byKey(const ValueKey('user-flow-detail-appearance')),
            )
            .appearance
            .imageObjectPath,
        '$owner/new.jpg',
      );
      expect(find.byType(FlowPostDetailPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      app.dispose();
    },
  );

  testWidgets('canonical Share and Save actions receive the real source ID', (
    tester,
  ) async {
    await pump(tester);
    await choose(tester, 'save');
    final patch = requests.singleWhere(
      (r) => r.method == 'PATCH' && r.url.path.endsWith('/flows'),
    );
    expect(patch.url.queryParameters['id'], 'eq.177');
    expect(jsonDecode(patch.body), {'is_saved': true});
    await choose(tester, 'share');
    expect(
      tester.widget<ShareFlowSheet>(find.byType(ShareFlowSheet)).flowId,
      id,
    );
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('canonical journal action writes the owned flow badge to today', (
    tester,
  ) async {
    await pump(tester);
    await choose(tester, 'journal');
    final writes = requests
        .where(
          (r) => r.method == 'POST' && r.url.path.endsWith('/journal_entries'),
        )
        .toList();
    expect(writes, isNotEmpty);
    final body = jsonDecode(writes.last.body) as Map<String, dynamic>;
    expect(body['user_id'], owner);
    expect(body['body'], contains('Live autumn practice'));
    expect(find.text('Added to journal'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  for (final missing in [true, false]) {
    testWidgets(
      '${missing ? 'missing' : 'failed'} source keeps post readable without source edit actions',
      (tester) async {
        sourceMissing = missing;
        sourceFailure = !missing;
        await pump(tester);
        expect(find.text('Published autumn practice'), findsWidgets);
        await tester.tap(
          find.byKey(const ValueKey('user-flow-detail-options')),
        );
        await settle(tester);
        expect(find.text('Remove from profile'), findsOneWidget);
        expect(find.text('Share Flow'), findsOneWidget);
        for (final label in [
          'Edit Flow',
          'Done / Add to journal',
          'Save Flow',
        ]) {
          expect(find.text(label), findsNothing);
        }
        expect(requests.where((r) => r.method != 'GET'), isEmpty);
      },
    );
  }

  testWidgets(
    'visitor never resolves author source or receives source write actions',
    (tester) async {
      await Supabase.instance.client.auth.recoverSession(session(visitor));
      await pump(tester, isOwner: false);
      expect(find.text('Published autumn practice'), findsWidgets);
      expect(find.text('Add to My Flows'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('user-flow-detail-options')));
      await settle(tester);
      for (final label in ['Share Flow', 'Report post', 'Block user']) {
        expect(find.text(label), findsOneWidget);
      }
      for (final label in [
        'Edit Flow',
        'Remove from profile',
        'Save Flow',
        'Done / Add to journal',
      ]) {
        expect(find.text(label), findsNothing);
      }
      expect(
        requests.where(
          (r) =>
              r.url.path.endsWith('/flows') &&
              r.url.queryParameters['id'] == 'eq.177',
        ),
        isEmpty,
      );
    },
  );

  testWidgets(
    'complete warm visitor post refreshes its image from the post repository',
    (tester) async {
      await Supabase.instance.client.auth.recoverSession(session(visitor));
      final stale = FlowPost.fromJson(
        jsonDecode(jsonEncode(post)) as Map<String, dynamic>,
      );
      (post['payload'] as Map<String, dynamic>)['appearance'] = {
        'version': 1,
        'image_object_path': '$owner/new.jpg',
      };
      await tester.pumpWidget(
        MaterialApp(home: FlowPostDetailPage(post: stale, isOwner: false)),
      );
      await settle(tester);
      final hero = tester.widget<UserFlowAppearanceHero>(
        find.byKey(const ValueKey('user-flow-detail-appearance')),
      );
      expect(hero.appearance.imageObjectPath, '$owner/new.jpg');
      expect(requests.any((r) => r.url.path.endsWith('/flow_posts')), true);
    },
  );

  testWidgets(
    'late source result cannot regain write authority after A to B to A',
    (tester) async {
      sourceHold = Completer<void>();
      await pump(tester);
      await Supabase.instance.client.auth.recoverSession(session(visitor));
      await settle(tester);
      await Supabase.instance.client.auth.recoverSession(session(owner));
      sourceHold!.complete();
      await settle(tester);
      expect(find.text('Live autumn practice'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('user-flow-detail-options')));
      await settle(tester);
      expect(find.text('Edit Flow'), findsNothing);
    },
  );

  testWidgets(
    'account departure during journal load never writes into next account',
    (tester) async {
      await pump(tester);
      journalHold = Completer<void>();
      await choose(tester, 'journal');
      await Supabase.instance.client.auth.recoverSession(session(visitor));
      journalHold!.complete();
      await settle(tester);
      expect(
        requests.where(
          (r) => r.method == 'POST' && r.url.path.endsWith('/journal_entries'),
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    },
  );

  for (final entry in [
    ('track-the-sky', 'Follow the Sky'),
    ('offering-table', 'The Offering Table'),
    ('reading-house', 'The Reading House'),
    ('the-djed', 'The Djed'),
    ('the-kar', 'The Kꜣr'),
  ]) {
    testWidgets('posted ${entry.$1} uses the exact owned canonical instance', (
      tester,
    ) async {
      flow['name'] = entry.$2;
      flow['notes'] = 'maat=${entry.$1}';
      await pump(tester, size: const Size(1180, 820));
      switch (entry.$1) {
        case 'track-the-sky':
          final detail = tester.widget<FollowSkyDetailSurface>(
            find.byType(FollowSkyDetailSurface),
          );
          expect(detail.existingFlowId, id);
          expect(detail.isJoined, true);
        case 'offering-table':
          final detail = tester.widget<OfferingTableDetailSurface>(
            find.byType(OfferingTableDetailSurface),
          );
          expect(detail.joinedFlowId, id);
          expect(detail.joinedStartDate, isNotNull);
        case 'reading-house':
          final detail = tester.widget<ReadingHouseDetailSurface>(
            find.byType(ReadingHouseDetailSurface),
          );
          expect(detail.initialFlowId, id);
          expect(detail.initialCalendarId, 'personal-calendar');
          expect(detail.initiallyHeld, true);
        case 'the-djed':
          final detail = tester.widget<DjedDetailSurface>(
            find.byType(DjedDetailSurface),
          );
          expect(detail.flowId, id);
          expect(detail.joined, true);
          expect(detail.canActOnEvents, true);
        case 'the-kar':
          final detail = tester.widget<KarDetailSurface>(
            find.byType(KarDetailSurface),
          );
          expect(detail.joinedFlowId, id);
          expect(detail.joinedStartDate, isNotNull);
      }
      expect(
        find.byKey(const ValueKey('user-flow-detail-options')),
        findsOneWidget,
      );
      expect(find.text('Remove from profile'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      if (entry.$1 == 'the-kar') {
        expect(find.text('Carry this flow'), findsNothing);
      }
      await capture(tester, 'actual-maat-${entry.$1}-1180x820');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    });
  }

  testWidgets('owned archived Ma’at retains event titles and responses', (
    tester,
  ) async {
    flow['name'] = 'Dawn House Rite';
    flow['notes'] = 'maat=dawn-house-rite';
    events[0]['behavior_payload'] = {
      'responses': {'What did you notice?': 'An autumn sunrise'},
    };
    await pump(tester);
    final detail = tester.widget<ArchivedMaatFlowDetailView>(
      find.byType(ArchivedMaatFlowDetailView),
    );
    expect(detail.fixture.events.map((e) => e.title), [
      'Autumn day 1',
      'Autumn day 2',
    ]);
    expect(detail.fixture.responses.single.response, 'An autumn sunrise');
    expect(find.text('This flow is archived'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('user-flow-detail-options')));
    await settle(tester);
    expect(find.text('Edit Flow'), findsNothing);
    expect(find.text('Remove from profile'), findsOneWidget);
  });
}
