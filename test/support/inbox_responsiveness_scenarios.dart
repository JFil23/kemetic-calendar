import 'maat_flow_visual_test_fonts.dart';
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
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import 'package:mobile/features/inbox/inbox_dm_conversation_page.dart';
import 'package:mobile/features/inbox/presentation/inbox_message_actions.dart';
import 'package:mobile/features/profile/profile_search_page.dart';
import 'package:mobile/widgets/kemetic_keyboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _uid = '27d63169-a28a-4550-a0a0-8fee0e8e7b95';
const _other = '00000000-0000-4000-8000-000000000123';
const _group = '00000000-0000-4000-8000-000000000456';
String _session(String uid) {
  final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  String enc(Object x) =>
      base64Url.encode(utf8.encode(jsonEncode(x))).replaceAll('=', '');
  return jsonEncode({
    'access_token':
        '${enc({'alg': 'HS256', 'typ': 'JWT'})}.${enc({'sub': uid, 'exp': exp})}.signature',
    'refresh_token': 'fixture',
    'token_type': 'bearer',
    'expires_at': exp,
    'expires_in': 3600,
    'user': {
      'id': uid,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'fixture@example.com',
      'app_metadata': {},
      'user_metadata': {},
      'created_at': '2026-01-01T00:00:00Z',
    },
  });
}

/// The same real-widget/network-delay scenarios run under widget and iOS bindings.
/// All sends use the injected HTTP fixture, never a live account or service.
void inboxResponsivenessScenarios() {
  final store = WarmSnapshotStore.instance;
  final sent = <Map<String, dynamic>>[];
  final gates = <Completer<void>>[];
  final searches = <String, Completer<void>>{};
  var messages = <Map<String, dynamic>>[];
  Completer<void>? reads, sends, marks, actions;
  var failSend = false, failAction = false, failRead = false;
  var messageReads = 0;
  Completer<void> gate() {
    final c = Completer<void>();
    gates.add(c);
    return c;
  }

  final summary = {
    'conversation_id': _group,
    'type': 'group',
    'title': 'Friends',
    'created_by': _uid,
    'created_at': '2026-10-07T20:00:00Z',
    'updated_at': '2026-10-07T20:00:00Z',
    'members': [],
    'unread_count': 1,
  };

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadMaatFlowVisualTestFonts();
    for (final channel in ['events', 'messages']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('com.llfbandit.app_links/$channel'),
            (_) async => null,
          );
    }
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'inbox-responsiveness-fixture',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        Object? result = [];
        var status = 200;
        final path = request.url.path;
        if (path.endsWith('/dm_conversation_summaries')) result = [summary];
        if (path.endsWith('/dm_conversation_messages_client')) {
          messageReads++;
          await reads?.future;
          result = messages;
          if (failRead) {
            status = 503;
            result = {'message': 'Unavailable'};
          }
        }
        if (path.endsWith('/mark_dm_conversation_read')) {
          await marks?.future;
          result = {'success': true};
        }
        if (path.endsWith('/send_dm_message_v2')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          sent.add(body);
          await sends?.future;
          if (failSend) {
            status = 503;
            result = {'error': 'Unavailable'};
          } else {
            final message = <String, dynamic>{
              'id': 'server-${body['clientMessageId']}',
              'conversation_id': _group,
              'sender_id': _uid,
              'body': body['text'],
              'kind': 'text',
              'client_message_id': body['clientMessageId'],
              'created_at': DateTime.now().toUtc().toIso8601String(),
              if (body['replyToId'] != null)
                'payload_json': {
                  'reply_to': {'text': 'An earlier message'},
                },
            };
            messages = [
              ...messages.where((m) => m['id'] != message['id']),
              message,
            ];
            result = {'success': true, 'message': message};
          }
        }
        if (path.endsWith('/inbox_message_action')) {
          await actions?.future;
          if (failAction) {
            status = 403;
            result = {'code': '42501', 'message': 'Denied'};
          } else {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            messages.removeWhere((m) => m['id'] == body['p_id']);
            result = true;
          }
        }
        if (path.endsWith('/profiles')) {
          final query =
              (request.url.queryParameters['handle'] ??
                      request.url.queryParameters['display_name'] ??
                      '')
                  .replaceAll('ilike.', '')
                  .replaceAll('%', '');
          await searches[query]?.future;
          result = [
            {'id': _other, 'handle': query, 'display_name': '$query Person'},
          ];
        }
        return http.Response(
          jsonEncode(result),
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  setUp(() async {
    reads = null;
    sends = null;
    marks = null;
    actions = null;
    failSend = false;
    failAction = false;
    failRead = false;
    sent.clear();
    searches.clear();
    messageReads = 0;
    await Supabase.instance.client.auth.recoverSession(_session(_uid));
    store.invalidate(_uid);
    messages = [
      {
        'id': 'earlier',
        'conversation_id': _group,
        'sender_id': _other,
        'body': 'An earlier message',
        'kind': 'text',
        'created_at': '2026-10-07T20:00:00Z',
        'sender_display_name': 'Friend',
      },
    ];
    await store.refresh(
      _uid,
      'dm.messages.$_group',
      () async => messages,
      isCurrent: () => true,
    );
    await store.refresh(
      _uid,
      'dm.summaries',
      () async => [summary],
      isCurrent: () => true,
    );
  });
  tearDown(() async {
    for (final c in gates) {
      if (!c.isCompleted) c.complete();
    }
    gates.clear();
    await Supabase.instance.client.removeAllChannels();
    await Supabase.instance.client.realtime.disconnect();
    Supabase.instance.client.realtime.reconnectTimer.reset();
  });
  tearDownAll(() async => Supabase.instance.dispose());

  Future<void> drain(WidgetTester tester) async {
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump();
  }

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        builder: (_, child) => RepaintBoundary(
          key: const ValueKey('response-capture'),
          child: KemeticKeyboardHost(child: child!),
        ),
        home: const InboxDmConversationPage(conversationId: _group),
      ),
    );
    await tester.pump();
  }

  Future<void> record(WidgetTester tester, String name) async {
    final folder = Platform.environment['HAW_RESPONSE_CAPTURE_DIR'];
    if (folder == null) return;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('response-capture')),
      );
      final shot = await boundary.toImage();
      final data = await shot.toByteData(format: ui.ImageByteFormat.png);
      await File('$folder/$name.png').writeAsBytes(data!.buffer.asUint8List());
      shot.dispose();
    });
  }

  Future<void> disposePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    for (final c in gates) {
      if (!c.isCompleted) c.complete();
    }
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await Supabase.instance.client.removeAllChannels();
      await Supabase.instance.client.realtime.disconnect();
      Supabase.instance.client.realtime.reconnectTimer.reset();
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
    'warm group paints immediately and remains usable through slow failed refresh',
    (tester) async {
      reads = gate();
      marks = gate();
      await mount(tester);
      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('An earlier message'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.enterText(find.byType(TextField), 'Draft stays editable');
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('An earlier message'), findsOneWidget);
      expect(messageReads, lessThanOrEqualTo(1));
      failRead = true;
      reads!.complete();
      reads = null;
      await drain(tester);
      expect(find.text('An earlier message'), findsOneWidget);
      expect(find.text('Conversation temporarily unavailable'), findsNothing);
      expect(find.text('Friends'), findsOneWidget);
      await disposePage(tester);
    },
  );

  testWidgets(
    'group Send paints before acknowledgement and retry retains later draft and id',
    (tester) async {
      if (tester.binding is AutomatedTestWidgetsFlutterBinding) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(844, 390);
        tester.view.padding = const FakeViewPadding(bottom: 21);
        addTearDown(tester.view.reset);
      }
      reads = gate();
      marks = gate();
      sends = gate();
      await mount(tester);
      if (tester.binding is AutomatedTestWidgetsFlutterBinding) {
        tester.view.viewInsets = const FakeViewPadding(bottom: 209);
      }
      await tester.enterText(find.byType(TextField), 'First reply');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('kemetic-toggle-hit-target')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('kemetic-keyboard-panel')),
        findsOneWidget,
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'Native/custom keyboard handoff reserves occlusion once.',
      );
      if (tester.binding is AutomatedTestWidgetsFlutterBinding) {
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pumpAndSettle();
      }
      await record(tester, 'group-keyboard-landscape');
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(find.byType(ElevatedButton));
      final touch = await tester.startGesture(rect.center);
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.getRect(find.byType(ElevatedButton)), rect);
      await touch.up();
      await tester.pumpAndSettle();
      expect(find.text('First reply'), findsOneWidget);
      expect(find.text('Sending…'), findsOneWidget);
      expect(store.peek(_uid, 'dm.messages.$_group'), isNotNull);
      expect(
        jsonEncode(store.peek(_uid, 'dm.messages.$_group')!.data),
        isNot(contains('First reply')),
        reason: 'Pending writes never enter the disposable warm cache.',
      );
      await record(tester, 'group-sending');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
      // Reopen the native input connection before injecting the next draft.
      // Otherwise a late iOS focus event can overwrite test-injected text.
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'My next draft');
      await drain(tester);
      expect(sent, hasLength(1));
      final clientId = sent.single['clientMessageId'];
      failSend = true;
      sends!.complete();
      sends = null;
      await drain(tester);
      await tester.pumpAndSettle();
      expect(find.text('Not sent'), findsOneWidget);
      expect(store.peek(_uid, 'dm.messages.$_group'), isNotNull);
      await record(tester, 'group-failed');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'My next draft',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('First reply'));
      await tester.longPress(find.text('First reply'));
      await tester.pumpAndSettle();
      failSend = false;
      await tester.tap(find.text('Retry'));
      await drain(tester);
      await tester.pumpAndSettle();
      expect(sent, hasLength(2));
      expect(sent.last['clientMessageId'], clientId);
      expect(find.text('Not sent'), findsNothing);
      expect(find.text('First reply'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'My next draft',
      );
      reads!.complete();
      reads = null;
      await drain(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('First reply'),
        findsOneWidget,
        reason: 'Acknowledged and streamed copies deduplicate.',
      );
      await disposePage(tester);
    },
  );

  testWidgets('Back responds while the read acknowledgement is held', (
    tester,
  ) async {
    marks = gate();
    reads = gate();
    final router = GoRouter(
      initialLocation: '/inbox',
      routes: [
        GoRoute(
          path: '/inbox',
          builder: (_, _) => const Scaffold(body: Text('Inbox home')),
        ),
        GoRoute(
          path: '/chat',
          builder: (_, _) =>
              const InboxDmConversationPage(conversationId: _group),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/chat');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Inbox home'), findsOneWidget);
    expect(marks!.isCompleted, isFalse);
    await disposePage(tester);
    router.dispose();
  });

  testWidgets(
    'Delete responds immediately and rolls back a rejected account write',
    (tester) async {
      actions = gate();
      reads = gate();
      marks = gate();
      await mount(tester);
      await tester.pumpAndSettle();
      await tester.longPress(find.text('An earlier message'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete for me'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete for me'));
      await tester.pumpAndSettle();
      expect(find.text('An earlier message'), findsNothing);
      expect(store.peek(_uid, 'dm.messages.$_group'), isNotNull);
      failAction = true;
      actions!.complete();
      actions = null;
      await drain(tester);
      await tester.pumpAndSettle();
      expect(find.text('An earlier message'), findsOneWidget);
      expect(store.peek(_uid, 'dm.messages.$_group'), isNotNull);
      expect(
        find.text('Could not complete this action. Please try again.'),
        findsOneWidget,
      );
      await disposePage(tester);
    },
  );

  testWidgets(
    'account change rejects a late send and clears the private view',
    (tester) async {
      reads = gate();
      marks = gate();
      sends = gate();
      await mount(tester);
      await tester.enterText(find.byType(TextField), 'Private draft');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send));
      await drain(tester);
      expect(sent, hasLength(1));
      await Supabase.instance.client.auth.recoverSession(_session(_other));
      await tester.pump();
      expect(find.text('Private draft'), findsNothing);
      expect(find.text('An earlier message'), findsNothing);
      sends!.complete();
      sends = null;
      await drain(tester);
      expect(find.text('Private draft'), findsNothing);
      await disposePage(tester);
    },
  );

  testWidgets(
    'search keeps tappable results and ignores a superseded response',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileSearchPage(selectionMode: 'conversation'),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Al');
      await tester.pump(const Duration(milliseconds: 310));
      await drain(tester);
      await drain(tester);
      expect(find.text('Al Person'), findsOneWidget);
      searches['Alb'] = gate();
      await tester.enterText(find.byType(TextField), 'Alb');
      await tester.pump(const Duration(milliseconds: 310));
      await drain(tester);
      expect(find.text('Al Person'), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 450));
      await tester.ensureVisible(find.text('Al Person'));
      await tester.tap(find.text('Al Person'));
      await tester.pump();
      expect(find.text('Start'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'Al Person'), findsOneWidget);
      await tester.tap(find.byType(TextField));
      await tester.pump(const Duration(milliseconds: 450));
      await tester.enterText(find.byType(TextField), 'Be');
      await tester.pump(const Duration(milliseconds: 310));
      await drain(tester);
      await drain(tester);
      await tester.scrollUntilVisible(
        find.text('Be Person'),
        80,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Be Person'), findsOneWidget);
      searches['Alb']!.complete();
      await drain(tester);
      await drain(tester);
      expect(find.text('Alb Person'), findsNothing);
      expect(find.text('Be Person'), findsOneWidget);
      await disposePage(tester);
    },
  );

  testWidgets('the entire message target recognizes one ordinary tap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: InboxMessageActions(
              createdAt: DateTime(2026),
              onTap: () => taps++,
              child: const SizedBox(
                width: 220,
                height: 100,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text('Flow title'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final rect = tester.getRect(find.byType(InboxMessageActions));
    final touch = await tester.startGesture(
      rect.bottomRight - const Offset(8, 8),
    );
    await tester.pump(const Duration(milliseconds: 60));
    await touch.up();
    expect(
      taps,
      1,
      reason: 'The preview hit target includes empty artwork/padding.',
    );
    await disposePage(tester);
  });
}
