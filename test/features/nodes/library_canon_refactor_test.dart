import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/nodes/kemetic_node_library.dart';
import 'package:mobile/features/nodes/kemetic_node_list_page.dart';
import 'package:mobile/features/nodes/kemetic_numeral.dart';
import 'package:mobile/features/nodes/library_canon_adapter.dart';
import 'package:mobile/features/nodes/library_canon_entry.dart';
import 'package:mobile/features/nodes/library_read_progress_store.dart';
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

  group('Library reader progress state', () {
    testWidgets('node II is not highlighted or continued with no progress', (
      tester,
    ) async {
      _setPhoneViewport(tester);
      final entries = buildLibraryCanonEntries(nodes: KemeticNodeLibrary.nodes);

      expect(entries[1].node.id, 'human_emergence');
      expect(entries[1].visualState, LibraryChapterVisualState.unread);
      expect(
        resolveCurrentLibraryNodeId(
          canonicalNodeIds: _canonicalIds,
          readSnapshot: const LibraryReadSnapshot(),
        ),
        isNull,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LibraryCanonEntry(
              chapterNumber: entries[1].chapterNumber,
              title: entries[1].title,
              glyph: entries[1].glyph,
              themes: entries[1].themes,
              openingLine: entries[1].openingLine,
              readingMinutes: entries[1].readingMinutes,
              visualState: entries[1].visualState,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('CONTINUE →'), findsNothing);
      expect(find.text('✦ READ'), findsOneWidget);
    });

    test('node I unfinished progress makes node I current', () {
      final snapshot = _snapshot(
        LibraryNodeProgress(
          nodeId: 'cosmic_order',
          progressPercent: 41,
          lastScrollOffset: 420,
          lastReadAt: DateTime(2026, 6, 21, 10),
        ),
      );
      final entries = buildLibraryCanonEntries(
        nodes: KemeticNodeLibrary.nodes,
        readSnapshot: snapshot,
      );

      expect(entries[0].visualState, LibraryChapterVisualState.current);
      expect(entries[1].visualState, LibraryChapterVisualState.unread);
      expect(
        resolveCurrentLibraryNodeId(
          canonicalNodeIds: _canonicalIds,
          readSnapshot: snapshot,
        ),
        'cosmic_order',
      );
    });

    test('node II unfinished progress makes node II current', () {
      final snapshot = _snapshot(
        LibraryNodeProgress(
          nodeId: 'human_emergence',
          progressPercent: 36,
          lastScrollOffset: 380,
          lastReadAt: DateTime(2026, 6, 21, 11),
        ),
      );
      final entries = buildLibraryCanonEntries(
        nodes: KemeticNodeLibrary.nodes,
        readSnapshot: snapshot,
      );

      expect(entries[0].visualState, LibraryChapterVisualState.unread);
      expect(entries[1].visualState, LibraryChapterVisualState.current);
      expect(
        resolveCurrentLibraryNodeId(
          canonicalNodeIds: _canonicalIds,
          readSnapshot: snapshot,
        ),
        'human_emergence',
      );
    });

    test('later out-of-order progress becomes the active resume card', () {
      final snapshot = _snapshot(
        LibraryNodeProgress(
          nodeId: 'maat',
          progressPercent: 24,
          lastScrollOffset: 240,
          lastReadAt: DateTime(2026, 6, 21, 12),
        ),
      );
      final entries = buildLibraryCanonEntries(
        nodes: KemeticNodeLibrary.nodes,
        readSnapshot: snapshot,
      );
      final maatEntry = entries.singleWhere((entry) => entry.node.id == 'maat');

      expect(maatEntry.visualState, LibraryChapterVisualState.current);
      expect(
        resolveCurrentLibraryNodeId(
          canonicalNodeIds: _canonicalIds,
          readSnapshot: snapshot,
        ),
        'maat',
      );
    });

    testWidgets('completed node is complete and does not show continue', (
      tester,
    ) async {
      _setPhoneViewport(tester);
      final snapshot = _snapshot(
        LibraryNodeProgress(
          nodeId: 'cosmic_order',
          progressPercent: 100,
          lastScrollOffset: 2200,
          lastReadAt: DateTime(2026, 6, 21, 13),
          completedAt: DateTime(2026, 6, 21, 13),
        ),
      );
      final entries = buildLibraryCanonEntries(
        nodes: KemeticNodeLibrary.nodes,
        readSnapshot: snapshot,
      );

      expect(entries[0].visualState, LibraryChapterVisualState.completed);
      expect(
        resolveCurrentLibraryNodeId(
          canonicalNodeIds: _canonicalIds,
          readSnapshot: snapshot,
        ),
        isNull,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LibraryCanonEntry(
              chapterNumber: entries[0].chapterNumber,
              title: entries[0].title,
              glyph: entries[0].glyph,
              themes: entries[0].themes,
              openingLine: entries[0].openingLine,
              readingMinutes: entries[0].readingMinutes,
              visualState: entries[0].visualState,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('CONTINUE →'), findsNothing);
      expect(find.text('COMPLETE'), findsOneWidget);
    });

    test('manual bookmark overrides newer automatic progress', () {
      final snapshot = _snapshot(
        LibraryNodeProgress(
          nodeId: 'cosmic_order',
          progressPercent: 44,
          lastScrollOffset: 440,
          lastReadAt: DateTime(2026, 6, 21, 14),
        ),
        LibraryNodeProgress(
          nodeId: 'human_emergence',
          progressPercent: 12,
          lastScrollOffset: 120,
          lastReadAt: DateTime(2026, 6, 21, 9),
          bookmarkedAt: DateTime(2026, 6, 21, 9),
          bookmarkScrollOffset: 120,
        ),
      );

      expect(
        resolveCurrentLibraryNodeId(
          canonicalNodeIds: _canonicalIds,
          readSnapshot: snapshot,
        ),
        'human_emergence',
      );
    });
  });

  group('Library progress sync state', () {
    test('merge keeps completed state durable over newer partial progress', () {
      final completed = LibraryNodeProgress(
        nodeId: 'cosmic_order',
        progressPercent: 100,
        lastScrollOffset: 2200,
        completedAt: DateTime(2026, 6, 21, 9),
        updatedAt: DateTime(2026, 6, 21, 9),
      );
      final stalePartial = LibraryNodeProgress(
        nodeId: 'cosmic_order',
        progressPercent: 42,
        lastScrollOffset: 420,
        lastReadAt: DateTime(2026, 6, 21, 10),
        updatedAt: DateTime(2026, 6, 21, 10),
      );

      expect(
        mergeLibraryNodeProgress(completed, stalePartial),
        same(completed),
      );
      expect(
        mergeLibraryNodeProgress(stalePartial, completed),
        same(completed),
      );
    });

    test('merge prefers newest incomplete state including bookmark clears', () {
      final bookmarked = LibraryNodeProgress(
        nodeId: 'human_emergence',
        progressPercent: 25,
        lastScrollOffset: 250,
        lastReadAt: DateTime(2026, 6, 21, 8),
        bookmarkedAt: DateTime(2026, 6, 21, 8),
        bookmarkScrollOffset: 250,
        updatedAt: DateTime(2026, 6, 21, 8),
      );
      final unbookmarked = LibraryNodeProgress(
        nodeId: 'human_emergence',
        progressPercent: 30,
        lastScrollOffset: 300,
        lastReadAt: DateTime(2026, 6, 21, 9),
        updatedAt: DateTime(2026, 6, 21, 9),
      );

      final merged = mergeLibraryNodeProgress(bookmarked, unbookmarked)!;

      expect(merged.progressPercent, 30);
      expect(merged.bookmarkedAt, isNull);
      expect(merged.bookmarkScrollOffset, isNull);
    });

    test('local cache is scoped by authenticated user id', () async {
      final prefs = await SharedPreferences.getInstance();
      final userAStore = LibraryReadProgressStore(
        prefs: prefs,
        now: () => DateTime(2026, 6, 21, 10),
        currentUserIdProvider: () => 'user-a',
      );

      await userAStore.saveScrollProgress(
        nodeId: 'cosmic_order',
        progressPercent: 44,
        lastScrollOffset: 440,
      );

      final userBStore = LibraryReadProgressStore(
        prefs: prefs,
        now: () => DateTime(2026, 6, 21, 10),
        currentUserIdProvider: () => 'user-b',
      );

      expect(await userBStore.readNodeProgress('cosmic_order'), isNull);
      expect(await userAStore.readNodeProgress('cosmic_order'), isNotNull);
    });

    test('remote progress loads into Library state', () async {
      final remote = _FakeLibraryReadProgressRemote()
        ..seed(
          'user-a',
          LibraryNodeProgress(
            nodeId: 'cosmic_order',
            progressPercent: 47,
            lastScrollOffset: 470,
            lastReadAt: DateTime(2026, 6, 21, 10),
            updatedAt: DateTime(2026, 6, 21, 10),
          ),
        );
      final store = LibraryReadProgressStore(
        prefs: await SharedPreferences.getInstance(),
        currentUserIdProvider: () => 'user-a',
        remote: remote,
      );

      final snapshot = await store.readSnapshot();

      expect(snapshot.progressFor('cosmic_order')!.progressPercent, 47);
    });

    test(
      'remote later out-of-order node becomes active continue card',
      () async {
        final remote = _FakeLibraryReadProgressRemote()
          ..seed(
            'user-a',
            LibraryNodeProgress(
              nodeId: 'maat',
              progressPercent: 28,
              lastScrollOffset: 280,
              lastReadAt: DateTime(2026, 6, 21, 11),
              updatedAt: DateTime(2026, 6, 21, 11),
            ),
          );
        final store = LibraryReadProgressStore(
          prefs: await SharedPreferences.getInstance(),
          currentUserIdProvider: () => 'user-a',
          remote: remote,
        );
        final snapshot = await store.readSnapshot();
        final entries = buildLibraryCanonEntries(
          nodes: KemeticNodeLibrary.nodes,
          readSnapshot: snapshot,
        );
        final maatEntry = entries.singleWhere(
          (entry) => entry.node.id == 'maat',
        );

        expect(maatEntry.visualState, LibraryChapterVisualState.current);
        expect(
          resolveCurrentLibraryNodeId(
            canonicalNodeIds: _canonicalIds,
            readSnapshot: snapshot,
          ),
          'maat',
        );
      },
    );

    testWidgets('completed remote state shows complete without continue', (
      tester,
    ) async {
      _setPhoneViewport(tester);
      final remote = _FakeLibraryReadProgressRemote()
        ..seed(
          'user-a',
          LibraryNodeProgress(
            nodeId: 'cosmic_order',
            progressPercent: 100,
            lastScrollOffset: 2400,
            lastReadAt: DateTime(2026, 6, 21, 12),
            completedAt: DateTime(2026, 6, 21, 12),
            updatedAt: DateTime(2026, 6, 21, 12),
          ),
        );
      final store = LibraryReadProgressStore(
        prefs: await SharedPreferences.getInstance(),
        currentUserIdProvider: () => 'user-a',
        remote: remote,
      );
      final entries = buildLibraryCanonEntries(
        nodes: KemeticNodeLibrary.nodes,
        readSnapshot: await store.readSnapshot(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LibraryCanonEntry(
              chapterNumber: entries[0].chapterNumber,
              title: entries[0].title,
              glyph: entries[0].glyph,
              themes: entries[0].themes,
              openingLine: entries[0].openingLine,
              readingMinutes: entries[0].readingMinutes,
              visualState: entries[0].visualState,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('COMPLETE'), findsOneWidget);
      expect(find.text('CONTINUE →'), findsNothing);
    });

    test('bookmark priority survives store reload', () async {
      final prefs = await SharedPreferences.getInstance();
      final remote = _FakeLibraryReadProgressRemote();
      final firstStore = LibraryReadProgressStore(
        prefs: prefs,
        now: () => DateTime(2026, 6, 21, 13),
        currentUserIdProvider: () => 'user-a',
        remote: remote,
      );

      await firstStore.setBookmark(
        nodeId: 'ancient_african_tree',
        progressPercent: 19,
        scrollOffset: 190,
      );

      final secondStore = LibraryReadProgressStore(
        prefs: prefs,
        now: () => DateTime(2026, 6, 21, 14),
        currentUserIdProvider: () => 'user-a',
        remote: remote,
      );
      final snapshot = await secondStore.readSnapshot();

      expect(
        resolveCurrentLibraryNodeId(
          canonicalNodeIds: _canonicalIds,
          readSnapshot: snapshot,
        ),
        'ancient_african_tree',
      );
      expect(snapshot.progressFor('ancient_african_tree')!.isBookmarked, true);
    });

    test(
      'authenticated load syncs local fallback progress to remote',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final localStore = LibraryReadProgressStore(
          prefs: prefs,
          now: () => DateTime(2026, 6, 21, 15),
          currentUserIdProvider: () => null,
        );
        await localStore.saveScrollProgress(
          nodeId: 'cosmic_order',
          progressPercent: 33,
          lastScrollOffset: 330,
        );

        final remote = _FakeLibraryReadProgressRemote();
        final signedInStore = LibraryReadProgressStore(
          prefs: prefs,
          now: () => DateTime(2026, 6, 21, 16),
          currentUserIdProvider: () => 'user-a',
          remote: remote,
        );

        await signedInStore.readSnapshot();

        expect(
          remote.progressFor('user-a', 'cosmic_order')?.progressPercent,
          33,
        );
      },
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

void _setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

List<String> get _canonicalIds =>
    KemeticNodeLibrary.nodes.map((node) => node.id).toList(growable: false);

LibraryReadSnapshot _snapshot(
  LibraryNodeProgress first, [
  LibraryNodeProgress? second,
]) {
  final progress = <String, LibraryNodeProgress>{first.normalizedNodeId: first};
  if (second != null) {
    progress[second.normalizedNodeId] = second;
  }
  return LibraryReadSnapshot(progressByNodeId: progress);
}

class _FakeLibraryReadProgressRemote implements LibraryReadProgressRemote {
  final Map<String, Map<String, LibraryNodeProgress>> _rowsByUser =
      <String, Map<String, LibraryNodeProgress>>{};

  void seed(String userId, LibraryNodeProgress progress) {
    _rowsByUser.putIfAbsent(
      userId,
      () => <String, LibraryNodeProgress>{},
    )[progress.normalizedNodeId] = progress;
  }

  LibraryNodeProgress? progressFor(String userId, String nodeId) {
    return _rowsByUser[userId]?[normalizeLibraryNodeId(nodeId)];
  }

  @override
  Future<List<LibraryNodeProgress>> fetchAll({required String userId}) async {
    return _rowsByUser[userId]?.values.toList(growable: false) ??
        const <LibraryNodeProgress>[];
  }

  @override
  Future<LibraryNodeProgress?> upsert({
    required String userId,
    required LibraryNodeProgress progress,
  }) async {
    final userRows = _rowsByUser.putIfAbsent(
      userId,
      () => <String, LibraryNodeProgress>{},
    );
    final resolved = mergeLibraryNodeProgress(
      userRows[progress.normalizedNodeId],
      progress,
    )!;
    userRows[progress.normalizedNodeId] = resolved;
    return resolved;
  }
}

String _visibleRouterPath(GoRouter router) {
  final configuration = router.routerDelegate.currentConfiguration;
  final topMatch = configuration.lastOrNull;
  if (topMatch is ImperativeRouteMatch) return topMatch.matches.uri.path;
  return configuration.uri.path;
}
