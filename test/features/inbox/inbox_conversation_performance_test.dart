import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/share_repo.dart';
import 'package:mobile/features/inbox/conversation_user.dart';
import 'package:mobile/features/inbox/inbox_conversation_page.dart';
import 'package:mobile/widgets/kemetic_keyboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/maat_flow_visual_test_fonts.dart';
import '../pages/pages_resource_test.dart' show uid, session;

const friend = '00000000-0000-4000-8000-000000000123';
const capture = ValueKey('chat-performance-capture');

Map<String, dynamic> message(int i, {bool flow = false}) => {
  'share_id': 'share-$i',
  'kind': 'flow',
  'sender_id': uid,
  'recipient_id': friend,
  'payload_id': '$i',
  'created_at': DateTime.utc(2026, 10, 7, 10, i).toIso8601String(),
  'viewed_at': '2026-10-07T20:00:00Z',
  'title': flow ? 'Follow the sky' : 'Earlier message $i',
  'payload_json': flow
      ? {'name': 'Follow the sky', 'notes': 'maat=track-the-sky', 'events': []}
      : {'type': 'message', 'text': 'Earlier message $i'},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var reads = 0;
  final sentBodies = <Map<String, dynamic>>[];
  var unavailable = false;
  Completer<void>? refresh;
  final rows = [
    for (var i = 0; i < 30; i++) message(i),
    message(31, flow: true),
  ];

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'inbox:shares:v1:$uid': jsonEncode(rows),
    });
    for (final channel in ['events', 'messages']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('com.llfbandit.app_links/$channel'),
            (_) async => null,
          );
    }
    await loadMaatFlowVisualTestFonts();
    await Supabase.initialize(
      url: 'https://example.supabase.test',
      anonKey: 'test',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        Object data = [];
        if (request.url.path.endsWith('/send_dm_message')) {
          sentBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          data = {
            'success': true,
            'share': {'id': 'sent-reply'},
            'push': {'delivered': true},
          };
        }
        if (request.url.path.endsWith('/share_filing_items_client') ||
            request.url.path.endsWith('/inbox_share_items_filtered')) {
          reads++;
          await refresh?.future;
          if (unavailable) {
            return http.Response('unavailable', 503, request: request);
          }
          data = rows;
        }
        return http.Response(
          jsonEncode(data),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    await Supabase.instance.client.auth.recoverSession(session());
  });
  tearDownAll(() async => Supabase.instance.dispose());

  Future<void> mount(WidgetTester tester, {String other = friend}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        debugShowCheckedModeBanner: false,
        builder: (_, child) => RepaintBoundary(
          key: capture,
          child: KemeticKeyboardHost(child: child!),
        ),
        home: InboxConversationPage(
          otherUserId: other,
          otherProfile: ConversationUser(
            id: other,
            displayName: 'October/potato',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> record(WidgetTester tester, String name) async {
    final folder = Platform.environment['HAW_FLOW_PREVIEW_CAPTURE_DIR'];
    if (folder == null) return;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(capture),
      );
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(folder).create(recursive: true);
      await File('$folder/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  tearDown(() async {
    refresh?.complete();
    refresh = null;
    unavailable = false;
    await Supabase.instance.client.removeAllChannels();
  });

  testWidgets(
    'warm flows paint before refresh and keyboard changes never restart reads',
    (tester) async {
      refresh = Completer<void>();
      await ShareRepo(Supabase.instance.client).restoreCachedInboxItems();
      await mount(tester);
      final coldReads = reads;
      expect(coldReads, 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Follow the sky'), findsOneWidget);
      await record(tester, 'warm-flow-chat');
      final list = tester.widget<ListView>(find.byType(ListView).first);
      expect(list.controller!.position.extentAfter, lessThan(1));
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'this is ');
      for (final inset in [180.0, 320.0, 290.0, 320.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: inset);
        await tester.pumpAndSettle();
        expect(list.controller!.position.extentAfter, lessThan(1));
      }
      await tester.tap(find.byKey(const ValueKey('kemetic-toggle-hit-target')));
      await tester.pumpAndSettle();
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('kemetic-keyboard-panel')),
        findsOneWidget,
      );
      expect(list.controller!.position.extentAfter, lessThan(1));
      await record(tester, 'warm-flow-kemetic-keyboard');
      await tester.tap(find.byKey(const ValueKey('kemetic-action-left')));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'this is ',
      );
      expect(
        reads,
        coldReads,
        reason:
            'Typing, selection and keyboard layout must reuse the mounted stream.',
      );
      await tester.tap(find.text('ABC'));
      await tester.pumpAndSettle();
      // Resizing must also respect someone who scrolled into older messages.
      list.controller!.jumpTo(list.controller!.position.maxScrollExtent - 250);
      await tester.pumpAndSettle();
      final readingPosition = list.controller!.offset;
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      await tester.pumpAndSettle();
      expect(list.controller!.offset, closeTo(readingPosition, 1));
      list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
      await tester.pumpAndSettle();
      // A failed refresh cannot remove the already restored preview.
      unavailable = true;
      refresh!.complete();
      refresh = null;
      await tester.pumpAndSettle();
      expect(find.text('Follow the sky'), findsOneWidget);
      expect(find.text('Conversation temporarily unavailable'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      tester.view.reset();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        await Supabase.instance.client.removeAllChannels();
        await Supabase.instance.client.realtime.disconnect();
        Supabase.instance.client.realtime.reconnectTimer.reset();
      });
      await tester.pumpAndSettle();
    },
  );

  testWidgets('new chat stays editable while inbox hydration is delayed', (
    tester,
  ) async {
    refresh = Completer<void>();
    final before = reads;
    await mount(tester, other: '00000000-0000-4000-8000-000000000456');
    expect(find.text('No messages yet'), findsOneWidget);
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Welcome');
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kemetic-toggle-hit-target')));
    await tester.pumpAndSettle();
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('kemetic-keyboard-panel')),
      findsOneWidget,
    );
    expect(reads - before, 1);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Welcome',
    );
    await record(tester, 'new-chat-kemetic-keyboard');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    refresh!.complete();
    refresh = null;
    tester.view.reset();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await Supabase.instance.client.removeAllChannels();
      await Supabase.instance.client.realtime.disconnect();
      Supabase.instance.client.realtime.reconnectTimer.reset();
    });
    await tester.pumpAndSettle();
  });
  testWidgets('a held Send tap keeps its target until pointer up', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'One deliberate tap');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kemetic-toggle-hit-target')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('kemetic-keyboard-panel')),
      findsOneWidget,
    );
    final before = sentBodies.length;
    final send = find.byType(ElevatedButton);
    final rect = tester.getRect(send);
    final touch = await tester.startGesture(rect.center);
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      tester.getRect(send),
      rect,
      reason: 'Dismissal must not move controls beneath an active finger.',
    );
    expect(
      find.byKey(const ValueKey('kemetic-keyboard-panel')),
      findsOneWidget,
    );
    await touch.up();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(find.text('One deliberate tap'), findsOneWidget);
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(sentBodies.length, before + 1);
    expect(find.text('One deliberate tap'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.reset();
    await tester.runAsync(() async {
      await Supabase.instance.client.removeAllChannels();
      await Supabase.instance.client.realtime.disconnect();
      Supabase.instance.client.realtime.reconnectTimer.reset();
    });
    await tester.pumpAndSettle();
  });

  testWidgets(
    'real Inbox menu replies with source identity and retains keyboard input',
    (tester) async {
      await mount(tester);
      await tester.longPress(find.text('Follow the sky'));
      await tester.pumpAndSettle();
      expect(find.text('Delete for me'), findsOneWidget);
      expect(find.text('Unsend'), findsOneWidget);
      await tester.tap(find.text('Reply'));
      await tester.pumpAndSettle();
      expect(find.text('Replying to'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Thank you for this flow');
      expect(
        tester
            .getRect(find.byKey(const ValueKey('kemetic-toggle-hit-target')))
            .overlaps(tester.getRect(find.byType(ElevatedButton))),
        isFalse,
      );
      await record(tester, 'reply-composer-toggle-clearance');
      await tester.tap(find.byIcon(Icons.send));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(sentBodies.last['replyToId'], 'share-31');
      expect(sentBodies.last['replyToKind'], 'flow');
      expect(sentBodies.last['text'], 'Thank you for this flow');
      expect(find.text('Thank you for this flow'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      tester.view.reset();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        await Supabase.instance.client.removeAllChannels();
        await Supabase.instance.client.realtime.disconnect();
        Supabase.instance.client.realtime.reconnectTimer.reset();
      });
      await tester.pumpAndSettle();
      reads = 0;
    },
  );
}
