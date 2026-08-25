import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/maat_list_to_detail_route.dart';

void main() {
  testWidgets('list shell shifts on secondary animation', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: _TransitionHarness()));
    await tester.pump();

    final foreground = find.byKey(
      MaatFlowsListDetailReveal.foregroundTransformKey,
    );
    await tester.tap(find.text('Open detail'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Detail page'), findsOneWidget);
    expect(_translationX(tester.widget<Transform>(foreground)), lessThan(0));
  });

  testWidgets(
    'list shell reveals a stationary detail with exact V11 geometry and timing',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: _TransitionHarness()));
      await tester.pump();

      final chrome = find.byKey(_TransitionHarness.chromeKey);
      final foreground = find.byKey(
        MaatFlowsListDetailReveal.foregroundTransformKey,
      );
      final opacity = find.byKey(
        MaatFlowsListDetailReveal.foregroundOpacityKey,
      );
      final chromeOrigin = tester.getTopLeft(chrome);

      expect(
        MaatFlowsListDetailReveal.transformDuration,
        const Duration(milliseconds: 500),
      );
      expect(
        MaatFlowsListDetailReveal.opacityDuration,
        const Duration(milliseconds: 380),
      );
      expect(MaatFlowsListDetailReveal.outgoingShiftFraction, 0.16);
      expect(find.text('Detail page'), findsNothing);

      await tester.tap(find.text('Open detail'));
      await tester.pump();

      final detail = find.byKey(_TransitionHarness.detailKey);
      expect(detail, findsOneWidget);
      final detailOrigin = tester.getTopLeft(detail);
      expect(
        find.ancestor(of: detail, matching: find.byType(FadeTransition)),
        findsNothing,
      );
      expect(
        find.ancestor(of: detail, matching: find.byType(SlideTransition)),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.getTopLeft(detail), detailOrigin);
      expect(tester.getTopLeft(chrome), chromeOrigin);

      await tester.pump(const Duration(milliseconds: 130));
      expect(tester.widget<Opacity>(opacity).opacity, closeTo(0, 0.0001));
      expect(tester.getTopLeft(detail), detailOrigin);

      await tester.pump(const Duration(milliseconds: 120));
      expect(_translationX(tester.widget<Transform>(foreground)), -64);
      expect(tester.getTopLeft(detail), detailOrigin);
      expect(tester.getTopLeft(chrome), chromeOrigin);
      expect(find.descendant(of: foreground, matching: chrome), findsNothing);

      await tester.tap(find.text('Back to list'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 380));
      expect(tester.widget<Opacity>(opacity).opacity, closeTo(1, 0.0001));
      expect(tester.getTopLeft(detail), detailOrigin);

      await tester.pump(const Duration(milliseconds: 120));
      expect(
        _translationX(tester.widget<Transform>(foreground)),
        closeTo(0, 0.001),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open detail'), findsOneWidget);
      expect(find.text('Detail page'), findsNothing);
      expect(tester.getTopLeft(chrome), chromeOrigin);
    },
  );
}

double _translationX(Transform transform) => transform.transform.storage[12];

class _TransitionHarness extends StatelessWidget {
  const _TransitionHarness();

  static const chromeKey = ValueKey<String>('outer-day-sheet-chrome');
  static const detailKey = ValueKey<String>('stationary-detail-content');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SizedBox(
            key: chromeKey,
            height: 120,
            child: Center(child: Text('Day Sheet chrome')),
          ),
          Expanded(
            child: MaatFlowsListDetailReveal<void>(
              foregroundBuilder: (context, revealDetail) => ColoredBox(
                color: Colors.black,
                child: Center(
                  child: TextButton(
                    onPressed: () {
                      revealDetail(
                        (detailContext) => ColoredBox(
                          key: detailKey,
                          color: Colors.indigo,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Detail page'),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(detailContext).maybePop(),
                                  child: const Text('Back to list'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('Open detail'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
