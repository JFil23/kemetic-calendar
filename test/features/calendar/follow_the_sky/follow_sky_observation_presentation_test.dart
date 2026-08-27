import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/domain/sky_instrument_data.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/fixtures/follow_sky_observation_presentation_fixture.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/widgets/follow_sky_observation_presentation.dart';

void main() {
  test('Los Angeles fixture retains the verified Full Moon specimen', () {
    final fixture = losAngelesFullMoonPresentationFixture;
    final instrument = fixture.instrument;

    expect(fixture.intention, 'self confidence');
    expect(instrument.rise, DateTime(2026, 8, 27, 19, 17, 18));
    expect(instrument.transit, DateTime(2026, 8, 28, 1, 0, 9));
    expect(instrument.set, DateTime(2026, 8, 28, 6, 51));
    expect(
      instrument.eclipseContacts.map((contact) => contact.kind),
      <LunarEclipseContactKind>[
        LunarEclipseContactKind.p1,
        LunarEclipseContactKind.u1,
        LunarEclipseContactKind.maximum,
        LunarEclipseContactKind.u4,
        LunarEclipseContactKind.p4,
      ],
    );
    expect(instrument.eclipseContacts.first.locallyVisible, isFalse);
    expect(
      instrument.eclipseContacts.skip(1).every((item) => item.locallyVisible),
      isTrue,
    );
    expect(instrument.moonSamples, hasLength(12));
  });

  testWidgets('presentation starts on the HTML mockup hierarchy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          backgroundColor: Colors.black,
          body: FollowSkyObservationPresentation(
            fixture: losAngelesFullMoonPresentationFixture,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('follow-sky-presentation-fixture')),
      findsOneWidget,
    );
    expect(find.text('FOLLOW THE SKY'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('follow-sky-sparkle')),
      findsOneWidget,
    );
    expect(find.textContaining('Full Moon +'), findsOneWidget);
    expect(find.textContaining('Los Angeles'), findsOneWidget);
    expect(find.text('9:12 PM'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('follow-sky-view-time')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('follow-sky-fixture-scrubber')),
      findsNothing,
    );
    expect(find.textContaining('Your block moves'), findsNothing);
    expect(
      find.textContaining('Your view time moves to 9:12 PM.'),
      findsOneWidget,
    );
    expect(find.text('ENDURE'), findsOneWidget);
    expect(find.text('Stay true when conditions change.'), findsOneWidget);
    expect(find.text('“self confidence”'), findsOneWidget);
    expect(find.text('Capture'), findsOneWidget);
    expect(find.text('Reflect'), findsOneWidget);
    expect(find.text('COMPLETION'), findsOneWidget);
    expect(tester.getTopLeft(find.text('ENDURE')).dy, lessThan(760));
    expect(tester.getTopLeft(find.text('YOU CHOSE')).dy, lessThan(760));
    expect(
      find.text('What did staying true to your choice look like tonight?'),
      findsNothing,
    );
  });

  testWidgets('fixture interactions stay local to the presentation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          backgroundColor: Colors.black,
          body: FollowSkyObservationPresentation(
            fixture: losAngelesFullMoonPresentationFixture,
          ),
        ),
      ),
    );

    final hero = find.byKey(const ValueKey<String>('follow-sky-hero-drag'));
    final heroRect = tester.getRect(hero);
    await tester.tapAt(heroRect.center);
    await tester.pump();
    expect(find.text('1:00 AM'), findsOneWidget);
    expect(find.text('Due south'), findsOneWidget);
    expect(
      find.textContaining('Your view time moves to 1:00 AM.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Reflect'));
    await tester.tap(find.text('Reflect'));
    await tester.pump();
    expect(
      find.text('What did staying true to your choice look like tonight?'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Capture'));
    await tester.tap(find.text('Capture'));
    await tester.pump();
    expect(find.text('Photo kept'), findsOneWidget);
    expect(find.text('1 photo · kept with this turning'), findsOneWidget);

    await tester.ensureVisible(find.text('Observed'));
    await tester.tap(find.text('Observed'));
    await tester.pump();
    expect(find.text('KEPT'), findsOneWidget);
  });

  testWidgets(
    'rapid drag tracks the finger while lower content stays mounted',
    (tester) async {
      tester.view.physicalSize = const Size(390, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: Colors.black,
            body: FollowSkyObservationPresentation(
              fixture: losAngelesFullMoonPresentationFixture,
            ),
          ),
        ),
      );

      final lowerContent = tester.element(
        find.byKey(const ValueKey<String>('follow-sky-static-lower-sheet')),
      );
      final heroRect = tester.getRect(
        find.byKey(const ValueKey<String>('follow-sky-hero-drag')),
      );
      final gesture = await tester.startGesture(heroRect.centerLeft);
      for (var index = 1; index <= 24; index++) {
        await gesture.moveTo(
          Offset(
            heroRect.left + heroRect.width * index / 24,
            heroRect.center.dy,
          ),
        );
        await tester.pump(const Duration(milliseconds: 1));
      }
      await gesture.up();
      await tester.pump();

      expect(find.text('6:51 AM'), findsOneWidget);
      expect(
        find.textContaining('Your view time moves to 6:51 AM.'),
        findsOneWidget,
      );
      expect(
        identical(
          lowerContent,
          tester.element(
            find.byKey(const ValueKey<String>('follow-sky-static-lower-sheet')),
          ),
        ),
        isTrue,
      );
      expect(find.text('Stay true when conditions change.'), findsOneWidget);
    },
  );

  testWidgets('ENDURE foreground rises over the lunar instrument', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          backgroundColor: Colors.black,
          body: FollowSkyObservationPresentation(
            fixture: losAngelesFullMoonPresentationFixture,
          ),
        ),
      ),
    );

    final foreground = find.byKey(
      const ValueKey<String>('follow-sky-foreground-layer'),
    );
    final initialTop = tester.getTopLeft(foreground).dy;
    expect(initialTop, greaterThan(320));
    expect(initialTop, lessThan(420));

    await tester.drag(
      find.byKey(const ValueKey<String>('follow-sky-presentation-body')),
      const Offset(0, -330),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(foreground).dy, lessThan(80));
    expect(find.text('ENDURE'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('follow-sky-hero-drag')),
      findsOneWidget,
    );
  });
}
