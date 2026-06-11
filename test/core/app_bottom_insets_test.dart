import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/app_bottom_insets.dart';
import 'package:mobile/core/global_side_drawer_metrics.dart';
import 'package:mobile/features/nodes/kemetic_node_library.dart';
import 'package:mobile/features/nodes/kemetic_node_reader_page.dart';
import 'package:mobile/features/nodes/node_user_insights_section.dart';
import 'package:mobile/services/session_resume_service.dart';
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

  testWidgets('content padding follows the bottom-left drawer bubble', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    double? contentInset;
    double? bubbleInset;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            contentInset = AppBottomInsets.contentBottomPadding(context);
            bubbleInset = globalMenuBubbleContentBottomPadding(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(contentInset, bubbleInset);
    expect(contentInset, 112);
  });

  testWidgets('route scaffold does not add a full-width bottom bar inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const lastKey = ValueKey<String>('last-route-control');

    await tester.pumpWidget(
      const MaterialApp(
        home: AppPageScaffold(
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(key: lastKey, height: 48),
            ),
          ),
        ),
      ),
    );

    expect(tester.getBottomLeft(find.byKey(lastKey)).dy, 600);
  });

  testWidgets('scroll pages keep bubble-aware bottom padding', (tester) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    await tester.pumpWidget(
      const MaterialApp(
        home: AppScrollPage(children: [SizedBox(height: 1000)]),
      ),
    );

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    final padding = scrollView.padding as EdgeInsets;
    expect(padding.bottom, 112);
  });

  testWidgets('insight pages still scroll final content into view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AppPageScaffold(
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
  });

  testWidgets('main calendar route can opt out without special bottom chrome', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const lastKey = ValueKey<String>('calendar-opt-out-bottom-content');

    await tester.pumpWidget(
      const MaterialApp(
        home: SessionTrackedRoute(
          location: '/',
          applyBottomNavInset: false,
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(key: lastKey, height: 48),
            ),
          ),
        ),
      ),
    );

    expect(tester.getBottomLeft(find.byKey(lastKey)).dy, 600);
  });
}
