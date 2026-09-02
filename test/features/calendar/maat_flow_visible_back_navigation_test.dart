import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/maat_list_to_detail_route.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        anonKey: 'anon-key-0123456789012345678901234567890123456789',
      );
    }
  });

  const scenarios = <({String templateKey, Key backKey})>[
    (
      templateKey: 'track-the-sky',
      backKey: ValueKey<String>('follow-sky-back'),
    ),
    (
      templateKey: 'the-offering-table',
      backKey: ValueKey<String>('offering-table-back'),
    ),
    (
      templateKey: 'the-reading-house',
      backKey: ValueKey<String>('reading-house-back'),
    ),
  ];

  for (final scenario in scenarios) {
    testWidgets(
      '${scenario.templateKey} visible back dismisses detail but keeps Ma’at Flows open',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            home: Navigator(
              key: navigatorKey,
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => const Center(child: Text('Flow Studio hub')),
              ),
            ),
          ),
        );

        unawaited(
          navigatorKey.currentState!.push<void>(
            MaterialPageRoute<void>(
              builder: (_) => buildMaatFlowsListPreviewForTesting(
                detailBuilderForTemplate: (templateKey) {
                  return (context, dismissDetail) =>
                      buildMaatFlowTemplateDetailPreviewForTesting(
                        templateKey: templateKey,
                        onDismiss: () => unawaited(dismissDetail(null)),
                      );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final card = find.byKey(
          maatFlowCatalogCardKeyForTesting(scenario.templateKey),
        );
        await tester.scrollUntilVisible(
          card,
          280,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(card);
        await tester.pumpAndSettle();

        expect(
          find.byKey(MaatFlowsListDetailReveal.detailSurfaceKey),
          findsOneWidget,
        );
        final back = find.byKey(scenario.backKey);
        expect(back, findsOneWidget);

        // A physical double tap during the reverse animation must not reach
        // the Navigator that owns the outer Flow Studio route.
        await tester.tap(back);
        await tester.tap(back);
        await tester.pumpAndSettle();

        expect(
          find.byKey(MaatFlowsListDetailReveal.detailSurfaceKey),
          findsNothing,
        );
        expect(find.text("Ma'at Flows"), findsOneWidget);
        expect(find.text('Flow Studio hub'), findsNothing);
      },
    );
  }
}
