import 'dart:io';

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

  test(
    'Day View keeps fixture view time disconnected from calendar movement',
    () {
      final source = File(
        'lib/features/calendar/day_view.dart',
      ).readAsStringSync();
      final fixtureBranchStart = source.indexOf(
        'final Widget observation = isPresentationFixture',
      );
      final fixtureBranchEnd = source.indexOf(
        ': FollowSkyObservationSheet(',
        fixtureBranchStart,
      );
      final fixtureBranch = source.substring(
        fixtureBranchStart,
        fixtureBranchEnd,
      );

      expect(fixtureBranch, isNot(contains('onMoveFollowSkyEventTime')));
      expect(fixtureBranch, isNot(contains('onCommitStartTime')));
    },
  );

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
            now: _beforeRise,
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
    expect(find.text('Capture'), findsNothing);
    expect(find.byIcon(Icons.camera_alt_outlined), findsNothing);
    expect(find.text('Reflect'), findsOneWidget);
    final reflectAction = find.ancestor(
      of: find.text('Reflect'),
      matching: find.byType(InkWell),
    );
    expect(reflectAction, findsOneWidget);
    expect(tester.getSize(reflectAction).width, greaterThan(300));
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
            now: _beforeRise,
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
    expect(find.text('Capture'), findsNothing);
    expect(find.text('Photo kept'), findsNothing);
    expect(find.textContaining('Same reflection either way'), findsNothing);
    expect(
      find.textContaining('Dictation becomes editable text'),
      findsNothing,
    );
    expect(find.textContaining('This one belongs to tonight'), findsNothing);
    expect(
      find.textContaining('automatically kept in today’s Journal'),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const ValueKey<String>('follow-sky-presentation-body')),
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Observed'));
    await tester.pump();
    expect(find.text('KEPT'), findsOneWidget);
  });

  testWidgets('compact sheet host keeps the instrument clear and body usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 317);
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
            now: _beforeRise,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('FOLLOW THE SKY'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('follow-sky-hero-drag')),
      findsOneWidget,
    );

    final heroRect = tester.getRect(
      find.byKey(const ValueKey<String>('follow-sky-hero-drag')),
    );
    await tester.tapAt(heroRect.center);
    await tester.pump();
    expect(find.text('1:00 AM'), findsOneWidget);

    await tester.ensureVisible(find.text('Reflect'));
    await tester.pumpAndSettle();
    expect(find.text('Reflect'), findsOneWidget);
    expect(find.text('Capture'), findsNothing);
    expect(tester.takeException(), isNull);
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
              now: _beforeRise,
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

  testWidgets('foreground clamps at its bottom and reveals the hero downward', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 317);
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
            now: _beforeRise,
          ),
        ),
      ),
    );

    final foreground = find.byKey(
      const ValueKey<String>('follow-sky-foreground-layer'),
    );
    final presentationBody = find.byKey(
      const ValueKey<String>('follow-sky-presentation-body'),
    );
    final scrollView = tester.widget<CustomScrollView>(presentationBody);
    expect(scrollView.physics, isA<ClampingScrollPhysics>());

    final initialRect = tester.getRect(foreground);
    expect(initialRect.top, greaterThan(300));

    await tester.drag(presentationBody, const Offset(0, -2000));
    await tester.pumpAndSettle();

    final terminalRect = tester.getRect(foreground);
    expect(terminalRect.top, lessThan(0));
    expect(terminalRect.bottom, closeTo(317, 0.1));
    expect(tester.getRect(find.text('Observed')).bottom, lessThan(317));

    await tester.drag(presentationBody, const Offset(0, -500));
    await tester.pumpAndSettle();

    final clampedRect = tester.getRect(foreground);
    expect(clampedRect.top, closeTo(terminalRect.top, 0.1));
    expect(clampedRect.bottom, closeTo(terminalRect.bottom, 0.1));

    await tester.drag(presentationBody, const Offset(0, 2000));
    await tester.pumpAndSettle();

    final revealedRect = tester.getRect(foreground);
    expect(revealedRect.top, closeTo(initialRect.top, 0.1));
    expect(revealedRect.top, greaterThan(terminalRect.top));
    expect(find.text('ENDURE'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('follow-sky-hero-drag')),
      findsOneWidget,
    );
  });

  testWidgets('live tracking opens at 1:55 AM and advances by the minute', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 8, 28, 8, 55, 30);
    await tester.pumpWidget(_presentationHarness(now: () => now));

    expect(find.text('1:55 AM'), findsOneWidget);
    expect(
      find.textContaining('Your view time moves to 1:55 AM.'),
      findsOneWidget,
    );
    final lowerContent = tester.element(
      find.byKey(const ValueKey<String>('follow-sky-static-lower-sheet')),
    );

    now = DateTime.utc(2026, 8, 28, 8, 56);
    await tester.pump(const Duration(seconds: 30));

    expect(find.text('1:56 AM'), findsOneWidget);
    expect(
      identical(
        lowerContent,
        tester.element(
          find.byKey(const ValueKey<String>('follow-sky-static-lower-sheet')),
        ),
      ),
      isTrue,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('manual drag stops live time and reopening resets the session', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 8, 28, 8, 55, 30);
    await tester.pumpWidget(_presentationHarness(now: () => now));

    final hero = find.byKey(const ValueKey<String>('follow-sky-hero-drag'));
    await tester.tapAt(tester.getRect(hero).center);
    await tester.pump();
    expect(find.text('1:00 AM'), findsOneWidget);

    now = DateTime.utc(2026, 8, 28, 9, 5);
    await tester.pump(const Duration(minutes: 10));
    expect(find.text('1:00 AM'), findsOneWidget);
    expect(find.text('2:05 AM'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    now = DateTime.utc(2026, 8, 28, 8, 57);
    await tester.pumpWidget(_presentationHarness(now: () => now));

    expect(find.text('1:57 AM'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

DateTime _beforeRise() => DateTime.utc(2026, 8, 28, 1);

Widget _presentationHarness({required DateTime Function() now}) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      backgroundColor: Colors.black,
      body: FollowSkyObservationPresentation(
        fixture: losAngelesFullMoonPresentationFixture,
        now: now,
      ),
    ),
  );
}
