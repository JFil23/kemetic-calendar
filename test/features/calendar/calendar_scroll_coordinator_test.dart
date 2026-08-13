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

  test('coordinator source contains no authoritative mutation writer', () {
    final source = File(
      'lib/features/calendar/calendar_scroll_coordinator.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('setState(')));
    expect(source, isNot(contains('_setView(')));
    expect(source, isNot(contains('_handlePortraitMonthChanged(')));
    expect(source, isNot(contains('notifyListeners(')));
    expect(source, isNot(contains('print(')));
    expect(source, isNot(contains('debugPrint(')));
  });
}

final class _CoordinatorRig {
  _CoordinatorRig({
    required this.snapshot,
    required this.offset,
    required this.authoritative,
    CalendarLegacyCandidateReader? legacyReader,
    int traceCapacity = CalendarScrollCoordinator.defaultTraceCapacity,
  }) : _legacyReader = legacyReader {
    coordinator = CalendarScrollCoordinator(
      scheduleAfterFrame: _scheduled.addLast,
      readSnapshot: () => snapshot,
      readScrollOffset: () => offset,
      readAuthoritativeMonth: () => authoritative,
      readLegacyCandidate: _legacyReader ?? (_) => authoritative,
      traceCapacity: traceCapacity,
    );
  }

  CalendarGeometrySnapshot snapshot;
  double offset;
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
}) {
  return CalendarGeometrySnapshot(generation: generation, sections: sections);
}

CalendarSectionGeometry _geometry(
  MonthRef month,
  num leading,
  num trailing, {
  num? bodyLeading,
}) {
  return CalendarSectionGeometry(
    month: month,
    extent: CalendarCanonicalExtent(
      leading: leading.toDouble(),
      trailing: trailing.toDouble(),
    ),
    bodyLeading: bodyLeading?.toDouble(),
  );
}
