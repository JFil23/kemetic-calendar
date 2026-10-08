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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/main.dart' show createAppRouterForTesting;
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import 'package:mobile/features/reflections/decan_review_context.dart';
import 'package:mobile/features/reflections/decan_review_models.dart';
import 'package:mobile/features/reflections/decan_review_screen.dart';
import 'package:mobile/widgets/utility_sheet_route_scaffold.dart';
import 'package:mobile/features/reflections/decan_review_widgets.dart';
import 'package:mobile/features/journal/journal_archive_page.dart';
import 'package:mobile/features/journal/journal_v2_document_model.dart';
import 'package:mobile/features/profile/insight_post_detail_page.dart';
import '../../features/pages/pages_resource_test.dart' show session, uid;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  var offline = false;
  final now = DateTime.now();
  final date =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  const words =
      'Give a thought time before I answer it. Make a little more room for unhurried walks.';
  const question = 'What would you like to carry forward?';
  final context = DecanReviewContext(
    questionId: 'carry',
    question: question,
    moments: [
      DecanMoment(
        id: 'r',
        kind: 'response',
        sourceId: 'r',
        occurredOn: DateTime(2026, 10, 2),
        sourceLabel: 'Reading House',
        actionLabel: 'Your words',
        text: '“I can give a thought time before I answer it.”',
        isQuote: true,
        journalEntryId: 'entry',
      ),
      DecanMoment(
        id: 'w',
        kind: 'flow',
        sourceId: 'w',
        occurredOn: DateTime(2026, 10, 6),
        sourceLabel: 'Your flow',
        actionLabel: 'Completed',
        text: 'An evening walk',
        flowId: 42,
      ),
      DecanMoment(
        id: 'l',
        kind: 'library',
        sourceId: 'l',
        occurredOn: DateTime(2026, 10, 9),
        sourceLabel: 'Library',
        actionLabel: 'Bookmarked',
        text: 'Instruction of Ptahhotep',
        libraryId: 'instruction_ptahhotep',
      ),
    ],
  );
  final review = {
    'id': 'review',
    'decan_name': 'Decan reflection',
    'decan_start': '2026-10-01',
    'decan_end': '2026-10-10',
    'created_at': '2026-10-10T20:00:00Z',
    'review_revision': 1,
    'review_context': context.toJson(),
  };
  final document = {
    'version': 1,
    'blocks': [
      {
        'type': 'paragraph',
        'id': 'earlier',
        'ops': [
          {
            'insert':
                'The afternoon moved slowly. I want to remember the light on the table.',
            'attrs': {'italic': true},
          },
        ],
      },
      const DrawingBlock(
        id: 'kept-drawing',
        strokes: [
          DrawingStroke(
            points: [StrokePoint(x: 12, y: 18), StrokePoint(x: 36, y: 44)],
            color: 0xFFD4AE43,
            width: 2,
            tool: 'pen',
          ),
        ],
      ).toJson(),
      const ChartBlock(
        id: 'kept-chart',
        data: ChartData(
          labels: ['Morning'],
          series: [
            ChartSeries(name: 'Energy', values: [3], color: '#D4AE43'),
          ],
        ),
        options: ChartOptions(type: 'bar', title: 'Energy'),
      ).toJson(),
      {
        'type': 'paragraph',
        'id': 'decan_reflection:review',
        'ops': [
          {'insert': words},
        ],
      },
    ],
    'meta': {
      'personal_context': {'kept': true},
      'decan_sources': {
        'review': {
          'question': question,
          'start': '2026-10-01',
          'end': '2026-10-10',
        },
      },
    },
  };
  late Map<String, dynamic> entry;
  late Map<String, dynamic> post;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    for (final name in ['messages', 'events']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('com.llfbandit.app_links/$name'),
            (_) async => null,
          );
    }
    for (final face in {
      'Inter': 'Inter-Variable.ttf',
      'InterWeb': 'Inter-Regular.ttf',
      'GentiumPlus': 'GentiumPlus-Regular.ttf',
      'CormorantGaramond': 'CormorantGaramond-Regular.ttf',
    }.entries) {
      await (FontLoader(
        face.key,
      )..addFont(rootBundle.load('ios/Runner/Fonts/${face.value}'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('CormorantGaramond')
          ..addFont(
            rootBundle.load('ios/Runner/Fonts/CormorantGaramond-Regular.ttf'),
          )
          ..addFont(
            rootBundle.load('ios/Runner/Fonts/CormorantGaramond-Italic.ttf'),
          ))
        .load();
    await Supabase.initialize(
      url: 'https://example.supabase.test',
      anonKey: 'fixture',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        requests.add(r);
        final table = r.url.path.split('/').last;
        Object? data = [];
        var status = 200;
        if (offline) {
          data = {'message': 'offline'};
          status = 503;
        } else if (table == 'decan_reflections')
          data = review;
        else if (table == 'flows')
          data = {
            'id': 42,
            'user_id': uid,
            'name': 'An evening walk',
            'color': 0xCDAA42,
            'active': true,
            'is_saved': false,
            'is_hidden': false,
            'start_date': date,
            'end_date': date,
            'notes': 'mode=gregorian;ov=A%20quiet%20walk',
            'rules': [],
          };
        else if (table == 'read_decan_activity_v1')
          data = {'items': [], 'next_cursor': null};
        else if (table == 'decan_journal_sources')
          data = {
            'reflection_id': 'review',
            'greg_date': date,
            'block_id': 'decan_reflection:review',
            'is_deleted': false,
          };
        else if (table == 'journal_entries')
          data = entry;
        else if (table == 'read_journal_state_v1')
          data = {'revision': entry['revision'], 'row': entry};
        else if (table == 'insight_posts')
          data = post;
        else if (table == 'apply_journal_mutation_v1') {
          final req = jsonDecode(r.body) as Map;
          expect(req['p_expected_revision'], entry['revision']);
          expect(req['p_account'], uid);
          entry = {
            ...entry,
            'body': req['p_body'],
            'revision': (entry['revision'] as int) + 1,
          };
          data = {
            'status': 'applied',
            'revision': entry['revision'],
            'row': entry,
          };
        } else if (table == 'apply_decan_journal_v1') {
          final req = jsonDecode(r.body) as Map;
          final doc = jsonDecode(entry['body'] as String) as Map;
          (doc['blocks'] as List).last['ops'] = [
            {'insert': req['p_words']},
          ];
          entry = {
            ...entry,
            'body': jsonEncode(doc),
            'revision': (entry['revision'] as int) + 1,
          };
          data = {
            'status': 'applied',
            'revision': entry['revision'],
            'row': entry,
          };
        }
        return http.Response(
          jsonEncode(data),
          status,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  setUp(() async {
    offline = false;
    requests.clear();
    SharedPreferences.setMockInitialValues({});
    await Supabase.instance.client.auth.recoverSession(session());
    await WarmSnapshotStore.instance.forgetAccount(uid);
    entry = {
      'id': 'entry',
      'user_id': uid,
      'greg_date': date,
      'body': jsonEncode(document),
      'meta': {},
      'revision': 2,
      'created_at': '${date}T20:00:00Z',
      'updated_at': '${date}T20:00:00Z',
    };
    post = {
      'id': 'post',
      'user_id': uid,
      'source_kind': 'decan',
      'source_reflection_id': 'review',
      'body_text': words,
      'question_text': question,
      'revision': 1,
      'entry_date': date,
      'created_at': '${date}T20:00:00Z',
      'updated_at': '${date}T20:00:00Z',
      'author_display_name': 'Amina',
      'author_handle': 'amina',
    };
  });
  tearDownAll(() async => Supabase.instance.dispose());
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    'real reflection, Journal and social routes retain their established owners and warm state',
    (tester) async {
      tester.view.physicalSize = const Size(402, 1150);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = createAppRouterForTesting();
      final routes = app.configuration.routes
          .whereType<GoRoute>()
          .where(
            (r) => [
              '/reflections/:reflectionId',
              '/journal/entry/:entryId',
              '/insight-post/:postId',
              '/shared-flow/by-flow/:flowId',
            ].contains(r.path),
          )
          .toList();
      expect(routes, hasLength(4));
      const capture = ValueKey('review-route-capture');
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, __) => const SizedBox.expand()),
          ...routes,
        ],
      );
      addTearDown(router.dispose);
      addTearDown(app.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          routerConfig: router,
          builder: (context, child) =>
              RepaintBoundary(key: capture, child: child!),
        ),
      );
      Future<void> screenshot(String name) async {
        if (Platform.environment['HAW_DECAN_CAPTURE_DIR']
            case final String path) {
          await tester.runAsync(() async {
            final image =
                await (tester.element(find.byKey(capture)).renderObject!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(path).create(recursive: true);
            await File(
              '$path/route-$name.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }

      unawaited(router.push('/reflections/review'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(DecanReviewScreen), findsOneWidget);
      expect(find.text('These ten days'), findsOneWidget);
      expect(find.byType(DecanMomentTile), findsNWidgets(3));
      await screenshot('review');
      expect(requests.any((r) => r.url.path.contains('ai_generate')), isFalse);
      expect(
        find.byKey(utilitySheetRouteCloseButtonKey).hitTestable(),
        findsOneWidget,
      );
      final reflectionState = tester.state(find.byType(DecanReviewScreen));
      final flowMoment = find.widgetWithText(
        DecanMomentTile,
        'An evening walk',
      );
      await tester.ensureVisible(flowMoment);
      await tester.tap(flowMoment);
      await settle(tester);
      expect(router.state.uri.path, '/shared-flow/by-flow/42');
      expect(
        find.byKey(const ValueKey('user-flow-detail-surface-42')),
        findsOneWidget,
      );
      expect(find.text('Edit Flow'), findsNothing);
      expect(
        find.byKey(const ValueKey('user-flow-detail-scroll-42')),
        findsOneWidget,
      );
      await screenshot('canonical-flow');
      await tester.tap(find.byKey(utilitySheetRouteCloseButtonKey).last);
      await settle(tester);
      expect(router.state.uri.path, '/reflections/review');
      expect(
        tester.state(find.byType(DecanReviewScreen)),
        same(reflectionState),
      );

      expect(find.text('Read your saved reflection  →'), findsOneWidget);
      await tester.tap(find.text('Edit your words'));
      await settle(tester);
      await tester.enterText(
        find.byType(TextField).first,
        'A new sentence of my own.',
      );
      await tester.tap(find.byKey(utilitySheetRouteCloseButtonKey));
      await settle(tester);
      expect(router.state.uri.path, '/');
      unawaited(router.push('/reflections/review'));
      await settle(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'A new sentence of my own.',
      );
      await tester.ensureVisible(find.text('Keep in Journal'));
      await tester.tap(find.text('Keep in Journal'));
      await settle(tester);
      expect(find.text('Kept in Journal'), findsOneWidget);
      expect(
        find.textContaining('A new sentence of my own.', findRichText: true),
        findsOneWidget,
      );
      expect(
        post['body_text'],
        words,
        reason: 'private edit never changes published snapshot',
      );
      final saved = jsonDecode(entry['body'] as String) as Map;
      expect(
        (saved['blocks'] as List).first,
        document['blocks'] is List ? (document['blocks'] as List).first : null,
      );
      await screenshot('saved');
      router.go('/journal/entry/entry');
      await settle(tester);
      expect(find.byType(JournalArchivePage), findsOneWidget);
      expect(find.byKey(journalArchiveReflectionSkinKey), findsOneWidget);
      expect(find.text('Journal Entry'), findsOneWidget);
      expect(find.byType(DecanReviewCanvas), findsNothing);
      expect(
        find.textContaining('A new sentence of my own.', findRichText: true),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await screenshot('journal');
      expect(
        find.textContaining(
          'removing them from Journal leaves your post in place',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Edit reflection'));
      await tester.tap(find.text('Edit reflection'));
      await settle(tester);
      await tester.enterText(
        find.byType(TextField).first,
        'Edited inside Journal.',
      );
      await tester.ensureVisible(find.text('Save').last);
      await tester.tap(find.text('Save').last);
      await settle(tester);
      expect(
        find.textContaining('Edited inside Journal.', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      final journalEdited = jsonDecode(entry['body'] as String) as Map;
      expect(
        (journalEdited['blocks'] as List).first,
        (saved['blocks'] as List).first,
      );
      expect(
        (journalEdited['blocks'] as List).where(
          (b) => b['id'] != 'decan_reflection:review',
        ),
        (saved['blocks'] as List).where(
          (b) => b['id'] != 'decan_reflection:review',
        ),
      );
      expect(journalEdited['meta'], saved['meta']);
      expect(post['body_text'], words);
      router.go('/reflections/review');
      await settle(tester);
      await tester.tap(find.text('Read your saved reflection  →'));
      await settle(tester);
      expect(
        find.textContaining('Edited inside Journal.', findRichText: true),
        findsOneWidget,
      );
      router.go('/insight-post/post');
      await settle(tester);
      expect(find.byType(InsightPostDetailPage), findsOneWidget);
      expect(find.byType(DecanReviewCanvas), findsNothing);
      expect(find.text(words), findsOneWidget);
      expect(find.text('Amina'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await screenshot('post');
      router.go('/journal/entry/entry');
      await settle(tester);
      await tester.ensureVisible(find.text('Remove reflection from Journal'));
      await tester.tap(find.text('Remove reflection from Journal'));
      await settle(tester);
      final removed = jsonDecode(entry['body'] as String) as Map;
      expect(
        (removed['blocks'] as List).any(
          (b) => b['id'] == 'decan_reflection:review',
        ),
        isFalse,
      );
      expect(
        (removed['blocks'] as List),
        (journalEdited['blocks'] as List).where(
          (b) => b['id'] != 'decan_reflection:review',
        ),
      );
      expect(
        post['body_text'],
        words,
        reason:
            'removing the private contribution never removes the public snapshot',
      );
      expect(tester.takeException(), isNull);
      offline = true;
      router.go('/reflections/review');
      await settle(tester);
      expect(find.text('These ten days'), findsOneWidget);
      expect(find.byType(DecanMomentTile), findsNWidgets(3));
      expect(tester.takeException(), isNull);
      await Supabase.instance.client.auth.recoverSession(
        session().replaceAll(uid, '11111111-1111-4111-8111-111111111111'),
      );
      await settle(tester);
      expect(find.text('A new sentence of my own.'), findsNothing);
      expect(find.text('These ten days'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
