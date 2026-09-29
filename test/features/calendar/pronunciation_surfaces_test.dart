import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/day_key.dart';
import 'package:mobile/data/maat_guidance_model.dart';
import 'package:mobile/data/maat_guidance_repo.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/pronunciation/pronunciation_catalog.dart';
import 'package:mobile/features/calendar/pronunciation/pronunciation_service.dart';
import 'package:mobile/features/maat_guidance/maat_guidance_detail_page.dart';
import 'package:mobile/widgets/kemetic_day_info.dart';
import 'package:mobile/widgets/pronounce_icon_button.dart';
import 'pronunciation_service_test.dart' show Audio, Fallback;

class OpeningRepo implements MaatGuidanceDataSource {
  @override
  Future<MaatGuidanceDelivery?> getById(String id) async =>
      MaatGuidanceDelivery.fromJson({
        'id': id,
        'kind': 'decan_opening',
        'decan_period_key': '2026-05-29:2026-06-07:3-2',
        'body_text': 'Existing opening text',
        'payload': {'decan_short_name': 'ꜣpdw'},
      });
  @override
  Future<void> ack({
    required String deliveryId,
    required String action,
    Map<String, dynamic>? metadata,
  }) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('day cards map every decan and birthday without reading labels', (
    tester,
  ) async {
    for (var month = 1; month <= 13; month++) {
      for (final day in month == 13 ? [1, 2, 3, 4, 5] : [1, 11, 21]) {
        final key = month == 13
            ? 'epagomenal_${day}_1'
            : kemeticDayKey(month, day);
        final info = KemeticDayData.getInfoForDay(key);
        expect(info, isNotNull, reason: key);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KemeticDayDropdown(
                dayInfo: info!,
                onClose: () {},
                dayKey: key,
                kYear: 2,
              ),
            ),
          ),
        );
        await tester.pump();
        final keys = tester
            .widgetList<PronounceIconButton>(find.byType(PronounceIconButton))
            .map((w) => w.pronunciationKey)
            .toSet();
        expect(keys, {
          PronunciationKey.month(month),
          PronunciationKey.forDay(month, day),
        }, reason: key);
        expect(tester.takeException(), isNull);
      }
    }
  });
  testWidgets(
    'scroll/focused month and decan speakers preserve structural identities',
    (tester) async {
      for (final focused in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: focused
                    ? buildFocusedCalendarMonthGridForTesting(
                        kYear: 2,
                        kMonth: 6,
                        notesForDay: (_) => [],
                      )
                    : buildCalendarMonthCardLayoutForTesting(
                        kYear: 2,
                        kMonth: 6,
                        notesForDay: (_) => [],
                      ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widgetList<PronounceIconButton>(find.byType(PronounceIconButton))
              .map((w) => w.pronunciationKey)
              .toSet(),
          {
            PronunciationKey.month(6),
            for (var d = 1; d <= 3; d++) PronunciationKey.decan(6, d),
          },
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets('Decan Opening uses period identity and retains its text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MaatGuidanceDetailPage(
          deliveryId: 'fixture',
          repo: OpeningRepo(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Existing opening text'), findsOneWidget);
    expect(
      tester
          .widget<PronounceIconButton>(find.byType(PronounceIconButton))
          .pronunciationKey,
      PronunciationKey.decan(3, 2),
    );
  });
  testWidgets('speaker tap does not navigate and covering route stops owner', (
    tester,
  ) async {
    final a = Audio()..playGate = Completer<void>();
    final s = PronunciationService(audio: a, fallback: Fallback());
    var navigation = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => GestureDetector(
              onTap: () {
                navigation++;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('Next')),
                  ),
                );
              },
              child: Row(
                children: [
                  const Expanded(child: Text('Name')),
                  PronounceIconButton(
                    pronunciationKey: PronunciationKey.month(1),
                    color: Colors.amber,
                    service: s,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Play pronunciation'));
    await tester.pump();
    expect(navigation, 0);
    expect(s.activeKey.value, PronunciationKey.month(1));
    await tester.tap(find.text('Name'));
    await tester.pumpAndSettle();
    expect(navigation, 1);
    expect(s.activeKey.value, isNull);
    a.playGate!.complete();
  });
}
