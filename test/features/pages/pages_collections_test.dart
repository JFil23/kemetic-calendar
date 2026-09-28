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
import 'package:mobile/data/account_view_cache.dart';
import 'package:mobile/data/event_filing_repo.dart';
import 'package:mobile/data/event_filing_engine.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mobile/features/pages/pages_collections.dart';
import 'package:mobile/features/pages/pages_collections_controller.dart';
import 'package:mobile/features/pages/pages_layout.dart';
import 'package:mobile/features/pages/pages_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages_resource_test.dart' show session, uid, drain;

Map<String, Object?> row(int n, String kind) => {
  'id': 'event-$kind-$n',
  'user_id': uid,
  'client_event_id': 'client-$kind-$n',
  'title': '$kind $n',
  'starts_at': '2026-09-27T12:00:00Z',
  'all_day': false,
  'item_kind': kind,
  'lifecycle': 'active',
};

void main() {
  setUpAll(() => initializeDateFormatting());
  test(
    'lists read only on demand, page, reuse cache, and stop while hidden',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          requests.add(r);
          final kind = r.url.queryParameters['item_kind']!.replaceFirst(
            'eq.',
            '',
          );
          final offset = int.parse(r.url.queryParameters['offset'] ?? '0');
          return http.Response(
            jsonEncode(
              List.generate(offset == 0 ? 50 : 1, (i) => row(offset + i, kind)),
            ),
            200,
            headers: {'content-type': 'application/json'},
            request: r,
          );
        }),
      );
      await client.auth.recoverSession(session());
      final c = PagesCollectionsController(client, cache: AccountViewCache());
      c.setVisible(true);
      await drain();
      expect(requests, isEmpty);
      expect(
        await EventFilingRepo(
          client,
        ).getOwnedItemsPage(kind: FiledItemKind.note, offset: 0),
        hasLength(50),
      );
      requests.clear();
      c.select(PagesCollection.notes);
      await drain();
      expect(c.value.items, hasLength(50));
      expect(c.value.hasMore, isTrue);
      expect(requests.single.method, 'GET');
      expect(requests.single.url.queryParameters['user_id'], 'eq.$uid');
      expect(requests.single.url.queryParameters['lifecycle'], 'neq.deleted');
      await c.loadMore();
      expect(c.value.items, hasLength(51));
      expect(c.value.hasMore, isFalse);
      c.select(PagesCollection.reminders);
      await drain();
      expect(c.value.items.first.event!.kind.name, 'reminder');
      c.select(PagesCollection.notes);
      await drain();
      expect(requests, hasLength(3));
      c.setVisible(false);
      c.select(PagesCollection.reminders);
      await drain();
      expect(requests, hasLength(3));
      c.dispose();
      await client.dispose();
    },
  );

  test(
    'Notes starts at local midnight and advances using the existing boundary',
    () async {
      var now = DateTime(2026, 9, 27, 18);
      final requests = <http.Request>[];
      final dates = [
        DateTime(2026, 9, 26, 23, 59),
        DateTime(2026, 9, 27),
        DateTime(2026, 9, 28),
      ];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          requests.add(r);
          final cutoff = r.url.queryParameters['starts_at'];
          final rows = [
            for (var i = 0; i < dates.length; i++)
              if (cutoff == null ||
                  !dates[i].toUtc().isBefore(
                    DateTime.parse(cutoff.substring(4)),
                  ))
                {
                  ...row(i, 'note'),
                  'starts_at': dates[i].toUtc().toIso8601String(),
                },
          ];
          return http.Response(
            jsonEncode(rows),
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await client.auth.recoverSession(session());
      final c = PagesCollectionsController(
        client,
        cache: AccountViewCache(),
        now: () => now,
      );
      c.setVisible(true);
      c.select(PagesCollection.notes);
      await drain();
      expect(c.value.items.map((i) => i.title), ['note 1', 'note 2']);
      expect(
        requests.single.url.queryParameters['starts_at'],
        'gte.${DateTime(2026, 9, 27).toUtc().toIso8601String()}',
      );
      c.refreshDate();
      await drain();
      expect(requests, hasLength(1));
      now = DateTime(2026, 9, 28);
      c.refreshDate();
      expect(c.value.items, isEmpty);
      await drain();
      expect(c.value.items.map((i) => i.title), ['note 2']);
      c.select(PagesCollection.reminders);
      await drain();
      expect(
        requests.last.url.queryParameters.containsKey('starts_at'),
        isFalse,
      );
      c.dispose();
      await client.dispose();
    },
  );

  test(
    'Flows reuses filing RPC and excludes reminders and note helpers',
    () async {
      SharedPreferences.setMockInitialValues({});
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          requests.add(r);
          final rows = r.url.path.endsWith('get_my_filed_flows_v1')
              ? [
                  for (var i = 1; i <= 4; i++)
                    {
                      'id': i,
                      'user_id': uid,
                      'name': 'flow $i',
                      'color': 0xd4af37,
                      'active': true,
                      'visible_in_active_list': true,
                      'is_reminder': i == 2,
                      'is_hidden': i == 3,
                      if (i == 4) 'notes': '{"kind":"repeating_note"}',
                    },
                ]
              : [];
          return http.Response(
            jsonEncode(rows),
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await client.auth.recoverSession(session());
      final c = PagesCollectionsController(client, cache: AccountViewCache());
      c.setVisible(true);
      c.select(PagesCollection.flows);
      await drain();
      expect(c.value.items.map((i) => i.title), ['flow 1']);
      final count = requests.length;
      c.select(null);
      c.select(PagesCollection.flows);
      await drain();
      expect(requests, hasLength(count));
      expect(
        requests.every(
          (r) => r.method == 'GET' || r.url.path.contains('/rpc/get_'),
        ),
        isTrue,
      );
      c.dispose();
      await client.dispose();
    },
  );

  test(
    'late response cannot replace another tab or a departed account',
    () async {
      final pending = Completer<http.Response>();
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) => pending.future),
      );
      await client.auth.recoverSession(session());
      final cache = AccountViewCache();
      final c = PagesCollectionsController(client, cache: cache);
      c.setVisible(true);
      c.select(PagesCollection.notes);
      await drain();
      c.select(null);
      cache.enterAccount('another-user');
      pending.complete(http.Response(jsonEncode([row(1, 'note')]), 200));
      await drain();
      expect(c.value.collection, isNull);
      expect(c.value.items, isEmpty);
      expect(
        cache.peek<Object>('another-user', 'pages.collection.notes.0'),
        isNull,
      );
      c.dispose();
      await client.dispose();
    },
  );

  testWidgets('tabs show simple lists, filter locally, and return to panes', (
    tester,
  ) async {
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final f in fonts) {
      final loader = FontLoader(f['family']);
      for (final a in f['fonts']) {
        loader.addFont(rootBundle.load(a['asset']));
      }
      await loader.load();
    }
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cards = [
      for (final d in PagesDestination.values) ValueNotifier(PagesCard(d)),
    ];
    final snapshot = ValueNotifier(const PagesCollectionState());
    final key = GlobalKey();
    PagesCollectionItem? opened;
    final selections = <PagesCollection?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: RepaintBoundary(
          key: key,
          child: ValueListenableBuilder<PagesCollectionState>(
            valueListenable: snapshot,
            builder: (context, state, _) => PagesLayout(
              cards: cards,
              profileHandle: 'bigjfil',
              profileGlyphIds: const ['i', 'receive', 'aset'],
              onOpen: (_) {},
              onProfile: () {},
              onNewNote: () {},
              onSearchResult: (_) {},
              searchRecords: () => [],
              collectionState: state,
              onCollectionItem: (item) => opened = item,
              onCollectionChanged: (tab) {
                selections.add(tab);
                snapshot.value = PagesCollectionState(
                  collection: tab,
                  items: const [
                    PagesCollectionItem(
                      id: '1',
                      title: 'Say no to burnout',
                      detail: 'Sep 27, 2026',
                    ),
                    PagesCollectionItem(
                      id: '2',
                      title: 'Make time for Spanish',
                      detail: 'Sep 26, 2026',
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(find.text('Say no to burnout'), findsOneWidget);
    expect(find.text('Make time for Spanish'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final path = Platform.environment['HAW_LIST_CAPTURE_PATH'];
    if (path != null) {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      void repaint(RenderObject node) {
        node.markNeedsPaint();
        node.visitChildren(repaint);
      }

      repaint(boundary);
      await tester.pump();
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(path).writeAsBytes(bytes!.buffer.asUint8List());
      });
    }
    await tester.enterText(find.byType(TextField), 'Spanish');
    await tester.pumpAndSettle();
    expect(find.text('Say no to burnout'), findsNothing);
    expect(selections, [PagesCollection.notes]);
    await tester.tap(find.text('Make time for Spanish'));
    expect(opened!.id, '2');
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(selections.last, isNull);
    expect(find.text('Say no to burnout'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    snapshot.dispose();
    for (final card in cards) {
      card.dispose();
    }
  });
}
