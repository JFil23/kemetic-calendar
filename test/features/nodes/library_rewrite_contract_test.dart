import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/insight_entry_model.dart';
import 'package:mobile/features/nodes/kemetic_node_library.dart';
import 'package:mobile/features/nodes/kemetic_node_model.dart';
import 'package:mobile/features/nodes/kemetic_node_reader_page.dart';
import 'package:mobile/features/nodes/kemetic_node_search_delegate.dart';
import 'package:mobile/features/nodes/library_read_progress_store.dart';
import 'package:mobile/features/nodes/library_read_state.dart';
import 'package:mobile/features/nodes/node_link_picker_sheet.dart';
import 'package:mobile/features/nodes/node_user_insights_section.dart';
import 'package:mobile/features/nodes/widgets.dart';
import 'package:mobile/main.dart' show NodeReaderRoutePage;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const retiredIds = [
  'ancient_african_tree',
  'regnal_year',
  'memphite_theology',
  'hawk',
  'esna_temple',
  'amduat',
  'horizon',
  'tomb_inscriptions',
  'middle_kingdom_funerary',
  'declarations_of_innocence',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
      anonKey: 'anon-key-0123456789012345678901234567890123456789',
    );
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('retired routes preserve their identity and exact original copy', () {
    final original =
        jsonDecode(
              File(
                'test/fixtures/library/simplified_first_pass_updated.v1.json',
              ).readAsStringSync(),
            )['nodes']
            as Map<String, dynamic>;
    for (final id in retiredIds) {
      final node = KemeticNodeLibrary.resolve(id)!;
      expect(node.id, id);
      expect(KemeticNodeLibrary.isRetired(id), isTrue);
      expect(KemeticNodeLibrary.nodes, isNot(contains(node)));
      expect(node.title, original[id]['title']);
      expect(
        sha256.convert(utf8.encode(node.body)).toString(),
        original[id]['body_sha256'],
      );
      for (final link in node.linkMap) {
        expect(KemeticNodeLibrary.resolve(link.targetId), isNotNull);
      }
    }
    expect(KemeticNodeLibrary.resolve('Horizon')!.id, 'horizon');
    expect(KemeticNodeLibrary.resolve('akhet')!.id, 'akhet');
    expect(KemeticNodeLibrary.resolve('Eye of Heru')!.id, 'hawk');
  });

  test('exact article titles take priority over thematic aliases', () {
    expect(KemeticNodeLibrary.resolve('Eye of Ra')!.id, 'eye_of_ra');
    expect(KemeticNodeLibrary.resolve("Ma'at")!.id, 'maat');
    expect(
      KemeticNodeLibrary.resolve('Book of the Dead')!.id,
      'book_of_the_dead',
    );
  });

  test(
    'active links have one subject each and no misleading retired anchors',
    () {
      for (final node in KemeticNodeLibrary.nodes) {
        expect(
          node.linkMap.map((l) => l.targetId).toSet().length,
          node.linkMap.length,
        );
        expect(
          node.linkMap.any((l) => retiredIds.contains(l.targetId)),
          isFalse,
        );
      }
      expect(
        KemeticNodeLibrary.resolve(
          'false_door',
        )!.linkMap.any((l) => l.phrase == 'Set'),
        isFalse,
      );
      expect(
        KemeticNodeLibrary.resolve(
          'wadi_el_jarf_papyri',
        )!.linkMap.any((l) => l.targetId == 'akhet'),
        isFalse,
      );
      expect(
        KemeticNodeLibrary.resolve(
          'ib',
        )!.linkMap.singleWhere((l) => l.phrase == 'Memphite Theology').targetId,
        'ptah',
      );
      final calendar = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      for (final id in retiredIds) {
        expect(calendar, isNot(contains("targetId: '$id'")));
      }
    },
  );

  test(
    'all 12 restored tables and 165 sections belong to the 61-node canon',
    () {
      final bodies = KemeticNodeLibrary.nodes
          .map((n) => n.body)
          .join('\n\n')
          .split('\n\n');
      final tables = bodies.where((b) => b.startsWith('|')).toList();
      expect(tables.length, 12);
      expect(tables.toSet().length, 12);
      expect(bodies.where((b) => b.startsWith('## ')).length, 165);
      expect(KemeticNodeLibrary.nodes.length, 61);
    },
  );

  test('saved insight search still opens its retired subject', () {
    final now = DateTime(2026, 10, 5);
    final entry = InsightEntry(
      id: 'saved-esna',
      userId: 'user-a',
      nodeId: 'esna_temple',
      nodeTitle: 'Esna Temple',
      bodyText: 'My saved temple reflection',
      entryDate: now,
      createdAt: now,
      updatedAt: now,
    );
    final search = KemeticNodeSearchDelegate(
      nodes: KemeticNodeLibrary.nodes,
      insightEntriesFuture: Future.value([entry]),
    );
    expect(
      search.debugMatchingNodeIds('Esna Temple', const []),
      isNot(contains('esna_temple')),
    );
    expect(search.debugMatchingNodeIds('saved temple reflection', [entry]), [
      'esna_temple',
    ]);
  });

  test(
    'retired bookmarks survive reload without becoming another article’s progress',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = LibraryReadProgressStore(
        prefs: prefs,
        currentUserIdProvider: () => null,
      );
      await store.setBookmark(
        nodeId: 'ancient_african_tree',
        progressPercent: 38,
        scrollOffset: 420,
      );
      final reloaded = LibraryReadProgressStore(
        prefs: prefs,
        currentUserIdProvider: () => null,
      );
      final snapshot = await reloaded.readSnapshot();
      expect(
        snapshot.progressFor('ancient_african_tree')!.bookmarkScrollOffset,
        420,
      );
      expect(snapshot.progressFor('human_emergence'), isNull);
      expect(
        resolveCurrentLibraryNodeId(
          canonicalNodeIds: KemeticNodeLibrary.nodes.map((n) => n.id).toList(),
          readSnapshot: snapshot,
        ),
        isNull,
      );
    },
  );

  testWidgets(
    'saved retired route retains its own insights and archive label',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: NodeReaderRoutePage(nodeId: 'esna_temple')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Archived entry · Kept for your saved links and insights.'),
        findsOneWidget,
      );
      final insights = tester.widget<NodeUserInsightsSection>(
        find.byType(NodeUserInsightsSection),
      );
      expect(insights.node.id, 'esna_temple');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long names win and later standalone short names still click through',
    (tester) async {
      const node = KemeticNode(
        id: 'links_specimen',
        title: 'Links specimen',
        glyph: '𓆄',
        body: 'Sah (Orion) and Sah. Eye of Ra and Eye of Ra. Ra returns.',
        linkMap: [
          KemeticNodeLink(phrase: 'Sah', targetId: 'sah'),
          KemeticNodeLink(phrase: 'Sah (Orion)', targetId: 'sah'),
          KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
          KemeticNodeLink(phrase: 'Eye of Ra', targetId: 'eye_of_ra'),
        ],
      );
      await tester.pumpWidget(
        const MaterialApp(home: KemeticNodeReaderPage(node: node)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sah (Orion)'), findsOneWidget);
      expect(find.text('Eye of Ra'), findsOneWidget);
      expect(find.text('Ra'), findsOneWidget);
      await tester.tap(find.text('Eye of Ra'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<NodeUserInsightsSection>(
              find.byType(NodeUserInsightsSection),
            )
            .node
            .id,
        'eye_of_ra',
      );
      await tester.tap(find.byType(GlyphBackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ra'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<NodeUserInsightsSection>(
              find.byType(NodeUserInsightsSection),
            )
            .node
            .id,
        'ra',
      );
    },
  );

  testWidgets(
    'new link picker omits retired entries and can remove an old link',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showNodeLinkPickerSheet(
                  context: context,
                  selectedText: 'saved passage',
                  currentNode: KemeticNodeLibrary.resolve('esna_temple'),
                ),
                child: const Text('Choose'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Esna');
      await tester.pumpAndSettle();
      expect(find.text('No matching nodes.'), findsOneWidget);
      expect(find.text('Remove link to Esna Temple'), findsOneWidget);
    },
  );
  testWidgets(
    'table links retain reading order through resize and sideways gestures',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      const specimen = KemeticNode(
        id: 'table_specimen',
        title: 'Table specimen',
        glyph: '𓆄',
        body:
            '| Name | Description |\n| --- | --- |\n| Ra | A long description to scroll into view. |\n\nRa appears again.',
        linkMap: [KemeticNodeLink(phrase: 'Ra', targetId: 'ra')],
      );
      await tester.pumpWidget(
        const MaterialApp(home: KemeticNodeReaderPage(node: specimen)),
      );
      await tester.pumpAndSettle();
      Finder tableLink() =>
          find.descendant(of: find.byType(Table), matching: find.text('Ra'));
      expect(tableLink(), findsOneWidget);
      tester.view.physicalSize = const Size(360, 780);
      await tester.pumpAndSettle();
      expect(tableLink(), findsOneWidget);
      final horizontal = find.byWidgetPredicate(
        (w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      );
      await tester.drag(horizontal, const Offset(-180, 0));
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: horizontal, matching: find.byType(Scrollable)),
          )
          .position;
      expect(position.pixels, greaterThan(0));
      await tester.drag(horizontal, const Offset(240, 0));
      await tester.pumpAndSettle();
      expect(tableLink(), findsOneWidget);
      await tester.tap(tableLink());
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<NodeUserInsightsSection>(
              find.byType(NodeUserInsightsSection),
            )
            .node
            .id,
        'ra',
      );
      await tester.tap(find.byType(GlyphBackButton));
      await tester.pumpAndSettle();
      expect(find.text('Table specimen'), findsOneWidget);
    },
  );

  testWidgets('table pan does not leave the clicked article', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    const specimen = KemeticNode(
      id: 'launch_table',
      title: 'Launch table',
      glyph: '𓆄',
      body: 'Human Emergence',
      linkMap: [
        KemeticNodeLink(phrase: 'Human Emergence', targetId: 'human_emergence'),
      ],
    );
    await tester.pumpWidget(
      const MaterialApp(home: KemeticNodeReaderPage(node: specimen)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Human Emergence'));
    await tester.pumpAndSettle();
    final table = find.byType(Table).first;
    await Scrollable.ensureVisible(tester.element(table), alignment: 0.05);
    await tester.pumpAndSettle();
    final horizontal = find
        .ancestor(
          of: table,
          matching: find.byWidgetPredicate(
            (w) =>
                w is SingleChildScrollView &&
                w.scrollDirection == Axis.horizontal,
          ),
        )
        .first;
    await tester.drag(horizontal, const Offset(-220, 0));
    await tester.pumpAndSettle();
    await tester.drag(horizontal, const Offset(150, 0));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<NodeUserInsightsSection>(find.byType(NodeUserInsightsSection))
          .node
          .id,
      'human_emergence',
    );
    expect(tester.takeException(), isNull);
  });
}
