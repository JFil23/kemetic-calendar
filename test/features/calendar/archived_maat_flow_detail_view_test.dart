import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/maat_flow_catalog.dart';
import 'package:mobile/features/calendar/maat_flow_identity.dart';
import 'package:mobile/features/calendar/presentation/archived_maat_flow_detail_view.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/maat_flow_visual_test_fonts.dart';

const _captureArchivedFlowVisuals = bool.fromEnvironment(
  'CAPTURE_ARCHIVED_FLOW_VISUALS',
);

void main() {
  setUpAll(() async {
    if (_captureArchivedFlowVisuals) await loadMaatFlowVisualTestFonts();
  });

  Future<void> pumpFixture(
    WidgetTester tester, {
    required Size size,
    double textScale = 1,
    ArchivedMaatFlowFixture fixture = kArchivedMaatFlowVisualFixture,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: RepaintBoundary(
            key: const ValueKey<String>('archived-flow-visual-capture'),
            child: ArchivedMaatFlowDetailView(
              fixture: fixture,
              onBack: () {},
              onEndOrLeave: () {},
              onDismiss: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'uses the shared shell and exposes history without join actions',
    (tester) async {
      await pumpFixture(tester, size: const Size(390, 844));
      expect(find.byType(MaatFlowDetailShell), findsOneWidget);
      expect(find.text('Dawn House Rite'), findsOneWidget);
      expect(find.text('This flow is archived'), findsOneWidget);
      expect(find.text('Historical events'), findsOneWidget);
      expect(find.text('Saved responses'), findsOneWidget);
      expect(find.textContaining('Join'), findsNothing);
      expect(find.textContaining('Schedule new'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('canonical retired snapshots route to read-only compatibility', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home:
            CalendarPage.buildCanonicalMaatFlowDetail(
              name: 'Dawn House Rite',
              notes: 'maat=dawn-house-rite',
              eventsJson: <dynamic>[
                <String, dynamic>{
                  'date': '2026-08-12',
                  'title': 'Open the eastern room',
                  'completion_status': 'Observed',
                  'behavior_payload': <String, dynamic>{
                    'responses': <String, dynamic>{
                      'What arrived with the light?': 'A quiet beginning.',
                    },
                  },
                },
              ],
            ) ??
            const SizedBox.shrink(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ArchivedMaatFlowDetailView), findsOneWidget);
    expect(find.text('Open the eastern room'), findsOneWidget);
    expect(find.text('A quiet beginning.'), findsOneWidget);
    expect(find.textContaining('Join'), findsNothing);
  });

  testWidgets('all nine archived identities restore through compatibility', (
    tester,
  ) async {
    expect(kArchivedCompatibilityMaatFlowKinds, hasLength(9));
    for (final kind in kArchivedCompatibilityMaatFlowKinds) {
      final detail = CalendarPage.buildCanonicalMaatFlowDetail(
        name: '',
        notes: 'mode=kemetic;maat=${kind.flowKey}',
        eventsJson: <dynamic>[
          <String, dynamic>{
            'date': '2026-08-12',
            'title': 'Preserved event',
            'behavior_payload': <String, dynamic>{
              'flow_key': kind.flowKey,
              'responses': <String, dynamic>{'Saved prompt': 'Saved answer'},
            },
          },
        ],
      );
      expect(detail, isNotNull, reason: kind.flowKey);
      await tester.pumpWidget(MaterialApp(home: detail!));
      await tester.pumpAndSettle();
      expect(find.byType(ArchivedMaatFlowDetailView), findsOneWidget);
      expect(find.text('Preserved event'), findsOneWidget);
      expect(find.text('Saved answer'), findsOneWidget);
      expect(find.textContaining('Join'), findsNothing);
    }
  });

  test(
    'legacy device responses are decoded read-only for the exact flow',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'kept_word_73_prompt_repair': 'Speak plainly.',
        'kept_word_73_conversation_completed': true,
        'kept_word_74_prompt_repair': 'Another flow.',
        'unrelated': 'ignore',
      });
      final prefs = await SharedPreferences.getInstance();

      final responses = await ArchivedMaatFlowLocalStateReader.load(
        flowKey: 'the-kept-word',
        flowId: 73,
        preferences: prefs,
      );

      expect(responses.map((response) => response.prompt), <String>[
        'Conversation completed',
        'Repair',
      ]);
      expect(responses.map((response) => response.response), <String>[
        'Completed',
        'Speak plainly.',
      ]);
    },
  );

  test('all four legacy local namespaces decode without mutation', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'kept_word_91_prompt_record': 'Kept history',
      'tending_91_prompt_record': 'Tending history',
      'the_wag_91_prompt_record': 'Wag history',
      'days_outside_91_prompt_record': 'Threshold history',
    });
    final prefs = await SharedPreferences.getInstance();
    final before = <String, Object?>{
      for (final key in prefs.getKeys()) key: prefs.get(key),
    };

    for (final flowKey in const <String>[
      'the-kept-word',
      'the-tending',
      'the-wag',
      'the-days-outside-the-year',
    ]) {
      final responses = await ArchivedMaatFlowLocalStateReader.load(
        flowKey: flowKey,
        flowId: 91,
        preferences: prefs,
      );
      expect(responses, hasLength(1), reason: flowKey);
    }
    expect(<String, Object?>{
      for (final key in prefs.getKeys()) key: prefs.get(key),
    }, before);
  });

  test('generic Wag and Days Outside compatibility is read-only', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'the_wag_91_prompt_ancestor_names': 'Preserved ancestor',
      'days_outside_91_prompt_year_close_triple': 'Preserved threshold',
    });
    final prefs = await SharedPreferences.getInstance();
    final before = <String, Object?>{
      for (final key in prefs.getKeys()) key: prefs.get(key),
    };

    for (final flowKey in const <String>[
      'the-wag',
      'the-days-outside-the-year',
    ]) {
      expect(
        await ArchivedMaatFlowLocalStateReader.load(
          flowKey: flowKey,
          flowId: 91,
          preferences: prefs,
        ),
        hasLength(1),
      );
    }
    expect(<String, Object?>{
      for (final key in prefs.getKeys()) key: prefs.get(key),
    }, before);
    expect(
      prefs.getString('the_wag_91_prompt_ancestor_names'),
      'Preserved ancestor',
    );
    expect(
      prefs.getString('days_outside_91_prompt_year_close_triple'),
      'Preserved threshold',
    );
  });

  for (final fixture in <(String, Size, double)>[
    ('minimum', const Size(320, 700), 1),
    ('mockup', const Size(390, 844), 1),
    ('large', const Size(430, 932), 1),
    ('accessible', const Size(390, 844), 1.35),
  ]) {
    testWidgets('archived flow visual ${fixture.$1}', (tester) async {
      await pumpFixture(tester, size: fixture.$2, textScale: fixture.$3);
      expect(tester.takeException(), isNull);
      if (!_captureArchivedFlowVisuals) return;
      await expectLater(
        find.byKey(const ValueKey<String>('archived-flow-visual-capture')),
        matchesGoldenFile('/tmp/archived-flow-${fixture.$1}.png'),
      );
    });
  }
}
