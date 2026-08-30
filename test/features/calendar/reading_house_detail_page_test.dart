import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_thirty_day_calendar.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_detail_page.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';

const _captureVisualCheckpoint = bool.fromEnvironment(
  'CAPTURE_READING_HOUSE_VISUAL_CHECKPOINT',
);
const _captureSurfaceKey = ValueKey<String>(
  'reading-house-visual-capture-surface',
);

void main() {
  Future<void> pumpHouse(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: _captureSurfaceKey,
          child: ReadingHouseDetailPage(
            key: ValueKey<Size>(size),
            timezone: TrackSkyTimeZone.pacific,
            initialStartDate: DateTime(2026, 9, 14),
          ),
        ),
      ),
    );
    await tester.pump();
    Object? heroLoadError;
    await tester.runAsync(
      () => precacheImage(
        const AssetImage(ReadingHouseDetailTokens.heroAsset),
        tester.element(find.byType(ReadingHouseDetailPage)),
        onError: (exception, stackTrace) => heroLoadError = exception,
      ),
    );
    expect(heroLoadError, isNull);
    await tester.pumpAndSettle();
  }

  Finder houseScrollable() => find
      .descendant(
        of: find.byKey(const ValueKey<String>('reading-house-scroll')),
        matching: find.byType(Scrollable),
      )
      .first;

  Future<void> jumpHouseScroll(WidgetTester tester, double offset) async {
    final position = tester.state<ScrollableState>(houseScrollable()).position;
    position.jumpTo(offset.clamp(0, position.maxScrollExtent).toDouble());
    await tester.pumpAndSettle();
  }

  testWidgets('uses the shared detail architecture and revised visual copy', (
    tester,
  ) async {
    await pumpHouse(tester);

    expect(find.byType(MaatFlowDetailShell), findsOneWidget);
    expect(find.byType(MaatFlowDetailHero), findsOneWidget);
    expect(find.byType(MaatFlowDetailDock), findsOneWidget);
    expect(find.byType(MaatFlowThirtyDayCalendar), findsOneWidget);
    final heroImage = tester.widget<Image>(
      find.byKey(const ValueKey<String>('reading-house-hero-image')),
    );
    expect(heroImage.image, isA<AssetImage>());
    expect(
      (heroImage.image as AssetImage).assetName,
      ReadingHouseDetailTokens.heroAsset,
    );
    expect(heroImage.fit, BoxFit.cover);
    expect(heroImage.alignment, ReadingHouseDetailTokens.heroImageAlignment);
    expect(find.text('The Reading\nHouse'), findsOneWidget);
    expect(find.text('A house kept around one book.'), findsOneWidget);
    expect(find.text('BEFORE THE CALENDAR'), findsOneWidget);
    expect(find.text('Set the house'), findsNothing);
    expect(find.text('No invites yet'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Hold this house'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('reading-house-thirty-day-calendar')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('reading-house-hold')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('reading-house-held')),
      findsOneWidget,
    );
    expect(find.text('Held in your flows'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('solo, doors, and reader invite remain local visual state', (
    tester,
  ) async {
    await pumpHouse(tester);
    await jumpHouseScroll(tester, 650);
    await tester.tap(find.text('Solo study'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('reading-house-readers')),
      findsNothing,
    );

    await tester.tap(find.text('With readers'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('reading-house-readers')),
      findsOneWidget,
    );

    await jumpHouseScroll(tester, 820);
    await tester.tap(find.text('Open · Commons'));
    await tester.pumpAndSettle();
    expect(
      find.text('Community members can discover this house in the Commons.'),
      findsOneWidget,
    );

    final invite = find.byKey(
      const ValueKey<String>('reading-house-invite-reader'),
    );
    await jumpHouseScroll(tester, 1050);
    await tester.tap(invite);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('reading-house-invite-sheet')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('reading-house-reader-search')),
      'Amina',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Amina Reed'));
    await tester.pumpAndSettle();
    expect(find.text('Amina Reed'), findsOneWidget);
    expect(find.text('1 invite pending'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sitting menu exposes editing and local placement actions', (
    tester,
  ) async {
    await pumpHouse(tester);
    final firstSitting = find.byKey(
      const ValueKey<String>('reading-house-sitting-1'),
    );
    await jumpHouseScroll(tester, 2000);
    await tester.tap(firstSitting);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('reading-house-sitting-sheet')),
      findsOneWidget,
    );
    expect(find.text('Edit reading section & prompt'), findsOneWidget);
    expect(find.text('Choose date & time'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('reading-house-edit-sitting')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('reading-house-sitting-editor')),
      findsOneWidget,
    );
    expect(find.text('PRIVATE PROMPT'), findsOneWidget);

    await tester.tap(find.text('←  Sitting'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('reading-house-place-sitting')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('reading-house-sitting-placement')),
      findsOneWidget,
    );
    expect(find.text('Save date & time'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('reading-house-save-placement')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('· 7:00 PM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow phone keeps the shared page free of layout overflow', (
    tester,
  ) async {
    await pumpHouse(tester, size: const Size(340, 700));
    final scroll = find.byKey(const ValueKey<String>('reading-house-scroll'));
    await tester.drag(scroll, const Offset(0, -1400));
    await tester.pumpAndSettle();
    await tester.drag(scroll, const Offset(0, -1400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('captures Reading House visual checkpoints', (tester) async {
    if (!_captureVisualCheckpoint) return;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    await _loadVisualFonts();

    for (final fixture in const <({String name, Size size})>[
      (name: '390', size: Size(390, 844)),
      (name: '340', size: Size(340, 700)),
    ]) {
      await pumpHouse(tester, size: fixture.size);
      await expectLater(
        find.byKey(_captureSurfaceKey),
        matchesGoldenFile('/tmp/reading-house-${fixture.name}-hero.png'),
      );

      await jumpHouseScroll(tester, 650);
      await expectLater(
        find.byKey(_captureSurfaceKey),
        matchesGoldenFile('/tmp/reading-house-${fixture.name}-setup.png'),
      );

      await jumpHouseScroll(tester, 1400);
      await expectLater(
        find.byKey(_captureSurfaceKey),
        matchesGoldenFile('/tmp/reading-house-${fixture.name}-calendar.png'),
      );

      await jumpHouseScroll(tester, 2000);
      await expectLater(
        find.byKey(_captureSurfaceKey),
        matchesGoldenFile('/tmp/reading-house-${fixture.name}-sittings.png'),
      );
    }
    expect(tester.takeException(), isNull);
  });
}

Future<void> _loadVisualFonts() async {
  final gentium = FontLoader('GentiumPlus')
    ..addFont(rootBundle.load('ios/Runner/Fonts/GentiumPlus-Regular.ttf'))
    ..addFont(rootBundle.load('ios/Runner/Fonts/GentiumPlus-Bold.ttf'));
  final cormorant = FontLoader('CormorantGaramond')
    ..addFont(rootBundle.load('ios/Runner/Fonts/CormorantGaramond-Regular.ttf'))
    ..addFont(rootBundle.load('ios/Runner/Fonts/CormorantGaramond-Italic.ttf'))
    ..addFont(rootBundle.load('ios/Runner/Fonts/CormorantGaramond-Medium.ttf'))
    ..addFont(
      rootBundle.load('ios/Runner/Fonts/CormorantGaramond-MediumItalic.ttf'),
    )
    ..addFont(
      rootBundle.load('ios/Runner/Fonts/CormorantGaramond-SemiBold.ttf'),
    );
  final materialIcons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  final hieroglyphs = FontLoader('Noto Sans Egyptian Hieroglyphs')
    ..addFont(
      rootBundle.load(
        'ios/Runner/Fonts/NotoSansEgyptianHieroglyphs-Regular.ttf',
      ),
    );
  await Future.wait(<Future<void>>[
    gentium.load(),
    cormorant.load(),
    materialIcons.load(),
    hieroglyphs.load(),
  ]);
}
