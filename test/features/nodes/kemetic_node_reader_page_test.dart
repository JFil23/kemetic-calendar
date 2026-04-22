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
