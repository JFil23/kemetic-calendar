import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/nodes/kemetic_node_library.dart';
import 'package:mobile/features/nodes/kemetic_node_list_page.dart';
import 'package:mobile/features/nodes/kemetic_node_reader_page.dart';
import 'package:mobile/features/nodes/node_user_insights_section.dart';
import 'package:mobile/features/nodes/widgets.dart';
import 'package:mobile/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> _ensureSupabaseInitialized() async {
  try {
    Supabase.instance.client;
    return;
  } catch (_) {}

  await Supabase.initialize(
    url: 'https://example.supabase.co',
    anonKey: 'anon-key-0123456789012345678901234567890123456789',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await _ensureSupabaseInitialized();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'visible back button walks in-page node history before popping the route',
    (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: _ReaderLaunchPage()));

      await tester.tap(find.text('Open reader'));
      await tester.pumpAndSettle();

      expect(find.text('Serpent'), findsOneWidget);
      expect(find.text('Open reader'), findsNothing);

      await tester.ensureVisible(find.text('Ra').first);
      await tester.tap(find.text('Ra').first);
      await tester.pumpAndSettle();

      expect(find.text('Serpent'), findsNothing);
      expect(find.text('Ra'), findsWidgets);

      await tester.tap(find.byType(GlyphBackButton));
      await tester.pumpAndSettle();

      expect(find.text('Serpent'), findsOneWidget);
      expect(find.text('Open reader'), findsNothing);
    },
  );

  testWidgets('reader back returns to the library list near the exited node', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/nodes/serpent',
      routes: [
        GoRoute(
          path: '/nodes',
          builder: (context, state) => KemeticNodeListPage(
            initialNodeId: state.uri.queryParameters['focus'],
          ),
        ),
        GoRoute(
          path: '/nodes/:nodeId',
          builder: (context, state) {
            final nodeId = Uri.decodeComponent(state.pathParameters['nodeId']!);
            return KemeticNodeReaderPage(
              node: KemeticNodeLibrary.resolve(nodeId)!,
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Serpent'), findsOneWidget);

    await tester.tap(find.byType(GlyphBackButton));
    await tester.pumpAndSettle();

    expect(find.text('Serpent'), findsOneWidget);
    final scrollableState = tester.state<ScrollableState>(
      find.byType(Scrollable).last,
    );
    expect(scrollableState.position.pixels, greaterThan(0));
  });

  testWidgets('node route action flag opens the insight editor on load', (
    tester,
  ) async {
    Future<void> pumpRoute(String location) async {
      final router = GoRouter(
        initialLocation: location,
        routes: [
          GoRoute(
            path: '/nodes/:nodeId',
            builder: (context, state) {
              final nodeId = Uri.decodeComponent(
                state.pathParameters['nodeId']!,
              );
              return app.NodeReaderRoutePage(
                nodeId: nodeId,
                openInsightEditorOnLoad: app
                    .shouldOpenInsightEditorOnLoadFromNodeRoute(state.uri),
              );
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
    }

    await pumpRoute('/nodes/maat?action=add_insight');
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is KemeticNodeReaderPage && widget.openInsightEditorOnLoad,
      ),
      findsOneWidget,
    );

    await pumpRoute('/nodes/maat');
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is KemeticNodeReaderPage && !widget.openInsightEditorOnLoad,
      ),
      findsOneWidget,
    );

    expect(
      app.shouldOpenInsightEditorOnLoadFromNodeRoute(
        Uri.parse('/nodes/maat?insight=new'),
      ),
      isTrue,
    );
  });

  testWidgets('node route action is consumed into a stable route', (
    tester,
  ) async {
    final node = KemeticNodeLibrary.resolve('maat')!;
    final router = GoRouter(
      initialLocation: '/nodes/maat?action=add_insight',
      routes: [
        GoRoute(
          path: '/nodes/:nodeId',
          builder: (context, state) {
            final nodeId = Uri.decodeComponent(state.pathParameters['nodeId']!);
            return app.NodeReaderRoutePage(
              nodeId: nodeId,
              openInsightEditorOnLoad: app
                  .shouldOpenInsightEditorOnLoadFromNodeRoute(state.uri),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('New ${node.title} Insight'), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/nodes/maat',
    );
  });

  testWidgets('insights section opens route editor once across rebuilds', (
    tester,
  ) async {
    final node = KemeticNodeLibrary.resolve('maat')!;
    final rebuild = ValueNotifier<int>(0);
    addTearDown(rebuild.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<int>(
            valueListenable: rebuild,
            builder: (context, ignoredValue, ignoredChild) {
              return NodeUserInsightsSection(
                node: node,
                openEditorOnLoad: true,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sheetTitle = 'New ${node.title} Insight';
    expect(find.text(sheetTitle), findsOneWidget);

    rebuild.value++;
    await tester.pumpAndSettle();
    expect(find.text(sheetTitle), findsOneWidget);
  });

  testWidgets('insights section does not open editor without route flag', (
    tester,
  ) async {
    final node = KemeticNodeLibrary.resolve('maat')!;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NodeUserInsightsSection(node: node)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New ${node.title} Insight'), findsNothing);
    expect(find.text('Your Insights'), findsOneWidget);
  });

  testWidgets('node list glyph tiles fit compound and low-profile signs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(744, 1133);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final entry in const [
      ('declarations_of_innocence', '𓉹𓆄𓆄'),
      ('nile', '𓈘'),
      ('epagomenal_days', '𓏤𓏤𓏤𓏤𓏤'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(home: KemeticNodeListPage(initialNodeId: entry.$1)),
      );
      await tester.pumpAndSettle();

      final tile = find.byWidgetPredicate(
        (widget) =>
            widget is NodeGlyphMark &&
            widget.glyph == entry.$2 &&
            widget.framed,
      );
      expect(tile, findsWidgets, reason: entry.$1);
      expect(tester.getSize(tile.first), const Size(48, 48));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders cosmic order prose with table grids', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: KemeticNodeReaderPage(
          node: KemeticNodeLibrary.resolve('cosmic_order')!,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cosmic Order'), findsOneWidget);
    expect(find.byType(Table), findsNWidgets(3));
    expect(
      find.text('Cosmic Beginnings, Around 13.8 Billion Years Ago'),
      findsOneWidget,
    );
    expect(find.text('Modern Science'), findsOneWidget);
    expect(find.text('Purpose'), findsOneWidget);
    expect(find.text('Event or Shift'), findsOneWidget);
    expect(find.text('How Stardust Becomes Life'), findsOneWidget);
  });

  testWidgets('renders human emergence table grids', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: KemeticNodeReaderPage(
          node: KemeticNodeLibrary.resolve('human_emergence')!,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Human Emergence'), findsOneWidget);
    expect(find.byType(Table), findsNWidgets(7));
    expect(find.text('New Species'), findsOneWidget);
    expect(find.text('Human Mirror'), findsOneWidget);
  });

  testWidgets('renders ancient african tree table grids', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: KemeticNodeReaderPage(
          node: KemeticNodeLibrary.resolve('ancient_african_tree')!,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ancient African Tree'), findsOneWidget);
    expect(find.byType(Table), findsNWidgets(2));
    expect(find.text('Species'), findsOneWidget);
    expect(find.text('Ecological Context'), findsOneWidget);
  });

  testWidgets('renders rise of kush and kemet volcanic grid', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: KemeticNodeReaderPage(
          node: KemeticNodeLibrary.resolve('rise_of_kush_and_kemet')!,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rise of Kush and Kemet'), findsOneWidget);
    expect(find.byType(Table), findsOneWidget);
    expect(find.text('Volcanic Feature'), findsOneWidget);
    expect(find.text('Relevance'), findsOneWidget);
  });

  testWidgets('renders Ptahhotep emphasis without markdown markers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: KemeticNodeReaderPage(
          node: KemeticNodeLibrary.resolve('instruction_ptahhotep')!,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'He saw what happened when authority forgot how to listen.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.textContaining('**', findRichText: true), findsNothing);
  });

  testWidgets('renders Ma\'at citation emphasis without markdown markers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: KemeticNodeReaderPage(node: KemeticNodeLibrary.resolve('maat')!),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Pyramid Texts', findRichText: true),
      findsWidgets,
    );
    expect(find.textContaining('*', findRichText: true), findsNothing);
  });
}

class _ReaderLaunchPage extends StatelessWidget {
  const _ReaderLaunchPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => KemeticNodeReaderPage(
                  node: KemeticNodeLibrary.resolve('serpent')!,
                ),
              ),
            );
          },
          child: const Text('Open reader'),
        ),
      ),
    );
  }
}
