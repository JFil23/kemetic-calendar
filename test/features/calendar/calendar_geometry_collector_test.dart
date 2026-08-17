import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_geometry_collector.dart';
import 'package:mobile/features/calendar/calendar_geometry_snapshot.dart';
import 'package:mobile/features/calendar/calendar_section_index.dart';

void main() {
  testWidgets(
    'publishes past-negative center-zero and future-positive extents',
    (tester) async {
      final collector = CalendarGeometryCollector();
      addTearDown(collector.dispose);
      final centerKey = GlobalKey();

      await tester.pumpWidget(
        _host(
          collector: collector,
          child: SizedBox(
            height: 300,
            child: CustomScrollView(
              center: centerKey,
              anchor: 0,
              slivers: [
                SliverToBoxAdapter(
                  child: CalendarGeometrySection(
                    month: MonthRef(year: 0, month: 13),
                    child: const SizedBox(height: 80),
                  ),
                ),
                SliverToBoxAdapter(
                  key: centerKey,
                  child: CalendarGeometrySection(
                    month: MonthRef(year: 1, month: 1),
                    child: const SizedBox(height: 100),
                  ),
                ),
                SliverToBoxAdapter(
                  child: CalendarGeometrySection(
                    month: MonthRef(year: 1, month: 2),
                    child: const SizedBox(height: 120),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final sections = collector.snapshot!.sections;
      expect(sections, hasLength(3));
      expect(
        sections.map((section) => section.month),
        orderedEquals([
          MonthRef(year: 0, month: 13),
          MonthRef(year: 1, month: 1),
          MonthRef(year: 1, month: 2),
        ]),
      );
      expect(sections[0].extent.leading, closeTo(-80, 0.001));
      expect(sections[0].extent.trailing, closeTo(0, 0.001));
      expect(sections[1].extent.leading, closeTo(0, 0.001));
      expect(sections[1].extent.trailing, closeTo(100, 0.001));
      expect(sections[2].extent.leading, closeTo(100, 0.001));
      expect(sections[2].extent.trailing, closeTo(220, 0.001));
    },
  );

  testWidgets('normalizes multiple before-center years chronologically', (
    tester,
  ) async {
    final collector = CalendarGeometryCollector();
    addTearDown(collector.dispose);
    final centerKey = GlobalKey();

    Widget year(int year) {
      return Column(
        children: [
          for (var month = 1; month <= 13; month++)
            CalendarGeometrySection(
              month: MonthRef(year: year, month: month),
              child: const SizedBox(height: 10),
            ),
        ],
      );
    }

    await tester.pumpWidget(
      _host(
        collector: collector,
        child: SizedBox(
          height: 300,
          child: CustomScrollView(
            center: centerKey,
            anchor: 0,
            slivers: [
              SliverList.builder(
                itemCount: 2,
                itemBuilder: (context, index) => year(1 - index),
              ),
              SliverToBoxAdapter(key: centerKey, child: year(2)),
            ],
          ),
        ),
      ),
    );

    final sections = collector.snapshot!.sections;
    expect(sections, hasLength(39));
    expect(sections.first.month, MonthRef(year: 0, month: 1));
    expect(sections[12].month, MonthRef(year: 0, month: 13));
    expect(sections[13].month, MonthRef(year: 1, month: 1));
    expect(sections[25].month, MonthRef(year: 1, month: 13));
    expect(sections[26].month, MonthRef(year: 2, month: 1));
    expect(sections.last.month, MonthRef(year: 2, month: 13));
    for (var index = 1; index < sections.length; index++) {
      expect(
        sections[index].extent.leading,
        closeTo(sections[index - 1].extent.trailing, 0.001),
      );
    }
  });

  testWidgets('normalizes a past-side final-day handoff monotonically', (
    tester,
  ) async {
    final collector = CalendarGeometryCollector();
    addTearDown(collector.dispose);
    final centerKey = GlobalKey();
    final pastMonth = MonthRef(year: 0, month: 13);

    await tester.pumpWidget(
      _host(
        collector: collector,
        child: SizedBox(
          height: 300,
          child: CustomScrollView(
            center: centerKey,
            anchor: 0,
            slivers: [
              SliverToBoxAdapter(
                child: CalendarGeometrySection(
                  month: pastMonth,
                  child: Column(
                    children: [
                      const SizedBox(height: 70),
                      CalendarGeometryFinalDayBlock(
                        month: pastMonth,
                        child: const SizedBox(height: 20),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                key: centerKey,
                child: CalendarGeometrySection(
                  month: MonthRef(year: 1, month: 1),
                  child: const SizedBox(height: 100),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final geometry = collector.snapshot!.geometryFor(pastMonth)!;
    expect(geometry.extent, _extent(-100, 0));
    expect(geometry.finalDayBlockLeading, closeTo(-30, 0.001));
  });

  testWidgets('coalesces a layout burst into one atomic generation', (
    tester,
  ) async {
    final collector = CalendarGeometryCollector();
    addTearDown(collector.dispose);
    final height = ValueNotifier<double>(80);
    addTearDown(height.dispose);
    final published = <int>[];
    collector.addListener(() {
      published.add(collector.snapshot!.generation);
    });

    await tester.pumpWidget(
      _host(
        collector: collector,
        child: ValueListenableBuilder<double>(
          valueListenable: height,
          builder: (context, value, _) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: CalendarGeometrySection(
                    month: MonthRef(year: 1, month: 1),
                    child: SizedBox(height: value),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    final publicationsBefore = collector.debugPublicationCount;

    height.value = 90;
    height.value = 100;
    height.value = 110;
    await tester.pump();

    expect(collector.debugPublicationCount, publicationsBefore + 1);
    expect(collector.snapshot!.sections.single.extent.length, 110);
    expect(published, orderedEquals(List.generate(published.length, (i) => i)));
  });

  testWidgets('publishes month-body boundary for interstitial diagnostics', (
    tester,
  ) async {
    final collector = CalendarGeometryCollector();
    addTearDown(collector.dispose);
    final month = MonthRef(year: 1, month: 1);

    await tester.pumpWidget(
      _host(
        collector: collector,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: CalendarGeometrySection(
                month: month,
                child: Column(
                  children: [
                    const SizedBox(height: 30),
                    CalendarGeometryMonthBody(
                      month: month,
                      child: const SizedBox(height: 70),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final geometry = collector.snapshot!.geometryFor(month)!;
    expect(collector.debugMountedBodyCount, 1);
    expect(geometry.bodyLeading, closeTo(30, 0.001));
    expect(geometry.activationIsInLeadingInterstitial(20), isTrue);
    expect(geometry.activationIsInLeadingInterstitial(30), isFalse);
  });

  testWidgets('publishes final-day handoff in the same atomic snapshot', (
    tester,
  ) async {
    final collector = CalendarGeometryCollector();
    addTearDown(collector.dispose);
    final month = MonthRef(year: 1, month: 1);

    await tester.pumpWidget(
      _host(
        collector: collector,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: CalendarGeometrySection(
                month: month,
                child: Column(
                  children: [
                    const SizedBox(height: 30),
                    CalendarGeometryMonthBody(
                      month: month,
                      child: Column(
                        children: [
                          const SizedBox(height: 40),
                          CalendarGeometryFinalDayBlock(
                            month: month,
                            child: const SizedBox(height: 20),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final snapshot = collector.snapshot!;
    final geometry = snapshot.geometryFor(month)!;
    expect(collector.debugMountedSectionCount, 1);
    expect(collector.debugMountedBodyCount, 1);
    expect(collector.debugMountedFinalDayBlockCount, 1);
    expect(geometry.extent, _extent(0, 100));
    expect(geometry.bodyLeading, closeTo(30, 0.001));
    expect(geometry.finalDayBlockLeading, closeTo(70, 0.001));
  });

  testWidgets('publishes inline Gregorian month boundaries atomically', (
    tester,
  ) async {
    final collector = CalendarGeometryCollector();
    addTearDown(collector.dispose);
    final month = MonthRef(year: 1, month: 1);
    const may = GregorianMonthRef(year: 2026, month: 5);

    await tester.pumpWidget(
      _host(
        collector: collector,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: CalendarGeometrySection(
                month: month,
                child: Column(
                  children: [
                    const SizedBox(height: 30),
                    CalendarGeometryGregorianMonthBoundary(
                      month: may,
                      child: const SizedBox(height: 20),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final snapshot = collector.snapshot!;
    expect(collector.debugMountedGregorianMonthBoundaryCount, 1);
    expect(snapshot.gregorianMonthBoundaries, hasLength(1));
    expect(
      snapshot.gregorianMonthBoundaries.single.leading,
      closeTo(30, 0.001),
    );
    expect(snapshot.gregorianMonthAt(29.999), may.predecessor);
    expect(snapshot.gregorianMonthAt(30), may);
  });

  testWidgets('publishes decan weekday boundaries atomically', (tester) async {
    final collector = CalendarGeometryCollector();
    addTearDown(collector.dispose);
    final month = MonthRef(year: 1, month: 1);

    await tester.pumpWidget(
      _host(
        collector: collector,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: CalendarGeometrySection(
                month: month,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    CalendarGeometryWeekdayRowBoundary(
                      row: CalendarWeekdayRowRef(month: month, rowIndex: 0),
                      child: const SizedBox(height: 20),
                    ),
                    const SizedBox(height: 20),
                    CalendarGeometryWeekdayRowBoundary(
                      row: CalendarWeekdayRowRef(month: month, rowIndex: 1),
                      child: const SizedBox(height: 20),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final snapshot = collector.snapshot!;
    expect(collector.debugMountedWeekdayRowBoundaryCount, 2);
    expect(snapshot.weekdayRowBoundaries, hasLength(2));
    expect(snapshot.weekdayRowBoundaries[0].leading, closeTo(20, 0.001));
    expect(snapshot.weekdayRowBoundaries[1].leading, closeTo(60, 0.001));
    expect(
      snapshot.weekdayRowAt(59.999),
      CalendarWeekdayRowRef(month: month, rowIndex: 0),
    );
    expect(
      snapshot.weekdayRowAt(60),
      CalendarWeekdayRowRef(month: month, rowIndex: 1),
    );
  });

  testWidgets('does not publish or schedule continuously while idle', (
    tester,
  ) async {
    final collector = CalendarGeometryCollector();
    addTearDown(collector.dispose);
    await tester.pumpWidget(
      _host(
        collector: collector,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: CalendarGeometrySection(
                month: MonthRef(year: 1, month: 1),
                child: const SizedBox(height: 100),
              ),
            ),
          ],
        ),
      ),
    );
    final publications = collector.debugPublicationCount;
    final scheduled = collector.debugScheduledPublicationCount;

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(collector.debugPublicationCount, publications);
    expect(collector.debugScheduledPublicationCount, scheduled);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('scroll-only layout does not republish unchanged geometry', (
    tester,
  ) async {
    final collector = CalendarGeometryCollector();
    final scrollController = ScrollController();
    addTearDown(collector.dispose);
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      _host(
        collector: collector,
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: CalendarGeometrySection(
                month: MonthRef(year: 1, month: 1),
                child: const SizedBox(height: 3000),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    final publications = collector.debugPublicationCount;
    final scheduled = collector.debugScheduledPublicationCount;

    scrollController.jumpTo(240);
    await tester.pump();
    await tester.pump();

    expect(collector.debugPublicationCount, publications);
    expect(collector.debugScheduledPublicationCount, scheduled);
  });

  testWidgets('rejects an invalid candidate without replacing last snapshot', (
    tester,
  ) async {
    final collector = CalendarGeometryCollector();
    addTearDown(collector.dispose);
    late StateSetter update;
    var reversed = false;

    await tester.pumpWidget(
      _host(
        collector: collector,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return SizedBox(
                    height: 200,
                    child: Stack(
                      children: [
                        Positioned(
                          top: reversed ? 100 : 0,
                          child: CalendarGeometrySection(
                            month: MonthRef(year: 1, month: 1),
                            child: SizedBox(
                              width: 100,
                              height: reversed ? 101 : 100,
                            ),
                          ),
                        ),
                        Positioned(
                          top: reversed ? 0 : 100,
                          child: CalendarGeometrySection(
                            month: MonthRef(year: 1, month: 2),
                            child: SizedBox(
                              width: 100,
                              height: reversed ? 101 : 100,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    final coherent = collector.snapshot;
    expect(coherent, isNotNull);

    update(() => reversed = true);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(collector.debugRejectedPublicationCount, 1);
    expect(collector.debugLastRejection, isA<ArgumentError>());
    expect(collector.snapshot, same(coherent));
  });

  testWidgets('lazy traversal keeps the mounted registry bounded', (
    tester,
  ) async {
    const index = CalendarSectionIndex();
    final collector = CalendarGeometryCollector();
    addTearDown(collector.dispose);
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    var peakMounted = 0;

    await tester.pumpWidget(
      _host(
        collector: collector,
        child: SizedBox(
          height: 300,
          child: CustomScrollView(
            controller: scrollController,
            cacheExtent: 200,
            slivers: [
              SliverList.builder(
                itemCount: 500,
                itemBuilder: (context, item) {
                  return CalendarGeometrySection(
                    month: index.monthAtOrdinal(13 + item),
                    child: const SizedBox(height: 100),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    peakMounted = collector.debugMountedSectionCount;

    for (final fraction in <double>[0.25, 0.5, 0.75, 1]) {
      scrollController.jumpTo(
        scrollController.position.maxScrollExtent * fraction,
      );
      await tester.pump();
      peakMounted = peakMounted < collector.debugMountedSectionCount
          ? collector.debugMountedSectionCount
          : peakMounted;
    }

    expect(peakMounted, lessThan(30));
    expect(collector.debugMountedSectionCount, lessThan(30));
    expect(collector.snapshot!.sections.length, lessThan(30));
    expect(
      collector.snapshot!.sections.last.month,
      index.monthAtOrdinal(13 + 499),
    );
  });
}

Widget _host({
  required CalendarGeometryCollector collector,
  required Widget child,
}) {
  return MaterialApp(
    home: Scaffold(
      body: CalendarGeometryCollectorScope(collector: collector, child: child),
    ),
  );
}

CalendarCanonicalExtent _extent(num leading, num trailing) {
  return CalendarCanonicalExtent(
    leading: leading.toDouble(),
    trailing: trailing.toDouble(),
  );
}
