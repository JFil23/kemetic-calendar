import 'dart:collection';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_banner_resolver.dart';
import 'package:mobile/features/calendar/calendar_geometry_snapshot.dart';
import 'package:mobile/features/calendar/calendar_scroll_coordinator.dart';
import 'package:mobile/features/calendar/calendar_section_index.dart';

void main() {
  final month1 = MonthRef(year: 10, month: 1);
  final month2 = MonthRef(year: 10, month: 2);

  test('publishes only fresh non-null banner resolutions', () {
    final rig = _CoordinatorRig(
      snapshot: _snapshot(
        generation: 1,
        sections: [_geometry(month1, 0, 100), _geometry(month2, 100, 200)],
      ),
      offset: 20,
      authoritative: month1,
    );
    addTearDown(rig.dispose);
    final published = <MonthRef>[];
    rig.coordinator.activeBannerMonth.addListener(() {
      published.add(rig.coordinator.activeBannerMonth.value);
    });

    expect(rig.coordinator.activeBannerMonth.value, month1);
    rig.coordinator.noteGeometryPublication();
    rig.flushOneFrame();
    expect(published, isEmpty);

    rig.offset = 120;
    rig.coordinator.noteScroll();
    rig.flushOneFrame();

    expect(rig.coordinator.activeBannerMonth.value, month2);
    expect(published, [month2]);
  });

  test('tracks Gregorian boundaries independently of Kemetic handoffs', () {
    const april = GregorianMonthRef(year: 2026, month: 4);
    const may = GregorianMonthRef(year: 2026, month: 5);
    const june = GregorianMonthRef(year: 2026, month: 6);
    final rig = _CoordinatorRig(
      snapshot: _snapshot(
        generation: 1,
        sections: [
          _geometry(month1, 0, 100, finalDayBlockLeading: 70),
          _geometry(month2, 100, 200, finalDayBlockLeading: 170),
        ],
        gregorianMonthBoundaries: const [
          CalendarGregorianMonthBoundary(month: may, leading: 40),
          CalendarGregorianMonthBoundary(month: june, leading: 140),
        ],
      ),
      offset: 39.999,
      authoritative: month1,
      initialGregorianBannerMonth: april,
    );
    addTearDown(rig.dispose);

    rig.coordinator.noteScroll();
    rig.flushOneFrame();
    expect(rig.coordinator.activeBannerMonth.value, month1);
    expect(rig.coordinator.activeGregorianBannerMonth.value, april);

    rig.offset = 40;
    rig.coordinator.noteScroll();
    rig.flushOneFrame();
    expect(rig.coordinator.activeBannerMonth.value, month1);
    expect(rig.coordinator.activeGregorianBannerMonth.value, may);

    rig.offset = 78;
    rig.coordinator.noteScroll();
    rig.flushOneFrame();
    expect(rig.coordinator.activeBannerMonth.value, month2);
    expect(rig.coordinator.activeGregorianBannerMonth.value, may);

    rig.offset = 140;
    rig.coordinator.noteScroll();
    rig.flushOneFrame();
    expect(rig.coordinator.activeGregorianBannerMonth.value, june);
  });

  test('switches the weekday strip at measured day-row trailing edges', () {
    final row0 = CalendarWeekdayRowRef(month: month1, rowIndex: 0);
    final row1 = CalendarWeekdayRowRef(month: month1, rowIndex: 1);
    final row2 = CalendarWeekdayRowRef(month: month1, rowIndex: 2);
    final nextRow0 = CalendarWeekdayRowRef(month: month2, rowIndex: 0);
    final rig = _CoordinatorRig(
      snapshot: _snapshot(
        generation: 1,
        sections: [
          _geometry(month1, 0, 100, finalDayBlockLeading: 70),
          _geometry(month2, 100, 200, finalDayBlockLeading: 170),
        ],
        weekdayRowBoundaries: [
          CalendarWeekdayRowBoundary(row: row0, trailing: 40),
          CalendarWeekdayRowBoundary(row: row1, trailing: 62),
          CalendarWeekdayRowBoundary(row: row2, trailing: 95),
          CalendarWeekdayRowBoundary(row: nextRow0, trailing: 150),
        ],
      ),
      offset: 61.999,
      authoritative: month1,
    );
    addTearDown(rig.dispose);

    rig.coordinator.noteScroll();
    rig.flushOneFrame();
    expect(rig.coordinator.activeWeekdayRow.value, row1);
    expect(rig.coordinator.activeBannerMonth.value, month1);

    rig.offset = 62;
    rig.coordinator.noteScroll();
    rig.flushOneFrame();
    expect(rig.coordinator.activeWeekdayRow.value, row2);
    expect(rig.coordinator.activeBannerMonth.value, month1);

    rig.offset = 78;
    rig.coordinator.noteScroll();
    rig.flushOneFrame();
    expect(rig.coordinator.activeBannerMonth.value, month2);
    expect(rig.coordinator.activeWeekdayRow.value, row2);

    rig.offset = 94.999;
    rig.coordinator.noteScroll();
    rig.flushOneFrame();
    expect(rig.coordinator.activeWeekdayRow.value, row2);

    rig.offset = 95;
    rig.coordinator.noteScroll();
    rig.flushOneFrame();
    expect(rig.coordinator.activeWeekdayRow.value, nextRow0);

    rig.offset = 94.999;
    rig.coordinator.noteScroll();
    rig.flushOneFrame();
    expect(rig.coordinator.activeWeekdayRow.value, row2);

    rig.offset = 62;
    rig.coordinator.noteScroll();
    rig.flushOneFrame();
    expect(rig.coordinator.activeWeekdayRow.value, row2);

    rig.offset = 61.999;
    rig.coordinator.noteScroll();
    rig.flushOneFrame();
    expect(rig.coordinator.activeWeekdayRow.value, row1);
  });

  test(
    'publishes centered semantic month from the same coalesced snapshot',
    () {
      final rig = _CoordinatorRig(
        snapshot: _snapshot(
          generation: 1,
          sections: [_geometry(month1, 0, 100), _geometry(month2, 100, 200)],
        ),
        offset: 20,
        viewportExtent: 80,
        authoritative: month1,
      );
      addTearDown(rig.dispose);
      final published = <MonthRef>[];
      rig.coordinator.activeCenteredMonth.addListener(() {
        published.add(rig.coordinator.activeCenteredMonth.value);
      });

      rig.coordinator
        ..noteScroll()
        ..noteScroll()
        ..noteScroll();
      rig.flushOneFrame();
      expect(published, isEmpty);

      rig.offset = 70;
      rig.coordinator
        ..noteScroll()
        ..noteScroll();
      rig.flushOneFrame();

      expect(rig.coordinator.activeBannerMonth.value, month1);
      expect(rig.coordinator.activeCenteredMonth.value, month2);
      expect(published, [month2]);
    },
  );

  test('publishes successor at the outgoing final-day block deadband', () {
    final rig = _CoordinatorRig(
      snapshot: _snapshot(
        generation: 1,
        sections: [
          _geometry(month1, 0, 100, finalDayBlockLeading: 70),
          _geometry(month2, 100, 200, finalDayBlockLeading: 170),
        ],
      ),
      offset: 60,
      authoritative: month1,
    );
    addTearDown(rig.dispose);
    rig.coordinator.noteGeometryPublication();
    rig.flushOneFrame();

    rig.offset = 77.999;
    rig.coordinator.noteScroll();
    rig.flushOneFrame();
    expect(rig.coordinator.activeBannerMonth.value, month1);

    rig.offset = 78;
    rig.coordinator.noteScroll();
    rig.flushOneFrame();
    expect(rig.coordinator.activeBannerMonth.value, month2);

    rig.offset = 62.001;
    rig.coordinator.noteScroll();
    rig.flushOneFrame();
    expect(rig.coordinator.activeBannerMonth.value, month2);

    rig.offset = 62;
    rig.coordinator.noteScroll();
    rig.flushOneFrame();
    expect(rig.coordinator.activeBannerMonth.value, month1);
  });

  test('scroll resolves without a new geometry generation', () {
    final rig = _CoordinatorRig(
      snapshot: _snapshot(
        generation: 4,
        sections: [_geometry(month1, 0, 100), _geometry(month2, 100, 200)],
      ),
      offset: 20,
      authoritative: month1,
    );
    addTearDown(rig.dispose);

    rig.coordinator.noteGeometryPublication();
    rig.flushOneFrame();
    expect(rig.coordinator.shadowMonth, month1);

    rig
      ..offset = 120
      ..authoritative = month2;
    rig.coordinator.noteScroll();
    rig.flushOneFrame();

    expect(rig.coordinator.shadowMonth, month2);
    expect(rig.coordinator.debugCommittedSampleCount, 2);
    expect(rig.snapshot.generation, 4);
  });

  test('stationary geometry preserves incumbent without deadband', () {
    final rig = _CoordinatorRig(
      snapshot: _snapshot(
        generation: 1,
        sections: [_geometry(month1, 0, 100), _geometry(month2, 100, 200)],
      ),
      offset: 90,
      authoritative: month1,
    );
    addTearDown(rig.dispose);
    rig.coordinator.noteGeometryPublication();
    rig.flushOneFrame();

    rig
      ..snapshot = _snapshot(
        generation: 2,
        sections: [_geometry(month1, 0, 80), _geometry(month2, 80, 200)],
      )
      ..authoritative = month2;
    rig.coordinator.noteGeometryPublication();
    rig.flushOneFrame();

    expect(rig.snapshot.ownerAt(90), month2);
    expect(rig.coordinator.shadowMonth, month1);
    expect(
      rig.coordinator.trace.last.resolutionMode,
      CalendarBannerResolutionMode.geometryOnlyAtUnchangedOffset,
    );
  });

  test('rejects a result from a stale geometry generation', () {
    late _CoordinatorRig rig;
    var replaced = false;
    rig = _CoordinatorRig(
      snapshot: _snapshot(generation: 1, sections: [_geometry(month1, 0, 100)]),
      offset: 20,
      authoritative: month1,
      legacyReader: (_) {
        if (!replaced) {
          replaced = true;
          rig.snapshot = _snapshot(
            generation: 2,
            sections: [_geometry(month1, 0, 100)],
          );
        }
        return month1;
      },
    );
    addTearDown(rig.dispose);

    rig.coordinator.noteScroll();
    rig.flushOneFrame();

    expect(rig.coordinator.debugStaleGenerationRejectionCount, 1);
    expect(rig.coordinator.debugCommittedSampleCount, 0);
    expect(rig.coordinator.trace, isEmpty);
  });

  test('rejects a result from a stale scroll serial', () {
    late _CoordinatorRig rig;
    var advanced = false;
    rig = _CoordinatorRig(
      snapshot: _snapshot(generation: 1, sections: [_geometry(month1, 0, 100)]),
      offset: 20,
      authoritative: month1,
      legacyReader: (_) {
        if (!advanced) {
          advanced = true;
          rig.coordinator.noteScroll();
        }
        return month1;
      },
    );
    addTearDown(rig.dispose);

    rig.coordinator.noteScroll();
    rig.flushOneFrame();

    expect(rig.coordinator.debugStaleScrollSerialRejectionCount, 1);
    expect(rig.coordinator.debugCommittedSampleCount, 0);
    expect(rig.pendingFrameCount, 1);
  });

  test('coalesces repeated scroll input into one frame resolution', () {
    final rig = _CoordinatorRig(
      snapshot: _snapshot(generation: 1, sections: [_geometry(month1, 0, 100)]),
      offset: 20,
      authoritative: month1,
    );
    addTearDown(rig.dispose);

    rig.coordinator
      ..noteScroll()
      ..noteScroll()
      ..noteScroll();

    expect(rig.pendingFrameCount, 1);
    expect(rig.coordinator.latestScrollSampleSerial, 3);
    rig.flushOneFrame();
    expect(rig.coordinator.debugResolutionAttemptCount, 1);
  });

  test('preserves distinct live and settled samples in one input frame', () {
    final rig = _CoordinatorRig(
      snapshot: _snapshot(generation: 1, sections: [_geometry(month1, 0, 100)]),
      offset: 20,
      authoritative: month1,
    );
    addTearDown(rig.dispose);

    rig.coordinator
      ..noteScroll()
      ..noteScrollEnd();
    expect(rig.pendingFrameCount, 1);

    rig.flushOneFrame();
    expect(rig.coordinator.debugCommittedSampleCount, 1);
    expect(rig.pendingFrameCount, 1);

    rig.flushOneFrame();
    expect(rig.coordinator.debugCommittedSampleCount, 2);
  });

  test('keeps detail trace bounded and cumulative counts intact', () {
    final rig = _CoordinatorRig(
      snapshot: _snapshot(
        generation: 1,
        sections: [_geometry(month1, 0, 100), _geometry(month2, 100, 200)],
      ),
      offset: 120,
      authoritative: month1,
      traceCapacity: 2,
    );
    addTearDown(rig.dispose);

    for (final offset in <double>[120, 130, 140]) {
      rig.offset = offset;
      rig.coordinator.noteScroll();
      rig.flushOneFrame();
    }

    expect(rig.coordinator.trace, hasLength(2));
    expect(
      rig.coordinator.divergenceCounts[CalendarShadowDivergenceCategory
          .centerVsLeadingEdgePolicy],
      3,
    );
  });

  test('classifies following-month interstitial from snapshot geometry', () {
    final rig = _CoordinatorRig(
      snapshot: _snapshot(
        generation: 1,
        sections: [
          _geometry(month1, 0, 100),
          _geometry(month2, 100, 200, bodyLeading: 130),
        ],
      ),
      offset: 110,
      authoritative: month1,
    );
    addTearDown(rig.dispose);

    rig.coordinator.noteScroll();
    rig.flushOneFrame();

    expect(
      rig.coordinator.trace.single.divergenceCategory,
      CalendarShadowDivergenceCategory.interstitialOwnership,
    );
  });

  test('live and scroll-end samples use the same resolver policy', () {
    final rig = _CoordinatorRig(
      snapshot: _snapshot(
        generation: 1,
        sections: [_geometry(month1, 0, 100), _geometry(month2, 100, 200)],
      ),
      offset: 20,
      authoritative: month1,
    );
    addTearDown(rig.dispose);
    rig.coordinator.noteScroll();
    rig.flushOneFrame();

    rig.offset = 120;
    rig.coordinator.noteScroll();
    rig.flushOneFrame();
    final live = rig.coordinator.trace.last;

    rig.coordinator.noteScrollEnd();
    rig.flushOneFrame();
    final settled = rig.coordinator.trace.last;

    expect(live.reason, CalendarShadowSampleReason.scroll);
    expect(settled.reason, CalendarShadowSampleReason.scrollEnd);
    expect(settled.resolutionMode, live.resolutionMode);
    expect(settled.shadowMonth, live.shadowMonth);
  });

  test('banner authority cannot mutate page or adjacent consumers', () {
    final source = File(
      'lib/features/calendar/calendar_scroll_coordinator.dart',
    ).readAsStringSync();

    expect(source, contains('ValueListenable<MonthRef> get activeBannerMonth'));
    expect(
      source,
      contains(
        'ValueListenable<GregorianMonthRef> get activeGregorianBannerMonth',
      ),
    );
    expect(source, isNot(contains('setState(')));
    expect(source, isNot(contains('_setView(')));
    expect(source, isNot(contains('_handlePortraitMonthChanged(')));
    expect(source, isNot(contains('_scheduleCalendarRestorationSave(')));
    expect(source, isNot(contains('_scheduleRenderedViewportHydration(')));
    expect(source, isNot(contains('notifyListeners(')));
    expect(source, isNot(contains('print(')));
    expect(source, isNot(contains('debugPrint(')));
  });

  test('scroll semantic publication cannot rebuild the calendar page', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final setView = RegExp(
      r'void _setView\([\s\S]*?\n  }\n\n  /// ✅ Save view state',
    ).firstMatch(source)?.group(0);

    expect(setView, isNotNull);
    expect(setView, isNot(contains('setState(')));
    expect(source, isNot(contains('_computeCenteredMonthLiveCandidate')));
    expect(source, isNot(contains('_computeCenteredMonthPrecisely')));
    expect(source, isNot(contains('_updateCenteredMonthWide')));
  });
}

final class _CoordinatorRig {
  _CoordinatorRig({
    required this.snapshot,
    required this.offset,
    required this.authoritative,
    this.viewportExtent = 80,
    this.initialGregorianBannerMonth = const GregorianMonthRef(
      year: 2026,
      month: 1,
    ),
    CalendarLegacyCandidateReader? legacyReader,
    int traceCapacity = CalendarScrollCoordinator.defaultTraceCapacity,
  }) : _legacyReader = legacyReader {
    coordinator = CalendarScrollCoordinator(
      initialBannerMonth: authoritative ?? MonthRef(year: 0, month: 1),
      initialGregorianBannerMonth: initialGregorianBannerMonth,
      scheduleAfterFrame: _scheduled.addLast,
      readSnapshot: () => snapshot,
      readScrollOffset: () => offset,
      readViewportExtent: () => viewportExtent,
      readAuthoritativeMonth: () => authoritative,
      readLegacyCandidate: _legacyReader ?? (_) => authoritative,
      traceCapacity: traceCapacity,
    );
  }

  CalendarGeometrySnapshot snapshot;
  double offset;
  double viewportExtent;
  final GregorianMonthRef initialGregorianBannerMonth;
  MonthRef? authoritative;
  final CalendarLegacyCandidateReader? _legacyReader;
  final ListQueue<void Function()> _scheduled = ListQueue();
  late final CalendarScrollCoordinator coordinator;

  int get pendingFrameCount => _scheduled.length;

  void flushOneFrame() {
    _scheduled.removeFirst()();
  }

  void dispose() {
    coordinator.dispose();
  }
}

CalendarGeometrySnapshot _snapshot({
  required int generation,
  required List<CalendarSectionGeometry> sections,
  List<CalendarGregorianMonthBoundary> gregorianMonthBoundaries = const [],
  List<CalendarWeekdayRowBoundary> weekdayRowBoundaries = const [],
}) {
  return CalendarGeometrySnapshot(
    generation: generation,
    sections: sections,
    gregorianMonthBoundaries: gregorianMonthBoundaries,
    weekdayRowBoundaries: weekdayRowBoundaries,
  );
}

CalendarSectionGeometry _geometry(
  MonthRef month,
  num leading,
  num trailing, {
  num? bodyLeading,
  num? finalDayBlockLeading,
}) {
  return CalendarSectionGeometry(
    month: month,
    extent: CalendarCanonicalExtent(
      leading: leading.toDouble(),
      trailing: trailing.toDouble(),
    ),
    bodyLeading: bodyLeading?.toDouble(),
    finalDayBlockLeading: finalDayBlockLeading?.toDouble(),
  );
}
