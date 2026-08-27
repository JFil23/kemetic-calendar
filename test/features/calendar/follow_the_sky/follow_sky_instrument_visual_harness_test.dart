import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/domain/sky_instrument_data.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/fixtures/follow_sky_observation_presentation_fixture.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/follow_sky_observation_presentation_model.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/widgets/follow_sky_observation_presentation.dart';
import 'package:mobile/features/calendar/follow_the_sky/services/sky_catalog_repository.dart';
import 'package:mobile/features/calendar/follow_the_sky/services/sky_instrument_data_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final gentium = FontLoader('GentiumPlus')
      ..addFont(rootBundle.load('ios/Runner/Fonts/GentiumPlus-Regular.ttf'))
      ..addFont(rootBundle.load('ios/Runner/Fonts/GentiumPlus-Bold.ttf'));
    final cormorant = FontLoader('CormorantGaramond')
      ..addFont(
        rootBundle.load('ios/Runner/Fonts/CormorantGaramond-Regular.ttf'),
      )
      ..addFont(
        rootBundle.load('ios/Runner/Fonts/CormorantGaramond-Italic.ttf'),
      )
      ..addFont(
        rootBundle.load('ios/Runner/Fonts/CormorantGaramond-Medium.ttf'),
      )
      ..addFont(
        rootBundle.load('ios/Runner/Fonts/CormorantGaramond-MediumItalic.ttf'),
      );
    await Future.wait(<Future<void>>[gentium.load(), cormorant.load()]);
  });

  testWidgets('renders one review image for each sealed instrument family', (
    tester,
  ) async {
    final catalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );
    const factory = FollowSkyObservationPresentationModelFactory(
      instrumentProvider: CatalogSkyInstrumentDataProvider(),
    );
    final models = <SkyInstrumentFamily, FollowSkyObservationPresentationModel>{
      SkyInstrumentFamily.lunarPath: losAngelesFullMoonPresentationFixture,
    };
    for (final event in catalog.materializableEvents) {
      final model = await factory.build(
        catalog: catalog,
        skyEventId: event.id,
        intention: 'test intention',
      );
      models.putIfAbsent(model.instrument.family, () => model);
    }
    expect(models.keys.toSet(), SkyInstrumentFamily.values.toSet());

    final output = Directory(
      '${Directory.systemTemp.path}/follow-sky-instrument-visuals',
    )..createSync(recursive: true);
    await tester.binding.setSurfaceSize(const Size(390, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final family in SkyInstrumentFamily.values) {
      final model = models[family]!;
      final captureKey = GlobalKey();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          theme: ThemeData.dark(),
          home: RepaintBoundary(
            key: captureKey,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: FollowSkyObservationPresentation(
                model: model,
                now: () => model.instrument.viewingWindowStart
                    .subtract(const Duration(days: 2))
                    .toUtc(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final hero = find.byKey(const ValueKey<String>('follow-sky-hero-drag'));
      final heroRect = tester.getRect(hero);
      await tester.tapAt(
        Offset(heroRect.left + heroRect.width * 0.18, heroRect.center.dy),
      );
      await tester.pump();
      expect(
        find.byKey(ValueKey<String>('follow-sky-peak-marker-${family.name}')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      final boundary =
          captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        return byteData!.buffer.asUint8List();
      });
      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(1000));
      File('${output.path}/${family.name}.png').writeAsBytesSync(bytes);
    }
  });
}
