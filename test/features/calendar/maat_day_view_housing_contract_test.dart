import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/presentation/instrument_event_presentation_frame.dart';

void main() {
  test(
    'all five built-in Ma’at flows have one explicit Day View housing spec',
    () {
      expect(MaatDayViewFlow.values, <MaatDayViewFlow>[
        MaatDayViewFlow.followSky,
        MaatDayViewFlow.offeringTable,
        MaatDayViewFlow.readingHouse,
        MaatDayViewFlow.djed,
        MaatDayViewFlow.kar,
      ]);

      final specs = <MaatDayViewFlow, MaatDayViewHousingSpec>{
        for (final flow in MaatDayViewFlow.values)
          flow: MaatDayViewHousingSpec.forFlow(flow),
      };

      expect(specs[MaatDayViewFlow.followSky]!.initialExtent, .58);
      expect(specs[MaatDayViewFlow.offeringTable]!.initialExtent, .71);
      expect(specs[MaatDayViewFlow.readingHouse]!.initialExtent, .58);
      expect(specs[MaatDayViewFlow.djed]!.initialExtent, .58);
      expect(specs[MaatDayViewFlow.kar]!.initialExtent, .71);
      expect(
        specs.values.map((spec) => spec.hostKey).toSet(),
        hasLength(MaatDayViewFlow.values.length),
      );
    },
  );
}
