import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/nodes/kemetic_node_library.dart';
import 'package:mobile/features/nodes/kemetic_node_list_page.dart';
import 'package:mobile/features/nodes/kemetic_numeral.dart';
import 'package:mobile/features/nodes/library_canon_adapter.dart';
import 'package:mobile/features/nodes/library_canon_entry.dart';
import 'package:mobile/features/nodes/library_read_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Kemetic numeral decomposition', () {
    test('stacks additive numerals in stable rows', () {
      expect(_rowsFor(1), {
        1: ['𓏺'],
      });
      expect(_rowsFor(2), {
        1: ['𓏺𓏺'],
      });
      expect(_rowsFor(3), {
        1: ['𓏺𓏺𓏺'],
      });
      expect(_rowsFor(4), {
        1: ['𓏺𓏺𓏺', '𓏺'],
      });
      expect(_rowsFor(5), {
        1: ['𓏺𓏺𓏺', '𓏺𓏺'],
      });
      expect(_rowsFor(9), {
        1: ['𓏺𓏺𓏺', '𓏺𓏺𓏺', '𓏺𓏺𓏺'],
      });
      expect(_rowsFor(10), {
        10: ['𓎆'],
      });
      expect(_rowsFor(12), {
        10: ['𓎆'],
        1: ['𓏺𓏺'],
      });
      expect(_rowsFor(27), {
        10: ['𓎆𓎆'],
        1: ['𓏺𓏺𓏺', '𓏺𓏺𓏺', '𓏺'],
      });
      expect(_rowsFor(100), {
        100: ['𓍢'],
      });
      expect(_rowsFor(276), {
        100: ['𓍢𓍢'],
        10: ['𓎆𓎆', '𓎆𓎆', '𓎆𓎆', '𓎆'],
        1: ['𓏺𓏺𓏺', '𓏺𓏺𓏺'],
      });
    });
  });

  test(
    'read state resolver maps read, current, unread without persistence',
    () {
      const ids = ['cosmic_order', 'human_emergence', 'ancient_african_tree'];
      const snapshot = LibraryReadSnapshot(readNodeIds: {'cosmic_order'});

      expect(
        resolveLibraryChapterVisualState(
          nodeId: 'cosmic_order',
          canonicalNodeIds: ids,
          readSnapshot: snapshot,
        ),
        LibraryChapterVisualState.read,
      );
      expect(
        resolveLibraryChapterVisualState(
          nodeId: 'human_emergence',
          canonicalNodeIds: ids,
          readSnapshot: snapshot,
        ),
        LibraryChapterVisualState.current,
      );
      expect(
        resolveLibraryChapterVisualState(
          nodeId: 'ancient_african_tree',
          canonicalNodeIds: ids,
          readSnapshot: snapshot,
        ),
        LibraryChapterVisualState.unread,
      );
    },
  );

  test('explicit current node wins when it is not already read', () {
    const ids = ['cosmic_order', 'human_emergence', 'ancient_african_tree'];
    const snapshot = LibraryReadSnapshot(currentNodeId: 'ancient_african_tree');

    expect(
      resolveCurrentLibraryNodeId(
        canonicalNodeIds: ids,
        readSnapshot: snapshot,
      ),
      'ancient_african_tree',
    );
  });

  test('opening line uses the first real prose sentence', () {
    final node = KemeticNodeLibrary.resolve('cosmic_order')!;

    expect(
      extractOpeningLine(node.body),
      'Before there was a world to order, there was only potential.',
    );
    expect(
      extractOpeningLine(
        '## Heading\n\n| A | B |\n| --- | --- |\n\n*First* sentence. Second sentence.',
      ),
      'First sentence.',
    );
  });

  test('canon adapter preserves canonical order for chapter indexes', () {
    final entries = buildLibraryCanonEntries(nodes: KemeticNodeLibrary.nodes);

    expect(entries.first.chapterNumber, 1);
    expect(entries.first.node.id, 'cosmic_order');
    expect(entries[1].chapterNumber, 2);
    expect(entries[1].node.id, 'human_emergence');
    expect(entries.first.themes.take(2).toList(), [
      'Cosmic Beginnings',
      'Elemental Memory',
    ]);
  });

  testWidgets('card tap opens the existing node route', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/nodes',
      routes: [
        GoRoute(
          path: '/nodes',
          builder: (context, state) => const KemeticNodeListPage(),
        ),
        GoRoute(
          path: '/nodes/:nodeId',
          builder: (context, state) =>
              Scaffold(body: Text('Node ${state.pathParameters['nodeId']}')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(LibraryCanonEntry).first);
    await tester.pumpAndSettle();

    expect(_visibleRouterPath(router), '/nodes/cosmic_order');
    expect(find.text('Node cosmic_order'), findsOneWidget);
  });
}

Map<int, List<String>> _rowsFor(int value) => {
  for (final group in decomposeKemeticNumber(value)) group.value: group.rows,
};

String _visibleRouterPath(GoRouter router) {
  final configuration = router.routerDelegate.currentConfiguration;
  final topMatch = configuration.lastOrNull;
  if (topMatch is ImperativeRouteMatch) return topMatch.matches.uri.path;
  return configuration.uri.path;
}
