import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/day_key.dart';
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

    test('reuses Heriu Renpet card data for year-suffixed keys', () {
      final canonical = KemeticDayData.getInfoForDay('epagomenal_1_1');
      final yearSpecific = KemeticDayData.getInfoForDay('epagomenal_1_2026');

      expect(canonical, isNotNull);
      expect(yearSpecific, same(canonical));
    });

    test('validates the leap-year sixth Heriu Renpet date label', () {
      expect(
        KemeticDayData.calculateGregorianDate('epagomenal_6_3'),
        isNot('Invalid Epagomenal Day'),
      );
      expect(
        KemeticDayData.calculateGregorianDate('epagomenal_6_2'),
        'Invalid Epagomenal Day',
      );
    });

    test('uses normalized visible date labels for all standard day cards', () {
      expect(KemeticDayData.dayInfoMap.length, 365);

      final oldStyleLabels = <String>[];
      for (var month = 1; month <= 12; month++) {
        for (var day = 1; day <= 30; day++) {
          final key = kemeticDayKey(month, day);
          final dayInfo = KemeticDayData.getInfoForDay(key);

          expect(dayInfo, isNotNull, reason: 'Missing day card for $key');
          if (RegExp(r'Day \d+ of|– Day').hasMatch(dayInfo!.kemeticDate)) {
            oldStyleLabels.add('$key => ${dayInfo.kemeticDate}');
          }
        }
      }

      for (var day = 1; day <= 5; day++) {
        final key = 'epagomenal_${day}_1';
        final dayInfo = KemeticDayData.getInfoForDay(key);

        expect(dayInfo, isNotNull, reason: 'Missing day card for $key');
        if (RegExp(r'Day \d+ of|– Day').hasMatch(dayInfo!.kemeticDate)) {
          oldStyleLabels.add('$key => ${dayInfo.kemeticDate}');
        }
      }

      expect(oldStyleLabels, isEmpty);
    });

    test('keeps day card rhythms short and rejects rollback copy', () {
      final rollbackPhrases = <String>[
        'The ground is cleared',
        'An unbegun structure cannot',
        'unbegun structure',
        'ground is cleared',
      ];
      final overLimitRhythms = <String>[];
      final rollbackMatches = <String>[];

      for (final entry in KemeticDayData.dayInfoMap.entries) {
        final rhythm = entry.value.cosmicContext.trim();
        final wordCount = _wordCount(rhythm);
        if (wordCount > 60) {
          overLimitRhythms.add('${entry.key} => $wordCount words');
        }
        for (final phrase in rollbackPhrases) {
          if (rhythm.contains(phrase)) {
            rollbackMatches.add('${entry.key} contains "$phrase"');
          }
        }
      }

      expect(overLimitRhythms, isEmpty);
      expect(rollbackMatches, isEmpty);

      final hathor23 = KemeticDayData.getInfoForDay('hathor_23_3');
      expect(hathor23, isNotNull);
      expect(
        hathor23!.cosmicContext.trim(),
        '''
Kemite masons roughed the block before they polished it.
First cuts: broad, approximate, correct in proportion but rough in surface.
The eye was on structure, not shine.

To wait for perfection before beginning
is to let the silt dry and the planting window close.
'''
            .trim(),
      );
      expect(_wordCount(hathor23.cosmicContext), 44);
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
        expect(find.text('△ The Day’s Rhythm'), findsOneWidget);
        expect(find.text('△ Cosmic Context'), findsNothing);

        final decanRichText = tester
            .widgetList<RichText>(find.byType(RichText))
            .firstWhere((widget) => widget.text.toPlainText().contains('ꜥḥꜣy'));
        final textSpan = decanRichText.text as TextSpan;
        expect(decanRichText.strutStyle?.height, 1.35);
        expect(textSpan.style?.height, 1.35);
      },
    );

    testWidgets('opens in a constrained overlay without scrollbar assertions', (
      tester,
    ) async {
      final dayInfo = KemeticDayData.getInfoForDay('hathor_13_2');
      expect(dayInfo, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(
              child: SizedBox(
                width: 360,
                height: 320,
                child: KemeticDayDropdown(
                  dayInfo: dayInfo!,
                  onClose: () {},
                  dayKey: 'hathor_13_2',
                  kYear: 2,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollbar), findsOneWidget);
    });
  });
}

int _wordCount(String text) {
  return RegExp(
    r"[A-Za-z0-9À-ÖØ-öø-ÿĀ-žḀ-ỿꜢꜣ]+(?:[-’'][A-Za-z0-9À-ÖØ-öø-ÿĀ-žḀ-ỿꜢꜣ]+)*",
  ).allMatches(text).length;
}
