import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/landscape_month_view.dart';

void main() {
  group('LandscapeMonthPager rotation handoff', () {
    testWidgets(
      'reports the current month when disposed after a settled swipe',
      (tester) async {
        await _setLandscapeViewport(tester);

        ({int ky, int km})? committedMonth;

        await tester.pumpWidget(
          _LandscapePagerHarness(
            onVisibleMonthCommitted: (ky, km) {
              committedMonth = (ky: ky, km: km);
            },
          ),
        );
        await tester.pumpAndSettle();

        final controller = _landscapePagerController(tester);
        controller.jumpToPage(controller.initialPage + 1);
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        expect(committedMonth, isNotNull);
        expect(committedMonth!.ky, 6267);
        expect(committedMonth!.km, 5);
      },
    );

    testWidgets(
      'reports the rounded visible month when disposed during a swipe',
      (tester) async {
        await _setLandscapeViewport(tester);

        ({int ky, int km})? committedMonth;

        await tester.pumpWidget(
          _LandscapePagerHarness(
            onVisibleMonthCommitted: (ky, km) {
              committedMonth = (ky: ky, km: km);
            },
          ),
        );
        await tester.pumpAndSettle();

        final controller = _landscapePagerController(tester);
        controller.jumpTo(
          controller.position.pixels +
              (controller.position.viewportDimension * 0.6),
        );
        await tester.pump();

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        expect(committedMonth, isNotNull);
        expect(committedMonth!.ky, 6267);
        expect(committedMonth!.km, 5);
      },
    );
  });
}

class _LandscapePagerHarness extends StatelessWidget {
  const _LandscapePagerHarness({this.onVisibleMonthCommitted});

  final void Function(int ky, int km)? onVisibleMonthCommitted;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: LandscapeMonthPager(
          initialKy: 6267,
          initialKm: 4,
          showGregorian: false,
          notesForDay: (_, __, ___) => const <NoteData>[],
          flowIndex: const <int, FlowData>{},
          getMonthName: (km) => 'Month $km',
          onVisibleMonthCommitted: onVisibleMonthCommitted,
        ),
      ),
    );
  }
}

Future<void> _setLandscapeViewport(WidgetTester tester) async {
  final binding = tester.binding;
  await binding.setSurfaceSize(const Size(1000, 420));
  binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  addTearDown(() async {
    await binding.setSurfaceSize(null);
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });
}

PageController _landscapePagerController(WidgetTester tester) {
  final pageView = tester.widget<PageView>(
    find.descendant(
      of: find.byType(LandscapeMonthPager),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is PageView && widget.scrollDirection == Axis.horizontal,
      ),
    ),
  );
  return pageView.controller!;
}
