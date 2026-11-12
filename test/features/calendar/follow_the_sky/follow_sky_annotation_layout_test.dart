import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/domain/sky_instrument_data.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/follow_sky_observation_presentation_model.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/follow_sky_view_time_policy.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/widgets/follow_sky_instrument_surface.dart';
import 'package:mobile/features/calendar/follow_the_sky/services/sky_catalog_repository.dart';
import 'package:mobile/features/calendar/follow_the_sky/services/sky_instrument_data_provider.dart';

void main() {
  testWidgets('all meteor previews stay clear around compact breakpoint', (
    tester,
  ) async {
    await (FontLoader(
          'GentiumPlus',
        )..addFont(rootBundle.load('ios/Runner/Fonts/GentiumPlus-Regular.ttf')))
        .load();
    final catalog = await SkyCatalogRepository().load();
    const factory = FollowSkyObservationPresentationModelFactory(
      instrumentProvider: CatalogSkyInstrumentDataProvider(),
    );
    var cases = 0;
    final problems = <String>[];
    for (final event in catalog.materializableEvents) {
      final model = await factory.build(catalog: catalog, skyEventId: event.id);
      if (model.instrument is! MeteorWindowData) continue;
      final controller = FollowSkyViewTimeController(
        track: model.track,
        now: model.track.trackStart.subtract(const Duration(days: 2)),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FollowSkyInstrumentSurface(
            data: model.instrument,
            peakMarker: model.peakMarker,
            controller: controller,
          ),
        ),
      );
      for (final fraction in [0.0, .25, model.track.peakFraction, .75, 1.0]) {
        controller.selectFraction(fraction);
        await tester.pump();
        final paint = tester.widget<CustomPaint>(
          find.descendant(
            of: find.byType(FollowSkyInstrumentSurface),
            matching: find.byType(CustomPaint),
          ),
        );
        for (final width in [
          150.0,
          186.5,
          205.0,
          320.0,
          390.0,
          395.0,
          396.5,
          397.0,
          398.0,
          399.0,
          400.0,
          412.0,
          450.0,
        ]) {
          final size = Size(width, width / 1.49 - 28);
          final canvas = TestRecordingCanvas();
          paint.painter!.paint(canvas, size);
          final labels = <Rect>[];
          for (final call in canvas.invocations) {
            if (call.invocation.memberName != #drawParagraph) continue;
            final paragraph =
                call.invocation.positionalArguments[0] as ui.Paragraph;
            final offset = call.invocation.positionalArguments[1] as Offset;
            final rect = offset & Size(paragraph.longestLine, paragraph.height);
            final key = '${event.id} width=$width fraction=$fraction';
            if (paragraph.didExceedMaxLines) {
              problems.add('$key truncated');
            }
            if (rect.left < 0 ||
                rect.top < 0 ||
                rect.right > size.width ||
                rect.bottom > size.height) {
              problems.add('$key out of bounds $rect');
            }
            if (labels.any((r) => r.inflate(2).overlaps(rect))) {
              problems.add('$key overlap ${labels.last} $rect');
            }
            labels.add(rect);
          }
          expect(
            labels,
            isNotEmpty,
            reason: '${event.id} / $width / $fraction',
          );
          cases++;
        }
      }
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    }
    debugPrint('Exercised $cases meteor preview states.');
    expect(cases, greaterThan(0));
    expect(problems, isEmpty, reason: problems.take(30).join('\n'));
  });
}
