import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/kemetic_day_info.dart';

void main() {
  group('KemeticDayData decan resolution', () {
    test('resolves canonical decan names for overridden month keys', () {
      expect(KemeticDayData.resolveDecanNameFromKey('paophi_6_1'), 'ꜥḥꜣy');
      expect(
        KemeticDayData.resolveDecanNameFromKey('sefbedet_16_2'),
        'ḥry-ib ḫnty-ḥr',
      );
      expect(
        KemeticDayData.resolveDecanNameFromKey('henti_27_3'),
        'sbꜣ ḥr-sꜣḥ',
      );
      expect(
        KemeticDayData.resolveDecanNameFromKey('mswtRa_24_3'),
        'sbꜣ msḥtjw ḫt',
      );
    });

    test('builds non-empty day info decan names for overridden month keys', () {
      final paophi = KemeticDayData.getInfoForDay('paophi_6_1');
      final sefBedet = KemeticDayData.getInfoForDay('sefbedet_16_2');
      final henti = KemeticDayData.getInfoForDay('henti_27_3');
      final mesutRa = KemeticDayData.getInfoForDay('mswtRa_24_3');

      expect(paophi, isNotNull);
      expect(paophi!.decanName, contains('ꜥḥꜣy'));
      expect(sefBedet, isNotNull);
      expect(sefBedet!.decanName, contains('ḥry-ib ḫnty-ḥr'));
      expect(henti, isNotNull);
      expect(henti!.decanName, contains('sbꜣ ḥr-sꜣḥ'));
      expect(mesutRa, isNotNull);
      expect(mesutRa!.decanName, contains('sbꜣ msḥtjw ḫt'));
    });
  });

  group('KemeticDayDropdown', () {
    testWidgets(
      'shows canonical decan name and applies consistent info line height',
      (tester) async {
        final dayInfo = KemeticDayData.getInfoForDay('paophi_6_1');
        expect(dayInfo, isNotNull);

        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: Center(
                child: KemeticDayDropdown(
                  dayInfo: dayInfo!,
                  onClose: () {},
                  dayKey: 'paophi_6_1',
                  kYear: 2,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('ꜥḥꜣy', findRichText: true), findsWidgets);

        final decanRichText = tester
            .widgetList<RichText>(find.byType(RichText))
            .firstWhere((widget) => widget.text.toPlainText().contains('ꜥḥꜣy'));
        final textSpan = decanRichText.text as TextSpan;
        expect(decanRichText.strutStyle?.height, 1.35);
        expect(textSpan.style?.height, 1.35);
      },
    );
  });
}
