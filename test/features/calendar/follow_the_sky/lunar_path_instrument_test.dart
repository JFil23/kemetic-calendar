import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/domain/sky_instrument_data.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/widgets/lunar_path_instrument.dart';

void main() {
  testWidgets('Moon is the path control and readout uses real alt/az samples', (
    tester,
  ) async {
    final rise = DateTime(2026, 8, 28, 20);
    final transit = DateTime(2026, 8, 29);
    final set = DateTime(2026, 8, 29, 6);
    final data = LunarPathData(
      viewingWindowStart: rise,
      viewingWindowEnd: set,
      rise: rise,
      transit: transit,
      set: set,
      moonSamples: <SkyPositionSample>[
        SkyPositionSample(at: rise, azimuthDegrees: 90, altitudeDegrees: 0),
        SkyPositionSample(
          at: transit,
          azimuthDegrees: 180,
          altitudeDegrees: 60,
        ),
        SkyPositionSample(at: set, azimuthDegrees: 270, altitudeDegrees: 0),
      ],
      eclipseContacts: <LunarEclipseContact>[
        LunarEclipseContact(
          kind: LunarEclipseContactKind.maximum,
          at: transit,
          azimuthDegrees: 180,
          altitudeDegrees: 60,
          locallyVisible: true,
        ),
      ],
      phaseInstant: DateTime.utc(2026, 8, 28, 4, 18),
      provenance: const SkyInstrumentProvenance(
        source: 'catalog',
        sourceVersion: 'test',
        calculationVersion: 'full-moon-local-v1',
      ),
      visibility: const SkyInstrumentVisibility(
        isLocal: true,
        isTimeFallback: false,
        summary: 'Local sky',
      ),
    );
    DateTime? previewed;
    DateTime? committed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: SizedBox(
            width: 390,
            child: LunarPathInstrument(
              data: data,
              selectedAt: transit,
              onPreview: (value) => previewed = value,
              onCommit: (value) => committed = value,
            ),
          ),
        ),
      ),
    );

    expect(find.text('SKY INSTRUMENT'), findsOneWidget);
    expect(find.text('HIGHEST'), findsOneWidget);
    expect(find.text('60.0°'), findsOneWidget);
    expect(find.text('180° S'), findsOneWidget);
    expect(find.textContaining('MAX'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);

    final instrument = find.byKey(const ValueKey<String>('lunar-path-canvas'));
    final rect = tester.getRect(instrument);
    await tester.tapAt(Offset(rect.left + rect.width * 0.25, rect.center.dy));
    await tester.pump();
    expect(previewed, isNotNull);
    expect(committed, previewed);
    expect(previewed!.isBefore(transit), isTrue);
  });
}
