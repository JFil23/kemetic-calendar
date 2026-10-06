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
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/flow_appearance_store.dart';
import 'package:mobile/data/share_models.dart';
import 'package:mobile/features/inbox/conversation_user.dart';
import 'package:mobile/features/inbox/inbox_conversation_page.dart';
import 'package:mobile/features/inbox/inbox_page.dart';
import 'package:mobile/features/inbox/presentation/flow_message_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/maat_flow_visual_test_fonts.dart';
import '../pages/pages_resource_test.dart' show uid, session;

const _friend = 'ac000000-0000-4000-8000-000000000001';
const _capture = ValueKey('inbox-route-capture');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var offline = false;
  var reads = 0;
  final rows = [_share('no-image', false), _share('image', true)];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.app_links/events'),
          (_) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.app_links/messages'),
          (_) async => null,
        );
    await loadMaatFlowVisualTestFonts();
    await Supabase.initialize(
      url: 'https://example.supabase.test',
      anonKey: 'test',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        Object body = [];
        if (request.url.path.endsWith('/share_filing_items_client') ||
            request.url.path.endsWith('/inbox_share_items_filtered')) {
          reads++;
          if (offline) {
            return http.Response('Unavailable', 503, request: request);
          }
          body = rows;
        }
        return http.Response(
          jsonEncode(body),
          200,
          headers: {
            'content-type': 'application/json',
            'content-range': '0-1/2',
          },
          request: request,
        );
      }),
    );
    await Supabase.instance.client.auth.recoverSession(session());
    final data = await rootBundle.load(
      'assets/the_reading_house/reference_hero.jpg',
    );
    FlowAppearanceStore.debugDownloadImageForTesting = (_, path) async =>
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  });
  tearDownAll(() async {
    FlowAppearanceStore.debugResetImageCacheForTesting();
    await Supabase.instance.dispose();
  });

  testWidgets(
    'Inbox row opens real conversation with sent and received flow previews; warm reopen keeps both',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/inbox',
        routes: [
          GoRoute(
            path: '/inbox',
            builder: (_, _) => InboxPage(
              inboxItemsStreamForTesting: Stream.value(
                rows.map(InboxShareItem.fromJson).toList(),
              ),
              disableAuxiliarySubscriptionsForTesting: true,
            ),
          ),
          GoRoute(
            path: '/inbox/conversation/:userId',
            builder: (_, state) => InboxConversationPage(
              otherUserId: state.pathParameters['userId']!,
              otherProfile: ConversationUser(
                id: _friend,
                displayName: 'Alton Chislom',
              ),
            ),
          ),
          GoRoute(
            path: '/shared-flow/:shareId',
            builder: (_, state) => Scaffold(
              body: Text('Opened ${state.pathParameters['shareId']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          routerConfig: router,
          builder: (_, child) => RepaintBoundary(key: _capture, child: child!),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alton Chislom').first);
      await tester.pumpAndSettle();
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<InboxConversationPage>(find.byType(InboxConversationPage))
            .otherUserId,
        _friend,
      );
      expect(reads, greaterThan(0));
      expect(find.byType(FlowMessagePreview), findsNWidgets(2));
      expect(find.text('Follow the sky'), findsOneWidget);
      expect(find.text('The Reading House'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('user-flow-appearance-fallback-layer')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('user-flow-appearance-image-layer')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('flow-message-built-in-hero')),
        findsOneWidget,
      );
      expect(find.text('Flow'), findsNothing);
      expect(tester.takeException(), isNull);
      final folder = Platform.environment['HAW_FLOW_PREVIEW_CAPTURE_DIR'];
      if (folder != null) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(_capture),
          );
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(folder).create(recursive: true);
          await File(
            '$folder/inbox-conversation.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.text('Follow the sky'));
      await tester.pumpAndSettle();
      expect(find.text('Opened no-image'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();
      final coldReads = reads;
      offline = true;
      await tester.tap(find.text('Alton Chislom').first);
      await tester.pumpAndSettle();
      expect(find.byType(FlowMessagePreview), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      expect(reads, greaterThan(coldReads));
      await tester.pumpWidget(const SizedBox());
      await Supabase.instance.client.removeAllChannels();
      await Supabase.instance.client.realtime.disconnect();
      await tester.pumpAndSettle();
    },
  );
}

Map<String, dynamic> _share(String id, bool image) => {
  'share_id': id,
  'kind': 'flow',
  'sender_id': image ? _friend : uid,
  'recipient_id': image ? uid : _friend,
  'sender_name': image ? 'Alton Chislom' : 'You',
  'recipient_display_name': image ? 'You' : 'Alton Chislom',
  'payload_id': id,
  'title': image ? 'The Reading House' : 'Follow the sky',
  'created_at': image ? '2026-10-06T23:21:00Z' : '2026-10-06T23:20:00Z',
  'viewed_at': '2026-10-06T23:22:00Z',
  'payload_json': {
    'name': image ? 'The Reading House' : 'Follow the sky',
    'color': 0xFFA4B1FF,
    if (!image) 'notes': 'maat=track-the-sky',
    'appearance': {
      'version': 1,
      if (image) 'image_object_path': 'fixture/reading-house.jpg',
    },
    'events': [],
  },
};
