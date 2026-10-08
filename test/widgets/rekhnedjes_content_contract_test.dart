import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/daily_reflection_question.dart';
import 'package:mobile/data/commons_models.dart';
import 'package:mobile/data/commons_question_selection.dart';
import 'package:mobile/services/decan_reflection_scheduler.dart';
import 'package:mobile/widgets/kemetic_day_info.dart';
import '../features/pages/pages_resource_test.dart' show session;

// Immutable fingerprints of the approved October 8 editorial reference, not
// generated from runtime data. Covers every field and each complete decan flow.
const approvedCards = <String>[
  'ccdd728bbded5d762279a807f7d50ce28d65c538393abf5ca0ae9984907196cc',
  '511240a672703ce38c142844f592400bb7c482e792a4937c3418fa0de2b5b73d',
  '955472f8d31e3810e8e89244d3391ddde2994d24cbc2e350100722d333e9c04b',
  'c8f6255a905a524cb6e65c8813c32354248959bbfc086eafd38cb07c2377af2d',
  '2dc8b2c52e07563ed75558877cc3e3f20099a138790e1077a4ff96bce600d332',
  '0476a07f5847a032ef322ebccdb45e4989d27179728cb1860fdf32b3213624c1',
  '23ccf284fe6587a97dfde50f0f92cd08f7c6df42448508a4d3eb922b6ea451bf',
  '70907c35edfc2d08d85a53299e77a7f075fee58f3009096f0dd9efd596bdd534',
  '560224b1174f66aab67ecc8e77a5d7ce91b131f7f93bb74a40f2e63209aeaddf',
  '46273d957b1b8e9a18e5260f88dcd85d24c032957d94b7c10edc80e75b5d2267',
  '3e4dacf4859f8d4a8970b28db03cc5c137ca6302d35e92b4a739e9067c94452c',
  'ae04a920d7e1d60ae39905035ffad6d4d9f4a3501fc49588a5e3f6606d752bd9',
  '40e3024225811485cce64d706f21035bf17e87d02cc32cca4013247daf5b9f6f',
  '3ff5d7661f631aced955d7784d50000677ebcec170ef04d45713b3911781e6e9',
  'e75e5016e756abf32eb4e3a4c8a9e56f6945f206d890478796ae1a71b13f1bff',
  'ef1d432c8dbd38a19ed328879dcc6d3c699531f8300c2fd97ae3ae9dd0cae6b7',
  '1e1abd959d1ec12bfe9d7b82b1dafa4ee2b0d19b9a5b20b66a841109101cefa1',
  '3b33aeb0eb44467d9c6b4784a341d40c70f7ef3b1fe3d1d37ffa15d6ac06db43',
  '17ad041d0c2791b8fdf71af681ff9eba1be55f2962723538d37e149f5b5a3a51',
  '1570496bffc48a4fe9a4310da8b70addf31c89d8a5473aa8f3eba22e1692c0b1',
  '51895c6efd5776292288db23845e2c96c8728ac5d6c44890d5366c848ddd5051',
  '02566287808dba973f1b72446630ea48b950d8c87f7fb5a366ac51dc545cc9b3',
  'e5fcb20c463623723fb0a6a3385e99fbac99fffc378a3ea8d2abd52e003dac87',
  '2fe1934bfd612cbfaec22bcc41d18a1d2980d643349a227f79c22f6c315122e1',
  '667f8b98601b386bd146fc6123566ca62cceba35380ff40064c3880a5cca4810',
  'f04e28cfd6adeacbfa96790f022eec9209579491423a293810529cd07531ab74',
  '0f0408768b1fe739d2503ccf5b44da63bb39e0fb499d3f915c7e756fb3595d47',
  'c264ec376fc1ba6ab69a1b895d2976bcd28c7614d4ddcd52aa20f652067c9c3b',
  '07b819a6a7759e9c9fe3f47a741330cb8cfa58523237b20dec153da1da774017',
  '38dae15b36c28acebe4d2c90ff64b0128ecfdf7ab0d15dced9c878797020ae9f',
];

void main() {
  test('all 30 cards reproduce the approved autumn reference exactly', () {
    for (var day = 1; day <= 30; day++) {
      final key = 'rekhnedjes_${day}_${(day - 1) ~/ 10 + 1}';
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
      expect(c.decanFlow, hasLength(10));
      expect(KemeticDayData.getFlowForDay(key)?.day, day);
    }
  });

  test('Rekh-Nedjes has one authored source and exactly 30 definitions', () {
    final owners = <String, int>{};
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final count = RegExp(
        r"(?:key: )?'rekhnedjes_\d+_[123]'(?:: KemeticDayInfo|,)",
      ).allMatches(file.readAsStringSync()).length;
      if (count > 0) owners[file.path] = count;
    }
    expect(owners, {'lib/widgets/kemetic_day_data_rekhnedjes.dart': 30});
  });

  test(
    'all 30 solar dates and Commons cold/warm prompts use the current card, preserving answers',
    () {
      for (var day = 1; day <= 30; day++) {
        final date = DateTime(2026, 9, 15 + day);
        final key = 'rekhnedjes_${day}_${(day - 1) ~/ 10 + 1}';
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
        dailyReflectionQuestionForDate(DateTime(2026, 9, 15))!.dayKey,
        'rekhwer_30_3',
      );
      expect(
        dailyReflectionQuestionForDate(DateTime(2026, 10, 16))!.dayKey,
        'renwet_1_1',
      );
    },
  );

  test(
    'guidance sends the exact current card and absolute-day flow for all three decans',
    () async {
      var now = DateTime(2026, 9, 16, 12);
      final payloads = <Map<String, dynamic>>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          payloads.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await client.auth.recoverSession(session());
      final scheduler = DecanReflectionScheduler(client, now: () => now);
      for (var day = 1; day <= 30; day++) {
        now = DateTime(2026, 9, 15 + day, 12);
        await scheduler.ensureCurrentAndNextScheduled(force: true);
        final key = 'rekhnedjes_${day}_${(day - 1) ~/ 10 + 1}';
        final card = KemeticDayData.getInfoForDay(key)!;
        final flow = KemeticDayData.getFlowForDay(key)!;
        final payload = payloads.last['day_card'] as Map;
        expect(payload['cosmicContext'], card.cosmicContext);
        expect(payload['maatPrinciple'], card.maatPrinciple);
        expect(payload['decanDayTheme'], flow.theme);
        expect(payload['decanDayAction'], flow.action);
        expect(payload['decanDayReflection'], flow.reflection);
      }
      expect(payloads, hasLength(30));
    },
  );
}
