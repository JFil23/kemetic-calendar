import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/flows_repo.dart';
import 'package:mobile/features/profile/flow_post_picker_page.dart';
import 'package:mobile/widgets/kemetic_keyboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/pages_resource_test.dart' show session, uid;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var filedStatus = 200;
  var filedReads = 0;
  var sourceStatus = 200;
  var eventStatus = 200;
  var eventReads = 0;
  Completer<void>? filedDelay;
  final writes = <Map<String, dynamic>>[];
  final source = <String, dynamic>{
    'id': 99123,
    'user_id': uid,
    'name': 'New iPad practice',
    'color': 0x6f93a8,
    'active': true,
    'is_saved': false,
    'is_hidden': false,
    'start_date': '2026-10-05',
    'end_date': '2026-10-06',
    'notes': 'mode=gregorian',
    'rules': [],
    'visible_in_active_list': true,
    'remaining_live_event_count': 2,
    'total_event_count': 2,
  };

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
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
        http.Response reply(Object data, [int status = 200]) => http.Response(
          jsonEncode(data),
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
        if (request.url.path.endsWith('/rpc/get_my_filed_flows_v1')) {
          filedReads++;
          await filedDelay?.future;
          return filedStatus == 200
              ? reply([source])
              : reply({
                  'code': '57014',
                  'message': 'fixture filing read timed out',
                }, filedStatus);
        }
        if (request.url.path.endsWith('/rpc/get_my_held_reading_houses_v1')) {
          return reply([]);
        }
        if (request.url.path.endsWith('/user_event_filing_items_client')) {
          eventReads++;
          return eventStatus == 200
              ? reply([])
              : reply({
                  'code': '57014',
                  'message': 'fixture event read timed out',
                }, eventStatus);
        }
        if (request.url.path.endsWith('/flows')) {
          return sourceStatus == 200
              ? reply(source)
              : reply({
                  'code': '57014',
                  'message': 'fixture source read timed out',
                }, sourceStatus);
        }
        if (request.url.path.endsWith('/flow_posts') &&
            request.method == 'POST') {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          writes.add(payload);
          return reply({
            ...payload,
            'id': 'picker-post',
            'created_at': '2026-10-05T16:00:00Z',
          }, 201);
        }
        return reply([]);
      }),
    );
    await Supabase.instance.client.auth.recoverSession(session());
  });

  setUp(() async {
    await Supabase.instance.client.auth.recoverSession(session());
    filedStatus = 200;
    filedReads = 0;
    sourceStatus = 200;
    eventStatus = 200;
    eventReads = 0;
    filedDelay = null;
    writes.clear();
    await FlowsRepo(Supabase.instance.client).clearMyFiledFlowsCache();
  });
  tearDownAll(() => Supabase.instance.dispose());

  testWidgets(
    'new owned flow can be selected and posted through the iPad picker',
    (tester) async {
      await _openPicker(tester);
      expect(
        filedReads,
        1,
        reason: 'The canonical viewer owns initial loading.',
      );
      await tester.tap(find.text('New iPad practice'));
      await _drain(tester);
      await tester.enterText(
        find.byKey(const ValueKey('flow-post-caption-field')),
        'From my iPad',
      );
      final submit = find.byKey(const ValueKey('flow-post-caption-submit'));
      await tester.ensureVisible(submit);
      await tester.pump();
      await tester.tap(submit);
      await _drain(tester);
      expect(tester.takeException(), isNull);
      expect(writes, hasLength(1));
      expect(
        (writes.single['ai_metadata'] as Map)['shared_note'],
        'From my iPad',
      );
      expect(find.byType(FlowPostPickerPage), findsNothing);
    },
  );

  testWidgets('picker remains usable after source flow lookup fails', (
    tester,
  ) async {
    await _openPicker(tester);
    await tester.tap(find.text('New iPad practice'));
    await _drain(tester);
    sourceStatus = 400;
    final submit = find.byKey(const ValueKey('flow-post-caption-submit'));
    await tester.ensureVisible(submit);
    await tester.pump();
    await tester.tap(submit);
    await _drain(tester);
    expect(tester.takeException(), isNull);
    expect(writes, isEmpty);
    expect(find.byType(FlowPostPickerPage), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Could not post this flow.'), findsOneWidget);
  });

  testWidgets('cached picker opens caption during a slow filing refresh', (
    tester,
  ) async {
    await FlowsRepo(Supabase.instance.client).refreshMyFiledFlows();
    filedDelay = Completer<void>();
    await _openPicker(tester);
    expect(find.text('New iPad practice'), findsOneWidget);
    await tester.tap(find.text('New iPad practice'));
    await _drain(tester);
    expect(
      find.byKey(const ValueKey('flow-post-caption-field')),
      findsOneWidget,
    );
    expect(eventReads, 0, reason: 'Caption preview does not fetch event rows.');
    expect(writes, isEmpty);
    filedDelay!.complete();
    await _drain(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'caption selection does not depend on a failed event preview read',
    (tester) async {
      eventStatus = 500;
      await _openPicker(tester);
      await tester.tap(find.text('New iPad practice'));
      await _drain(tester);
      expect(
        find.byKey(const ValueKey('flow-post-caption-field')),
        findsOneWidget,
      );
      expect(eventReads, 0);
      expect(writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'warm picker retains selection after a failed background refresh',
    (tester) async {
      await FlowsRepo(Supabase.instance.client).refreshMyFiledFlows();
      filedStatus = 400;
      await _openPicker(tester);
      expect(find.text('New iPad practice'), findsOneWidget);
      await tester.tap(find.text('New iPad practice'));
      await _drain(tester);
      expect(
        find.byKey(const ValueKey('flow-post-caption-field')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      expect(writes, isEmpty);
    },
  );

  testWidgets('selection cache miss reports a read failure and can retry', (
    tester,
  ) async {
    await _openPicker(tester);
    await FlowsRepo(Supabase.instance.client).clearMyFiledFlowsCache();
    filedStatus = 400;
    await tester.tap(find.text('New iPad practice'));
    await _drain(tester);
    expect(tester.takeException(), isNull);
    expect(
      find.text('Could not load this flow. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Only flows you own can be posted.'), findsNothing);
    expect(find.byKey(const ValueKey('flow-post-caption-field')), findsNothing);
    expect(writes, isEmpty);
    filedStatus = 200;
    await tester.tap(find.text('New iPad practice'));
    await _drain(tester);
    expect(
      find.byKey(const ValueKey('flow-post-caption-field')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final returnToOwner in [false, true]) {
    testWidgets(
      'account departure rejects pending selection (return: $returnToOwner)',
      (tester) async {
        await _openPicker(tester);
        await FlowsRepo(Supabase.instance.client).clearMyFiledFlowsCache();
        filedDelay = Completer<void>();
        await tester.tap(find.text('New iPad practice'));
        await _drain(tester);
        await _changeAccount(tester, returnToOwner: returnToOwner);
        filedDelay!.complete();
        await _drain(tester);
        expect(
          find.byKey(const ValueKey('flow-post-caption-field')),
          findsNothing,
        );
        expect(writes, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'account departure rejects caption submit (return: $returnToOwner)',
      (tester) async {
        await _openPicker(tester);
        await tester.tap(find.text('New iPad practice'));
        await _drain(tester);
        await _changeAccount(tester, returnToOwner: returnToOwner);
        final submit = find.byKey(const ValueKey('flow-post-caption-submit'));
        await tester.ensureVisible(submit);
        await tester.pump();
        await tester.tap(submit);
        await _drain(tester);
        expect(writes, isEmpty);
        expect(find.byType(FlowPostPickerPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'failed picker filing read stays in its retry UI without an unhandled error',
    (tester) async {
      filedStatus = 400;
      await _openPicker(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Unable to load flows'), findsOneWidget);
      expect(find.byTooltip('Retry'), findsOneWidget);
      expect(writes, isEmpty);
      filedStatus = 200;
      await tester.tap(find.byTooltip('Retry'));
      await _drain(tester);
      expect(find.text('New iPad practice'), findsOneWidget);
      expect(filedReads, 2);
      await tester.tap(find.text('New iPad practice'));
      await _drain(tester);
      final submit = find.byKey(const ValueKey('flow-post-caption-submit'));
      await tester.ensureVisible(submit);
      await tester.pump();
      await tester.tap(submit);
      await _drain(tester);
      expect(writes, hasLength(1));
      expect(find.byType(FlowPostPickerPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _changeAccount(
  WidgetTester tester, {
  required bool returnToOwner,
}) async {
  await tester.runAsync(
    () => Supabase.instance.client.auth.recoverSession(
      _sessionFor('3902ecdc-8105-4527-8c9d-ea2b206806c4'),
    ),
  );
  await _drain(tester);
  if (returnToOwner) {
    await tester.runAsync(
      () => Supabase.instance.client.auth.recoverSession(session()),
    );
    await _drain(tester);
  }
}

String _sessionFor(String accountId) {
  final value = jsonDecode(session()) as Map<String, dynamic>;
  (value['user'] as Map<String, dynamic>)['id'] = accountId;
  final pieces = (value['access_token'] as String).split('.');
  final claims =
      jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(pieces[1]))))
          as Map<String, dynamic>;
  claims['sub'] = accountId;
  pieces[1] = base64Url
      .encode(utf8.encode(jsonEncode(claims)))
      .replaceAll('=', '');
  value['access_token'] = pieces.join('.');
  return jsonEncode(value);
}

Future<void> _openPicker(WidgetTester tester) async {
  tester.view.physicalSize = const Size(820, 1180);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => context.push('/profile/flow-post-picker'),
              child: const Text('Open picker'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/profile/flow-post-picker',
        builder: (_, _) => const FlowPostPickerPage(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.dark,
      builder: (_, child) => KemeticKeyboardHost(child: child!),
    ),
  );
  await tester.tap(find.text('Open picker'));
  await _drain(tester);
}

Future<void> _drain(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}
