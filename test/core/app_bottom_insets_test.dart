import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/global_bottom_menu_metrics.dart';
import 'package:mobile/features/nodes/kemetic_node_library.dart';
import 'package:mobile/features/nodes/kemetic_node_reader_page.dart';
import 'package:mobile/features/nodes/node_user_insights_section.dart';
import 'package:mobile/services/session_resume_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _bottomNavKey = ValueKey<String>('test-bottom-nav');

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

  testWidgets('normal pages reserve space above bottom navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const lastKey = ValueKey<String>('last-normal-page-control');
    double? contentInset;
    double? navHeight;

    await tester.pumpWidget(
      _withBottomNav(
        Builder(
          builder: (context) {
            contentInset = AppBottomInsets.contentBottomPadding(context);
            navHeight = globalBottomMenuHeight(context);
            return AppPageScaffold(
              child: Scaffold(
                body: ListView(
                  padding: EdgeInsets.zero,
                  children: const [
                    SizedBox(height: 1000),
                    SizedBox(key: lastKey, height: 48),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(contentInset, greaterThan(navHeight!));
    expect(
      tester.getBottomLeft(find.byKey(lastKey)).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byKey(_bottomNavKey)).dy),
    );
  });

  testWidgets('insight page final card scrolls above bottom navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _withBottomNav(
        AppPageScaffold(
          child: KemeticNodeReaderPage(
            node: KemeticNodeLibrary.resolve('cosmic_order')!,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.dragUntilVisible(
      find.byKey(nodeUserInsightsEmptyCardKey),
      find.byType(SingleChildScrollView).first,
      const Offset(0, -260),
      maxIteration: 24,
    );
    await tester.pumpAndSettle();

    expect(find.text('Your Insights'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.byKey(nodeUserInsightsEmptyCardKey)).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byKey(_bottomNavKey)).dy),
    );
  });

  testWidgets(
    'main calendar keeps intentional infinite-scroll bottom behavior',
    (tester) async {
      tester.view.physicalSize = const Size(390, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const lastKey = ValueKey<String>('calendar-opt-out-bottom-content');

      await tester.pumpWidget(
        _withBottomNav(
          SessionTrackedRoute(
            location: '/',
            applyBottomNavInset: false,
            child: const Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(key: lastKey, height: 48),
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getBottomLeft(find.byKey(lastKey)).dy,
        greaterThan(tester.getTopLeft(find.byKey(_bottomNavKey)).dy),
      );
    },
  );

  testWidgets('normal route pages do not duplicate bottom navigation spacing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const lastKey = ValueKey<String>('last-route-page-control');

    await tester.pumpWidget(
      _withBottomNav(
        SessionTrackedRoute(
          location: '/settings',
          child: Scaffold(
            body: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: const [
                SizedBox(height: 1000),
                SizedBox(key: lastKey, height: 48),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    final navTop = tester.getTopLeft(find.byKey(_bottomNavKey)).dy;
    final lastBottom = tester.getBottomLeft(find.byKey(lastKey)).dy;

    expect(lastBottom, lessThanOrEqualTo(navTop));
    expect(navTop - lastBottom, lessThanOrEqualTo(56));
  });
}

Widget _withBottomNav(Widget child) {
  return MaterialApp(
    home: Stack(
      fit: StackFit.expand,
      children: [child, const _FakeBottomNav()],
    ),
  );
}

class _FakeBottomNav extends StatelessWidget {
  const _FakeBottomNav();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: globalBottomMenuHeight(context),
      child: const ColoredBox(key: _bottomNavKey, color: Colors.black),
    );
  }
}
