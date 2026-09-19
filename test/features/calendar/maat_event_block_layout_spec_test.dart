import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/maat_event_block_layout_spec.dart';
import 'package:mobile/features/calendar/maat_flow_identity.dart';

void main() {
  test('four authored cards own one fixed one-hour visual height', () {
    for (final kind in const <MaatFlowKind>[
      MaatFlowKind.offeringTable,
      MaatFlowKind.theDjed,
      MaatFlowKind.readingHouse,
      MaatFlowKind.theKar,
    ]) {
      final spec = MaatEventBlockLayoutSpec.forFlow(kind);
      expect(spec.heightAuthority, MaatEventBlockHeightAuthority.fixedOneHour);
      expect(spec.fixedVisualHeight, 60);
    }
  });

  test('Follow the Sky keeps astronomical duration authority', () {
    final spec = MaatEventBlockLayoutSpec.forFlow(MaatFlowKind.trackSky);
    expect(
      spec.heightAuthority,
      MaatEventBlockHeightAuthority.scheduleDuration,
    );
    expect(spec.fixedVisualHeight, isNull);
  });

  test('shared engine still owns phone, tablet, and overlap widths', () {
    const longTitle =
        'A deliberately long Reading House title that must not widen its lane';
    const readingFlow = FlowData(
      id: 31,
      name: 'The Reading House',
      color: Color(0xFFC99A3D),
      active: true,
      notes: 'mode=gregorian;maat=the-reading-house',
    );
    const notes = <NoteData>[
      NoteData(
        clientEventId: 'reading-long',
        title: longTitle,
        allDay: false,
        start: TimeOfDay(hour: 8, minute: 0),
        end: TimeOfDay(hour: 11, minute: 0),
        flowId: 31,
        behaviorPayload: <String, dynamic>{
          'kind': 'maat_reading_house_sitting',
          'flow_key': 'the-reading-house',
          'event_number': 1,
        },
      ),
      NoteData(
        clientEventId: 'ordinary-overlap',
        title: 'Ordinary overlap',
        allDay: false,
        start: TimeOfDay(hour: 8, minute: 30),
        end: TimeOfDay(hour: 9, minute: 30),
      ),
    ];
    const flowIndex = <int, FlowData>{31: readingFlow};

    final phone = EventLayoutEngine.layoutEventsForDay(
      notes: notes,
      flowIndex: flowIndex,
      availableWidth: 314,
      columnGap: 4,
      textScale: 1,
      day: 1,
    );
    final tablet = EventLayoutEngine.layoutEventsForDay(
      notes: notes,
      flowIndex: flowIndex,
      availableWidth: 692,
      columnGap: 4,
      textScale: 1,
      day: 1,
    );

    expect(phone, hasLength(2));
    expect(phone.map((block) => block.width).toSet(), <double>{155});
    expect(phone.map((block) => block.leftOffset).toSet(), <double>{0, 159});
    expect(tablet, hasLength(2));
    expect(tablet.map((block) => block.width).toSet(), <double>{344});
    expect(tablet.map((block) => block.leftOffset).toSet(), <double>{0, 348});
  });
}
