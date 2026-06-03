import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
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

    testWidgets('detail sheets match day view action placement', (
      tester,
    ) async {
      await _setLandscapeViewport(tester);
      EventItem? sharedEvent;

      await tester.pumpWidget(
        _LandscapePagerHarness(
          notesForDay: (ky, km, kd) => kd == 1
              ? const [
                  NoteData(
                    clientEventId: 'landscape-note',
                    title: 'Landscape note',
                    allDay: false,
                    start: TimeOfDay(hour: 0, minute: 0),
                    end: TimeOfDay(hour: 1, minute: 0),
                  ),
                ]
              : const <NoteData>[],
          onShareNote: (event) async {
            sharedEvent = event;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Landscape note'));
      await tester.pumpAndSettle();

      expect(find.text('Make to-do'), findsOneWidget);
      expect(find.text('Share Note'), findsNothing);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Share Note'), findsOneWidget);
      await tester.tap(find.text('Share Note'));
      await tester.pumpAndSettle();

      expect(sharedEvent, isNotNull);
      expect(sharedEvent!.title, 'Landscape note');
      expect(sharedEvent!.clientEventId, 'landscape-note');
    });
  });

  group('Calendar month grid tablet layout', () {
    testWidgets(
      'tablet landscape event chips stay inside day cells and overflow cleanly',
      (tester) async {
        await _setTabletLandscapeViewport(tester);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: buildCalendarMonthCardLayoutForTesting(
                  kYear: 6267,
                  kMonth: 1,
                  notesForDay: (day) => day == 4
                      ? List<NoteData>.generate(
                          6,
                          (index) => NoteData(
                            title: 'Tablet event ${index + 1}',
                            allDay: false,
                            start: TimeOfDay(hour: 8 + index, minute: 0),
                            end: TimeOfDay(hour: 9 + index, minute: 0),
                            manualColor: Colors.purple,
                          ),
                        )
                      : const <NoteData>[],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Tablet event 1'), findsOneWidget);
        expect(find.text('Tablet event 2'), findsOneWidget);
        expect(find.text('Tablet event 3'), findsOneWidget);
        expect(find.text('Tablet event 4'), findsOneWidget);
        expect(find.text('Tablet event 5'), findsNothing);
        expect(find.text('Tablet event 6'), findsNothing);
        expect(find.text('+2'), findsOneWidget);

        final dayCell = tester.getRect(
          find.byKey(const ValueKey<String>('k:6267-1-4|K')),
        );
        for (final label in const [
          'Tablet event 1',
          'Tablet event 2',
          'Tablet event 3',
          'Tablet event 4',
          '+2',
        ]) {
          final rect = tester.getRect(find.text(label));
          expect(rect.top, greaterThanOrEqualTo(dayCell.top));
          expect(rect.bottom, lessThanOrEqualTo(dayCell.bottom));
        }
      },
    );
  });
}

class _LandscapePagerHarness extends StatelessWidget {
  const _LandscapePagerHarness({
    this.notesForDay,
    this.onVisibleMonthCommitted,
    this.onShareNote,
  });

  final List<NoteData> Function(int ky, int km, int kd)? notesForDay;
  final void Function(int ky, int km)? onVisibleMonthCommitted;
  final Future<void> Function(EventItem event)? onShareNote;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: LandscapeMonthPager(
          initialKy: 6267,
          initialKm: 4,
          showGregorian: false,
          notesForDay: notesForDay ?? ((_, _, _) => const <NoteData>[]),
          flowIndex: const <int, FlowData>{},
          getMonthName: (km) => 'Month $km',
          onVisibleMonthCommitted: onVisibleMonthCommitted,
          onShareNote: onShareNote,
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

Future<void> _setTabletLandscapeViewport(WidgetTester tester) async {
  final binding = tester.binding;
  await binding.setSurfaceSize(const Size(1194, 834));
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
