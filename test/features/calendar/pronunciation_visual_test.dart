import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/widgets/kemetic_day_info.dart';
import 'package:mobile/features/maat_guidance/maat_guidance_detail_page.dart';
import 'pronunciation_surfaces_test.dart' show OpeningRepo;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/features/calendar/pronunciation/pronunciation_catalog.dart';
import 'package:mobile/features/calendar/scrolling_calendar_month_header.dart';
import 'package:mobile/features/reflections/decan_reflection_skin.dart';
import 'package:mobile/widgets/pronounce_icon_button.dart';

void main() {
  testWidgets('speaker visual contract fits narrow and enlarged layouts', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final entry in {
        'GentiumPlus': 'ios/Runner/Fonts/GentiumPlus-Regular.ttf',
        'CormorantGaramond': 'ios/Runner/Fonts/CormorantGaramond-Regular.ttf',
        'Roboto': 'ios/Runner/Fonts/Inter-Variable.ttf',
        'Inter': 'ios/Runner/Fonts/Inter-Variable.ttf',
        'Ahem': 'ios/Runner/Fonts/Inter-Variable.ttf',
        'NotoSans': 'ios/Runner/Fonts/Inter-Variable.ttf',
        'Noto Sans Egyptian Hieroglyphs':
            'ios/Runner/Fonts/NotoSansEgyptianHieroglyphs-Regular.ttf',
        'MaterialIcons':
            '/usr/local/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      }.entries) {
        final file = File(entry.value);
        if (!file.existsSync()) continue;
        final loader = FontLoader(entry.key)
          ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
        await loader.load();
      }
    });
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final scale in [1.0, 1.5]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 850),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: RepaintBoundary(
                key: const Key('capture'),
                child: Column(
                  children: [
                    ScrollingCalendarMonthHeader(
                      month: getMonthById(13),
                      yearLabel: 'Year 2',
                      showGregorian: false,
                      gregorianMonthName: 'March',
                      gregorianYearLabel: '2026',
                      weekdayLabels: const ['1', '2', '3', '4', '5'],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: DecanFolioMasthead(
                        title: 'ẖry-ḥbt n ḥr',
                        dateRange: '2026-09-21 → 2026-09-30',
                        pronunciationKey: PronunciationKey.decan(12, 3),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: PronunciationLabel(
                        pronunciationKey: PronunciationKey.decan(6, 2),
                        child: const Text(
                          'ḥry-ib knmw',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final playing in [false, true])
                          PronunciationControl(
                            color: Colors.amber,
                            size: 22,
                            playing: playing,
                            onPressed: () {},
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('capture')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/tmp/haw-pronunciation-visual-$scale.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    final fixtures = <String, Widget>{
      'scroll-month': SingleChildScrollView(
        child: buildCalendarMonthCardLayoutForTesting(
          kYear: 2,
          kMonth: 6,
          notesForDay: (_) => [],
        ),
      ),
      'focused-month': SingleChildScrollView(
        child: buildFocusedCalendarMonthGridForTesting(
          kYear: 2,
          kMonth: 6,
          notesForDay: (_) => [],
        ),
      ),
      'day-card': Center(
        child: KemeticDayDropdown(
          dayInfo: KemeticDayData.getInfoForDay('thoth_11_2')!,
          onClose: () {},
          dayKey: 'thoth_11_2',
          kYear: 2,
        ),
      ),
      'epagomenal-card': Center(
        child: KemeticDayDropdown(
          dayInfo: KemeticDayData.getInfoForDay('epagomenal_5_1')!,
          onClose: () {},
          dayKey: 'epagomenal_5_1',
          kYear: 2,
        ),
      ),
      'month-info': buildFocusedMonthDetailForTesting(kYear: 2, kMonth: 6),
      'decan-opening': MaatGuidanceDetailPage(
        deliveryId: 'visual-fixture',
        repo: OpeningRepo(),
      ),
    };
    for (final fixture in fixtures.entries) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 850),
              textScaler: TextScaler.linear(1.5),
            ),
            child: RepaintBoundary(
              key: const Key('surface-capture'),
              child: Scaffold(
                backgroundColor: Colors.black,
                body: fixture.value,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: fixture.key);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('surface-capture')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/tmp/haw-pronunciation-${fixture.key}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
