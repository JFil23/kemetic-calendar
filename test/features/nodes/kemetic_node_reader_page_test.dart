import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/nodes/kemetic_node_library.dart';
import 'package:mobile/features/nodes/kemetic_node_reader_page.dart';
import 'package:mobile/features/nodes/widgets.dart';
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
    expect(find.byType(Table), findsNWidgets(2));
    expect(
      find.text('Cosmic Beginnings, Around 13.8 Billion Years Ago'),
      findsOneWidget,
    );
    expect(find.text('Modern Science'), findsOneWidget);
    expect(find.text('Purpose'), findsOneWidget);
    expect(find.text('The Womb of Molecules'), findsOneWidget);
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
    expect(find.text('Fractured Lineage'), findsOneWidget);
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
