import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/decan_reflection_model.dart';
import 'package:mobile/data/decan_reflection_prompt_state.dart';
import 'package:mobile/data/decan_reflection_repo.dart';
import 'package:mobile/data/maat_guidance_model.dart';
import 'package:mobile/data/maat_guidance_repo.dart';
import 'package:mobile/features/reflections/decan_reflection_archive_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets(
    'measures five archive paints while prompt acknowledgement is delayed',
    (tester) async {
      final measurements = <int>[];

      for (var run = 0; run < 5; run++) {
        final repo = _DelayedAcknowledgementRepo(const Duration(seconds: 10));
        await tester.pumpWidget(
          MaterialApp(
            home: DecanReflectionArchivePage(
              reflectionRepoForTesting: repo,
              maatRepoForTesting: _ImmediateMaatRepo(),
              promptStateForTesting: _ImmediatePromptState(),
            ),
          ),
        );

        var elapsedMs = 0;
        while (find.text('Peret — Measure').evaluate().isEmpty &&
            elapsedMs < 12000) {
          await tester.pump(const Duration(milliseconds: 100));
          elapsedMs += 100;
        }

        measurements.add(elapsedMs);
        expect(find.text('Peret — Measure'), findsOneWidget);
        expect(repo.acknowledgementStarted, isTrue);
        expect(repo.acknowledgementCompleted, isFalse);

        await tester.pump(const Duration(seconds: 10));
        expect(repo.acknowledgementCompleted, isTrue);
        expect(find.text('Peret — Measure'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
      }

      // ignore: avoid_print
      print('DECAN_REFLECTIONS_FIRST_OPEN_MS=$measurements');
      expect(measurements, everyElement(inInclusiveRange(0, 100)));
    },
  );
}

class _DelayedAcknowledgementRepo extends DecanReflectionRepo {
  _DelayedAcknowledgementRepo(this.delay)
    : super(
        SupabaseClient(
          'https://example.test',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final Duration delay;
  bool acknowledgementStarted = false;
  bool acknowledgementCompleted = false;

  @override
  Future<DecanReflectionListResult> listMineResult() async {
    return DecanReflectionListResult(
      data: <DecanReflection>[
        DecanReflection(
          id: 'reflection-1',
          decanName: 'Peret — Measure',
          decanTheme: 'Measure',
          decanStart: DateTime.utc(2026, 5, 6),
          decanEnd: DateTime.utc(2026, 5, 15),
          badgeCount: 3,
          reflectionText: 'A generated end-of-decan reflection.',
          createdAt: DateTime.utc(2026, 5, 16),
        ),
      ],
    );
  }

  @override
  Future<void> markPromptInteracted({
    required DateTime decanStart,
    DateTime? decanEnd,
    String interactionKind = 'interacted',
  }) async {
    acknowledgementStarted = true;
    await Future<void>.delayed(delay);
    acknowledgementCompleted = true;
  }
}

class _ImmediateMaatRepo extends MaatGuidanceRepo {
  _ImmediateMaatRepo()
    : super(
        SupabaseClient(
          'https://example.test',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  @override
  Future<MaatGuidanceListResult> listDecanOpeningsForArchive() async {
    return const MaatGuidanceListResult(data: <MaatGuidanceDelivery>[]);
  }
}

class _ImmediatePromptState extends DecanReflectionPromptState {
  _ImmediatePromptState() : super.withUserIdProvider(() => 'user-1');

  @override
  Future<void> markInteracted(DateTime decanStart) async {}
}
