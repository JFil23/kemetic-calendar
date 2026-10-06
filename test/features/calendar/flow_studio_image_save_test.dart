import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/flow_appearance_store.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/snapshot/calendar_snapshot_runtime.dart';
import 'package:mobile/features/calendar/presentation/user_flow_appearance_visual.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/pages_resource_test.dart' show session, uid;
import '../../support/maat_flow_visual_test_fonts.dart';

const _captureKey = ValueKey('studio-image-capture');
const _flowId = 99173;
const _oldPath = '$uid/existing-image.jpg';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List imageBytes;
  var insertedEventCount = 0;
  late Map<String, dynamic> flow;
  late List<Map<String, dynamic>> events;
  final mutations = <http.Request>[];
  var uploadStatus = 200;
  var eventStatus = 200;
  var patchStatus = 200;
  var uploads = 0;
  var eventReads = 0;
  int? failingEventOffset;
  Completer<void>? uploadDelay;
  Completer<void>? patchDelay;

  setUpAll(() async {
    // Match the existing external-calendar route fixtures: incidental snapshot
    // writes stay in fake time rather than leaving a native IO queue at teardown.
    await Hive.openBox<String>(
      'calendar_snapshot_store_v1',
      bytes: Uint8List(0),
    );
    await calendarSnapshotStore.initialize();
    SharedPreferences.setMockInitialValues({
      'app:has_seen_onboarding': true,
      'app:onboarding:completed': true,
    });
    imageBytes = File(
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
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/image_picker'),
      (call) async => call.method == 'pickImage'
          ? File(
              'assets/profile/day_cycle_registered_v3_jpg/7am.jpg',
            ).absolute.path
          : null,
    );
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'fixture-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        http.Response reply(Object data, [int status = 200]) => http.Response(
          jsonEncode(data),
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
        if (request.url.path.contains('/storage/v1/object/')) {
          if (request.method == 'POST') {
            uploads++;
            await uploadDelay?.future;
            return uploadStatus == 200
                ? reply({'Key': request.url.path.split('/object/').last})
                : reply({
                    'statusCode': '$uploadStatus',
                    'message': 'fixture image upload failed',
                    'error': 'Upload failed',
                  }, uploadStatus);
          }
          return http.Response.bytes(
            imageBytes,
            200,
            request: request,
            headers: {'content-type': 'image/jpeg'},
          );
        }
        if (request.url.path.endsWith('/flows')) {
          if (request.method == 'PATCH') {
            mutations.add(request);
            await patchDelay?.future;
            if (patchStatus != 200) {
              return reply({
                'code': '57014',
                'message': 'fixture flow save failed',
              }, patchStatus);
            }
            flow.addAll(jsonDecode(request.body) as Map<String, dynamic>);
          }
          final objectResponse =
              request.headers['accept']?.contains('vnd.pgrst.object') ?? false;
          return reply(objectResponse ? flow : [flow]);
        }
        if (request.url.path.endsWith(
          '/rpc/delete_user_events_by_flow_semantic',
        )) {
          mutations.add(request);
          final deleted = events.length;
          events.clear();
          return reply(deleted);
        }
        if (request.url.path.endsWith('/user_events')) {
          if (request.method == 'POST') {
            mutations.add(request);
            final raw = jsonDecode(request.body);
            final rows = raw is List ? raw : [raw];
            final saved = <Map<String, dynamic>>[];
            for (final value in rows) {
              final row = Map<String, dynamic>.from(value as Map);
              final index = events.indexWhere(
                (event) => event['client_event_id'] == row['client_event_id'],
              );
              final record = <String, dynamic>{
                ...row,
                'id': index < 0
                    ? 'inserted-${++insertedEventCount}'
                    : events[index]['id'],
                'filed_flow_id': row['flow_local_id'],
                'item_kind': 'flow',
              };
              if (index < 0) {
                events.add(record);
              } else {
                events[index] = record;
              }
              saved.add(record);
            }
            final objectResponse =
                request.headers['accept']?.contains('vnd.pgrst.object') ??
                false;
            return reply(objectResponse ? saved.single : saved);
          }
          return reply(events);
        }
        if (request.url.path.endsWith('/user_event_filing_items_client')) {
          eventReads++;
          if (eventStatus != 200 ||
              request.url.queryParameters['offset'] == '$failingEventOffset') {
            return reply({
              'code': '57014',
              'message': 'fixture event load failed',
            }, eventStatus == 200 ? 500 : eventStatus);
          }
          final offset = int.parse(
            request.url.queryParameters['offset'] ?? '0',
          );
          final limit = int.parse(
            request.url.queryParameters['limit'] ?? '${events.length}',
          );
          return reply(events.skip(offset).take(limit).toList());
        }
        if (request.method != 'GET' &&
            !request.url.path.contains('/auth/') &&
            !request.url.path.endsWith('/user_app_restoration_snapshots')) {
          mutations.add(request);
        }
        return reply([]);
      }),
    );
    await Supabase.instance.client.auth.recoverSession(session());
    await loadMaatFlowVisualTestFonts();
  });

  setUp(() async {
    await Supabase.instance.client.auth.recoverSession(session());
    WarmSnapshotStore.instance.invalidate(uid);
    FlowAppearanceStore.debugResetImageCacheForTesting();
    FlowAppearanceStore(
      Supabase.instance.client,
    ).rememberImageBytes(_oldPath, imageBytes);
    flow = {
      'id': _flowId,
      'user_id': uid,
      'name': 'Autumn practice',
      'color': 0xD34F22,
      'active': true,
      'is_saved': false,
      'is_hidden': false,
      'start_date': '2026-10-05',
      'end_date': '2026-10-06',
      'notes': '{"kemetic":false,"split":true,"overview":"An autumn practice"}',
      'rules': [],
      'appearance': {
        'version': 1,
        'image_object_path': _oldPath,
        'sign_kind': 'papyrus',
        'sign_label': 'Autumn',
        'accent_argb': 0xFFD34F22,
      },
    };
    events = [
      for (var i = 0; i < 2; i++)
        {
          'id': 'event-$i',
          'user_id': uid,
          'client_event_id': 'original-event-$i',
          'filed_flow_id': _flowId,
          'flow_local_id': _flowId,
          'item_kind': 'flow',
          'title': 'Autumn note ${i + 1}',
          'detail': 'Existing personal note',
          'location': 'Autumn garden',
          'category': 'practice',
          'action_id': 'fixture-action-$i',
          'behavior_payload': {'version': 1, 'opaque': 'keep-$i'},
          'server_extension': {'revision': 17},
          'all_day': false,
          'starts_at': '2026-10-0${5 + i}T16:00:00Z',
          'ends_at': '2026-10-0${5 + i}T17:00:00Z',
        },
    ];
    mutations.clear();
    uploadStatus = eventStatus = patchStatus = 200;
    uploads = eventReads = insertedEventCount = 0;
    uploadDelay = patchDelay = null;
    failingEventOffset = null;
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
    await Hive.close();
  });

  testWidgets('eventful flow restores its image and sign before editing', (
    tester,
  ) async {
    await _open(tester);
    await _showImageRow(tester);
    await _capture(tester, 'existing-image');
    final hero = tester.widget<UserFlowAppearanceHero>(
      find.descendant(
        of: find.byKey(const ValueKey('flow-studio-image-row')),
        matching: find.byType(UserFlowAppearanceHero),
      ),
    );
    expect(hero.appearance.imageObjectPath, _oldPath);
    expect(find.textContaining('Autumn'), findsWidgets);
    expect(mutations, isEmpty);
  });

  testWidgets('selected image stays visible while one save is pending', (
    tester,
  ) async {
    var callbacks = 0;
    uploadDelay = Completer<void>();
    addTearDown(() {
      if (!uploadDelay!.isCompleted) uploadDelay!.complete();
    });
    await _open(
      tester,
      onResult: (_) async {
        callbacks++;
      },
    );
    await _pickImage(tester);
    await _capture(tester, 'selected-image');
    await tester.tap(_headerSave());
    await _drain(tester);
    await _capture(tester, 'saving-image');
    expect(uploads, 1);
    expect(tester.widget<TextButton>(_headerSave()).onPressed, isNull);
    expect(callbacks, 0);
    uploadDelay!.complete();
    await _drain(tester);
    expect(callbacks, 1);
  });

  testWidgets('failed image upload retains selection and permits retry', (
    tester,
  ) async {
    var callbacks = 0;
    uploadStatus = 400;
    await _open(
      tester,
      onResult: (_) async {
        callbacks++;
      },
    );
    await _pickImage(tester);
    await tester.tap(_headerSave());
    await _drain(tester);
    await _capture(tester, 'image-upload-failure');
    expect(callbacks, 0);
    expect(find.textContaining('saved without'), findsNothing);
    expect(
      find.text('Unable to save flow. Your changes are still here. Try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('StorageException'), findsNothing);
    expect(find.text('Remove image'), findsOneWidget);
    expect(tester.widget<TextButton>(_headerSave()).onPressed, isNotNull);
    uploadStatus = 200;
    await tester.tap(_headerSave());
    await _drain(tester);
    expect(uploads, 2);
    expect(callbacks, 1);
  });

  testWidgets('repeated Save taps share one pending acknowledgement', (
    tester,
  ) async {
    var callbacks = 0;
    final acknowledgement = Completer<void>();
    addTearDown(() {
      if (!acknowledgement.isCompleted) acknowledgement.complete();
    });
    await _open(
      tester,
      onResult: (_) async {
        callbacks++;
        await acknowledgement.future;
      },
    );
    await tester.tap(_headerSave());
    await _drain(tester);
    await tester.tap(_headerSave());
    await _drain(tester);
    expect(callbacks, 1);
    acknowledgement.complete();
    await _drain(tester);
  });

  testWidgets(
    'appearance-only route save preserves existing event identities',
    (tester) async {
      final originalEvents = jsonDecode(jsonEncode(events));
      final originalRules = jsonDecode(jsonEncode(flow['rules']));
      await _open(tester, useRoute: true);
      expect(CalendarPage.hasMountedHost, isFalse);
      await _pickImage(tester);
      await tester.tap(_headerSave());
      await _drain(tester);
      final patches = mutations.where(
        (r) => r.url.path.endsWith('/flows') && r.method == 'PATCH',
      );
      expect(patches, hasLength(1));
      expect((flow['appearance'] as Map)['image_object_path'], isNot(_oldPath));
      expect(
        mutations.where((r) => !r.url.path.endsWith('/flows')),
        isEmpty,
        reason: 'Appearance edits must not delete or recreate existing events.',
      );
      expect(flow['rules'], isEmpty);
      expect(events.map((e) => e['id']), ['event-0', 'event-1']);
      expect(
        events,
        originalEvents,
        reason: 'All IDs, client IDs, titles, times, and count stay unchanged.',
      );
      expect(flow['rules'], originalRules);
      expect(find.text('Saved flow'), findsOneWidget);
      final savedPath = (flow['appearance'] as Map)['image_object_path'];
      await _open(tester);
      await _showImageRow(tester);
      final reopenedHero = tester.widget<UserFlowAppearanceHero>(
        find.descendant(
          of: find.byKey(const ValueKey('flow-studio-image-row')),
          matching: find.byType(UserFlowAppearanceHero),
        ),
      );
      expect(reopenedHero.appearance.imageObjectPath, savedPath);
      expect(events, originalEvents);
    },
  );

  for (final mountedCalendar in [false, true]) {
    final owner = mountedCalendar ? 'mounted' : 'headless';
    testWidgets(
      '$owner appearance save preserves raw rules and nullable metadata',
      (tester) async {
        flow.addAll({
          'calendar_id': null,
          'start_date': null,
          'end_date': null,
          'share_id': '71111111-1111-4111-8111-111111111111',
          'origin_share_id': '72222222-2222-4222-8222-222222222222',
          'rules': [
            {
              'type': 'week',
              'weekdays': [2, 1],
              'allDay': false,
              'startHour': 9,
              'startMinute': 0,
              'endHour': 10,
              'endMinute': 0,
              'server_extension': {'revision': 3},
            },
          ],
        });
        final originalFlow = jsonDecode(jsonEncode(flow)) as Map;
        final originalEvents = jsonDecode(jsonEncode(events));
        await _open(tester, useRoute: true, mountedCalendar: mountedCalendar);
        expect(CalendarPage.hasMountedHost, mountedCalendar);
        await _pickImage(tester);
        mutations.clear();
        await tester.tap(_headerSave());
        await _drain(tester);
        expect(
          mutations.where(
            (r) => r.url.path.endsWith('/flows') && r.method == 'PATCH',
          ),
          hasLength(1),
        );
        expect(mutations.where((r) => !r.url.path.endsWith('/flows')), isEmpty);
        expect(
          events,
          originalEvents,
          reason: 'An image edit cannot change any scheduled event field.',
        );
        expect(events, hasLength(2));
        for (final field in [
          'calendar_id',
          'start_date',
          'end_date',
          'rules',
          'notes',
          'share_id',
          'origin_share_id',
        ]) {
          expect(
            flow[field],
            originalFlow[field],
            reason: '$field must remain unchanged.',
          );
        }
        expect(
          (flow['appearance'] as Map)['image_object_path'],
          isNot(_oldPath),
        );
        expect(find.text('Saved flow'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await _drain(tester);
      },
    );

    testWidgets(
      '$owner edited note title and start time still replace scheduled events',
      (tester) async {
        final originalIds = events.map((e) => e['id']).toSet();
        await _open(tester, useRoute: true, mountedCalendar: mountedCalendar);
        expect(CalendarPage.hasMountedHost, mountedCalendar);
        final title = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.controller?.text == 'Autumn note 1',
        );
        await tester.scrollUntilVisible(
          title,
          400,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.enterText(title, 'Changed autumn note');
        final firstStart = find
            .byWidgetPredicate(
              (widget) =>
                  widget is OutlinedButton &&
                  widget.key is ValueKey<String> &&
                  (widget.key! as ValueKey<String>).value.startsWith(
                    'flow-studio-note-start-',
                  ),
            )
            .first;
        await tester.ensureVisible(firstStart);
        await tester.tap(firstStart);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Switch to text input mode'));
        await tester.pumpAndSettle();
        final clockInputs = find.descendant(
          of: find.byType(TimePickerDialog),
          matching: find.byType(TextField),
        );
        await tester.enterText(clockInputs.at(0), '10');
        await tester.enterText(clockInputs.at(1), '30');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        mutations.clear();
        await tester.tap(_headerSave());
        await _drain(tester);
        expect(
          mutations.where(
            (r) =>
                r.url.path.endsWith('/rpc/delete_user_events_by_flow_semantic'),
          ),
          hasLength(1),
        );
        expect(
          mutations.where(
            (r) => r.url.path.endsWith('/user_events') && r.method == 'POST',
          ),
          isNotEmpty,
        );
        expect(events, hasLength(2));
        expect(events.map((e) => e['title']), contains('Changed autumn note'));
        final changed = events.singleWhere(
          (e) => e['title'] == 'Changed autumn note',
        );
        expect(
          DateTime.parse(changed['starts_at'] as String).toLocal(),
          DateTime(2026, 10, 5, 10, 30),
        );
        expect(
          DateTime.parse(
            changed['ends_at'] as String,
          ).isAfter(DateTime.parse(changed['starts_at'] as String)),
          isTrue,
        );
        expect(events.map((e) => e['title']), contains('Autumn note 2'));
        expect(
          events.map((e) => e['id']).toSet().intersection(originalIds),
          isEmpty,
        );
        expect(find.text('Saved flow'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await _drain(tester);
      },
    );
  }

  testWidgets('failed flow acknowledgement retains uploaded image for retry', (
    tester,
  ) async {
    var callbacks = 0;
    var failSave = true;
    await _open(
      tester,
      onResult: (_) async {
        callbacks++;
        if (failSave) throw StateError('fixture flow save failed');
      },
    );
    await _pickImage(tester);
    await tester.tap(_headerSave());
    await _drain(tester);
    expect(callbacks, 1);
    expect(uploads, 1);
    expect(find.text('Remove image'), findsOneWidget);
    expect(find.textContaining('Unable to save flow'), findsOneWidget);
    failSave = false;
    await tester.tap(_headerSave());
    await _drain(tester);
    expect(callbacks, 2);
    expect(uploads, 1, reason: 'Retry must reuse the acknowledged upload.');
  });

  testWidgets('account departure and return during upload cannot save', (
    tester,
  ) async {
    var callbacks = 0;
    uploadDelay = Completer<void>();
    addTearDown(() {
      if (!uploadDelay!.isCompleted) uploadDelay!.complete();
    });
    await _open(
      tester,
      onResult: (_) async {
        callbacks++;
      },
    );
    await _pickImage(tester);
    await tester.tap(_headerSave());
    await _drain(tester);
    expect(uploads, 1);
    final otherSession = session().replaceAll(
      uid,
      'b0000000-0000-0000-0000-000000000002',
    );
    await tester.runAsync(() async {
      await Supabase.instance.client.auth.recoverSession(otherSession);
      await Supabase.instance.client.auth.recoverSession(session());
    });
    uploadDelay!.complete();
    await _drain(tester);
    expect(callbacks, 0);
    expect(mutations, isEmpty);
  });

  testWidgets('dismissal during image upload cannot save a closed editor', (
    tester,
  ) async {
    var callbacks = 0;
    uploadDelay = Completer<void>();
    addTearDown(() {
      if (!uploadDelay!.isCompleted) uploadDelay!.complete();
    });
    await _open(
      tester,
      onResult: (_) async {
        callbacks++;
      },
    );
    await _pickImage(tester);
    await tester.tap(_headerSave());
    await _drain(tester);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    uploadDelay!.complete();
    await _drain(tester);
    expect(callbacks, 0);
    expect(mutations, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failure on a later event page blocks partial-flow saving', (
    tester,
  ) async {
    final first = events.first;
    events = [
      for (var i = 0; i < 500; i++) {...first, 'id': 'page-$i'},
    ];
    failingEventOffset = 500;
    await _open(tester);
    expect(eventReads, 2);
    expect(find.text('Retry'), findsOneWidget);
    expect(_headerSave(), findsNothing);
    expect(mutations, isEmpty);
  });

  testWidgets('failed event load cannot save a partial existing flow', (
    tester,
  ) async {
    eventStatus = 500;
    await _open(tester);
    expect(find.text('Retry'), findsOneWidget);
    expect(_headerSave(), findsNothing);
    expect(mutations, isEmpty);
    eventStatus = 200;
    await tester.tap(find.text('Retry'));
    await _drain(tester);
    expect(_headerSave(), findsOneWidget);
    expect(eventReads, greaterThanOrEqualTo(2));
  });
}

Finder _headerSave() =>
    find.descendant(of: find.byType(AppBar), matching: find.byType(TextButton));

Future<void> _open(
  WidgetTester tester, {
  Future<void> Function(dynamic)? onResult,
  bool useRoute = false,
  bool mountedCalendar = false,
}) async {
  tester.view.physicalSize = const Size(820, 1180);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (useRoute) {
    final calendarHarness = CalendarBoundaryHarnessController(
      expansionLevel: MonthExpansionLevel.details,
      content: CalendarBoundaryHarnessContent.empty,
      instrumentation: CalendarBoundaryInstrumentation.timingOnly,
    );
    final router = GoRouter(
      initialLocation: '/flows/$_flowId/edit',
      routes: [
        ShellRoute(
          builder: (_, _, child) => Stack(
            children: [
              if (mountedCalendar)
                Offstage(
                  child: CalendarPage(
                    calendarBoundaryHarnessController: calendarHarness,
                  ),
                ),
              child,
            ],
          ),
          routes: [
            GoRoute(
              path: '/done',
              builder: (_, _) => const Scaffold(body: Text('Saved flow')),
            ),
            GoRoute(
              path: '/flows/:id/edit',
              builder: (_, _) => CalendarPage.buildFlowEditorRoutePage(
                flowId: _flowId,
                fallbackLocation: '/done',
              ),
            ),
            GoRoute(
              path: '/shared-flow/by-flow/:id',
              builder: (_, _) => const Scaffold(body: Text('Saved flow')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.dark,
        routerConfig: router,
        builder: (_, child) => RepaintBoundary(key: _captureKey, child: child!),
      ),
    );
  } else {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        builder: (_, child) => RepaintBoundary(key: _captureKey, child: child!),
        home: debugBuildFlowStudioPageForTest(
          editFlowId: _flowId,
          onRouteResult: onResult ?? (_) async {},
        ),
      ),
    );
  }
  await _drain(tester);
}

Future<void> _showImageRow(WidgetTester tester) async {
  await tester.ensureVisible(
    find.byKey(const ValueKey('flow-studio-image-row')),
  );
  await tester.pump();
}

Future<void> _pickImage(WidgetTester tester) async {
  await _showImageRow(tester);
  await tester.tap(find.byKey(const ValueKey('flow-studio-image-row')));
  await _drain(tester);
  expect(find.text('Remove image'), findsOneWidget);
}

Future<void> _drain(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['HAW_FLOW_STUDIO_CAPTURE_DIR'];
  if (directory == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
