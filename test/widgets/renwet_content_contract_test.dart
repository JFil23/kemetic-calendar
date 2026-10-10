import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/daily_reflection_question.dart';
import 'package:mobile/data/commons_models.dart';
import 'package:mobile/data/commons_question_selection.dart';
import 'package:mobile/widgets/kemetic_day_info.dart';

// Immutable fingerprints of the approved three attached Renwet FINAL_v2 files, not
// generated from runtime data. Covers every field and each complete decan flow.
const approvedCards = <String>[
  'f4ae67d865f6eac4c6b3deb1329594ac6c50744cf33ed9190b9ced9259454ff2',
  'e174bd400b932eb3b3bdc965eef604c6cabfcb8697a8bcca8d1a8ca585c26146',
  '3376ba4fed57e076a2271040de055cd8b59703e214b62eb9882c92bdcc0ccd35',
  '2c2918f1f41d4b17a1be2e02747064b1fd6720f98af2642e31f5002574e634da',
  'bee9adb251a8c0d5098abf9e713e5032eb078feb0c112b5a77a87c3333eb2e44',
  '2480defe89b370d3c7970dd7dd94ad67986dd92beff9edeca4e90891edec1421',
  '85bd4c4f53fda61786fed7606a9c6cbf2ba36e423e0c9bf38e2210033127c914',
  'e943d6cf85a5cba46e3e7a8637c2302d4c250a27a2d354cde54b3d3e23f0f7c3',
  'ce2713511d2491898fe22825b7d500023ca897ddcffd239ed28d4794fa3a68fc',
  '649fd5f703018780554f395d6e31340db35c791447972431077aad5faf2cc50e',
  '42ac50a8fe7ca67d6ab94a752b24ec71ef62a670487ccfc065d1e7f28c85010f',
  '5adbf32ab76f48665a2d89f564f348a8f51216f3a7dd3de39f6c509b3d30361c',
  '8665201a50c464bcad80d232150d605c448de56919152ebd66d80ebc0db99dd4',
  'f4e1df5ce70b7e20a8bb75f6f746aeb1b2b7c0f48ddeb8caf16db96d6fef97b9',
  '30b91977ce310c075fe0d59bfb4bff2f32c5de4db90d0803e494bc045bd0ed08',
  'bc60f053b573fbe36ca3e2fb43fc5a6074945ccb5de5b36e7725ab7c7fa8c1ad',
  '19477bf641afccd777a5014c9536470f147b0116e9a023742c14c426e193732a',
  'c03942049774e87c6357a7761b0e21055ff4671fdd18951b988f2c4a2c117ac4',
  'a08418be9085edce74a774e411eabbc94dbbd880a2c2e656cd0554482b619e32',
  'cc71464c93bd4be20df3259f1cabda910145bf67cb0e2880b22e3b85f8d113ef',
  '6fdf6d144d419016df76c6b1583d29070fb2e2422d2476a8443a3e7711f6f0b9',
  '18afd61b84a71900d4baea0fe0f6ce09889492525c3c02fbcba89c2ba9971baa',
  '48fa9bf20fb3c6378ec079c0856f4fc1e4ceb24819a0202e7da0a2566c37116b',
  '1df16f6d4da0dc824f495167f844412c2b9cc7e8b7133bf28e768bf22d410665',
  'c13968b8a3780a8df54cba34dcbe64c9de659f93dde176977b44f8f51d478e12',
  'ca97d281b42838ce678b6b7e62cb8c0a872398b0d5abbaefc8dc7a0479c92a1b',
  '59af196eccacdbda1ad875c06d6beb2e33a5e15373d876c724b852321481eaa4',
  '272698c395ca5df5243e6d0be1b8c4a1529157270c21eb6bb64d550cc34c0fd6',
  'f5217a01981255d6063160da3f45b24b2ade666220699c4f320c5d30025eb564',
  'ebda953673be4f4f32932b2edd43f97290dccff3ea3f583961c4e865538b960d',
];

void main() {
  test('all 30 cards reproduce the approved final reference exactly', () {
    for (var day = 1; day <= 30; day++) {
      final key = 'renwet_${day}_${(day - 1) ~/ 10 + 1}';
      final c = KemeticDayData.getInfoForDay(key)!;
      final fields = {
        'kemeticDate': c.kemeticDate,
        'season': c.season,
        'month': c.month,
        'decanName': c.decanName,
        'starCluster': c.starCluster,
        'maatPrinciple': c.maatPrinciple,
        'cosmicContext': c.cosmicContext,
        'decanFlow': c.decanFlow
            .map(
              (f) => {
                'day': f.day,
                'theme': f.theme,
                'action': f.action,
                'reflection': f.reflection,
              },
            )
            .toList(),
        'meduNeter': {
          'glyph': c.meduNeter.glyph,
          'colorFrequency': c.meduNeter.colorFrequency,
          'mantra': c.meduNeter.mantra,
        },
      };
      expect(
        sha256.convert(utf8.encode(jsonEncode(fields))).toString(),
        approvedCards[day - 1],
        reason: key,
      );
      expect(c.season, '🌱 Peret – Emergence Season');
      final date = DateTime(2026, 10, 15 + day);
      final month = date.month == 10 ? 'October' : 'November';
      expect(
        KemeticDayData.calculateGregorianDate(key, kYearParam: 2),
        '$month ${date.day}, 2026',
      );
      expect(c.decanFlow, hasLength(10));
      expect(KemeticDayData.getFlowForDay(key)?.day, day);
    }
  });

  test('Renwet has one authored source and exactly 30 definitions', () {
    final owners = <String, int>{};
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final count = RegExp(
        r"(?:key: )?'renwet_\d+_[123]'(?:: KemeticDayInfo|,)",
      ).allMatches(file.readAsStringSync()).length;
      if (count > 0) owners[file.path] = count;
    }
    expect(owners, {'lib/widgets/kemetic_day_data_renwet.dart': 30});
  });

  test(
    'all 30 solar dates and Commons cold/warm prompts use the current card, preserving answers',
    () {
      for (var day = 1; day <= 30; day++) {
        final date = DateTime(2026, 10, 15 + day);
        final key = 'renwet_${day}_${(day - 1) ~/ 10 + 1}';
        final reflection = KemeticDayData.getFlowForDay(key)!.reflection;
        final daily = dailyReflectionQuestionForDate(date)!;
        expect(daily.dayKey, key);
        expect(daily.kYear, 2);
        expect(daily.question, reflection);
        final seed = commonsQuestionSeed(date);
        expect(seed.text, reflection.substring(1, reflection.length - 1));
        final snapshot = CommonsHomeSnapshot.fromJson({
          'questions': [
            {
              'id': seed.id,
              'question': 'Earlier cached editorial question',
              'answers': [
                {'id': 'public', 'body_text': 'Public answer remains'},
              ],
              'answers_has_more': true,
              'my_answer': {
                'id': 'mine',
                'body_text': 'My saved answer remains',
              },
            },
          ],
        });
        final current = activeCommonsQuestion(snapshot, date);
        expect(current.question, seed.text);
        expect(current.id, seed.id);
        expect(current.answers.single.bodyText, 'Public answer remains');
        expect(current.myAnswer?.bodyText, 'My saved answer remains');
        expect(current.hasMoreAnswers, isTrue);
        expect(activeCommonsQuestion(null, date).question, seed.text);
      }
      expect(
        dailyReflectionQuestionForDate(DateTime(2026, 10, 15))!.dayKey,
        'rekhnedjes_30_3',
      );
      expect(
        dailyReflectionQuestionForDate(DateTime(2026, 11, 15))!.dayKey,
        'hnsw_1_1',
      );
    },
  );
}
