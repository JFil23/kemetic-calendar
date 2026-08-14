import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_epoch_viewport.dart';

void main() {
  testWidgets('extent epoch preserves semantic anchor without scroll events', (
    tester,
  ) async {
    final correction = CalendarLayoutCorrectionController();
    final scroll = ScrollController(initialScrollOffset: 50);
    final anchor = GlobalKey();
    final height = ValueNotifier<double>(120);
    var scrollNotifications = 0;

    Widget build() => MaterialApp(
      home: SizedBox(
        height: 400,
        child: NotificationListener<ScrollNotification>(
          onNotification: (_) {
            scrollNotifications++;
            return false;
          },
          child: ValueListenableBuilder<double>(
            valueListenable: height,
            builder: (context, changingHeight, child) =>
                CalendarEpochScrollView(
                  controller: scroll,
                  correctionController: correction,
                  slivers: <Widget>[
                    SliverToBoxAdapter(child: SizedBox(height: changingHeight)),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        key: anchor,
                        height: 80,
                        child: const ColoredBox(color: Colors.amber),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 1000)),
                  ],
                ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.byKey(anchor)).dy;
    final beforePixels = scroll.position.pixels;
    scrollNotifications = 0;

    correction.request(
      geometryRevision: 'geometry-2',
      resolveAnchor: () => anchor.currentContext?.findRenderObject(),
    );
    height.value = 260;
    await tester.pump();

    expect(tester.getTopLeft(find.byKey(anchor)).dy, closeTo(before, 0.001));
    expect(scroll.position.pixels, closeTo(beforePixels + 140, 0.001));
    expect(scrollNotifications, 0);
    expect(correction.pending, isNull);
    expect(correction.debugLastCorrection, closeTo(140, 0.001));
  });

  testWidgets('missing anchor fails closed without a scroll correction', (
    tester,
  ) async {
    final correction = CalendarLayoutCorrectionController();
    correction.request(
      geometryRevision: 'geometry-2',
      resolveAnchor: () => null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CalendarEpochScrollView(
          correctionController: correction,
          slivers: const <Widget>[
            SliverToBoxAdapter(child: SizedBox(height: 800)),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(correction.pending, isNull);
    expect(correction.debugMissingAnchorCount, 1);
    expect(correction.debugLastCorrection, 0);
  });
}
