import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/dawn_house_rite_flow.dart';
import 'package:mobile/features/calendar/evening_threshold_rite_flow.dart';
import 'package:mobile/features/calendar/maat_flow_response_models.dart';
import 'package:mobile/features/calendar/maat_flow_response_projection.dart';
import 'package:mobile/features/calendar/maat_flow_response_resolver.dart';

void main() {
  test('every registered Ma_at response spec declares one journal behavior', () {
    for (final spec in kDefaultMaatFlowResponseResolver.specs) {
      switch (spec.journalBehavior) {
        case MaatFlowJournalBehavior.formatted:
          expect(
            spec.journalPolicy.canProduceJournalBody,
            isTrue,
            reason:
                '${spec.flowKey}/${spec.id} formatted behavior needs policy',
          );
        case MaatFlowJournalBehavior.plainUserText:
          expect(
            spec.journalCarryMode,
            MaatFlowJournalCarryMode.userReflection,
            reason:
                '${spec.flowKey}/${spec.id} plain behavior must be explicit',
          );
        case MaatFlowJournalBehavior.none:
          expect(
            spec.journalPolicy,
            MaatFlowJournalPolicy.localOnly,
            reason:
                '${spec.flowKey}/${spec.id} no-journal behavior must be explicit',
          );
      }
    }
  });

  test(
    'Evening Threshold closing response uses plain user-text journal behavior',
    () {
      final spec = resolveMaatFlowResponseSpecs(
        flowKey: kEveningThresholdRiteFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).singleWhere((spec) => spec.id == 'closing-release-tonight');

      expect(spec.journalBehavior, MaatFlowJournalBehavior.plainUserText);
      expect(spec.journalCarryMode, MaatFlowJournalCarryMode.userReflection);
      expect(
        spec.journalFormatter,
        MaatFlowResponseJournalFormatter.closingRelease,
      );
    },
  );

  test('unknown persisted journal behavior fails loudly', () {
    expect(
      () => MaatFlowJournalBehaviorX.fromWireName('future_behavior'),
      throwsA(isA<FormatException>()),
    );
    expect(
      MaatFlowJournalBehaviorX.fromWireName('none'),
      MaatFlowJournalBehavior.none,
    );
  });

  test(
    'projection routing is exhaustive and does not infer from loose fields',
    () {
      final formattedSpec = resolveMaatFlowResponseSpecs(
        flowKey: kDawnHouseRiteFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).singleWhere((spec) => spec.id == 'dawn-house-order-act');
      const plainSpec = MaatFlowResponseSpec(
        id: 'plain-reflection',
        flowKey: 'test-flow',
        surface: MaatFlowResponseSurface.calendarSheet,
        kind: MaatFlowResponseKind.multiline,
        label: 'Plain reflection',
        journalBehavior: MaatFlowJournalBehavior.plainUserText,
        journalCarryMode: MaatFlowJournalCarryMode.userReflection,
        journalPolicy: MaatFlowJournalPolicy.mirror,
      );
      final noJournalSpec = kDefaultMaatFlowResponseResolver.specs.firstWhere(
        (spec) => spec.journalBehavior == MaatFlowJournalBehavior.none,
      );
      final localDate = DateTime(2026, 7, 11);

      final projections = buildMaatJournalResponseProjections(
        specs: <MaatFlowResponseSpec>[formattedSpec, plainSpec, noJournalSpec],
        values: <String, MaatFlowResponseValue>{
          formattedSpec.id: MaatFlowResponseValue.text(
            specId: formattedSpec.id,
            text: 'clearing the table before sunrise',
          ),
          plainSpec.id: MaatFlowResponseValue.text(
            specId: plainSpec.id,
            text: 'plain reflection stays verbatim',
            multiline: plainSpec.kind == MaatFlowResponseKind.multiline,
          ),
          noJournalSpec.id: MaatFlowResponseValue.text(
            specId: noJournalSpec.id,
            text: 'private detail only',
            multiline: noJournalSpec.kind == MaatFlowResponseKind.multiline,
          ),
        },
        completionStatus: CompletionStatus.observed,
        localDate: localDate,
        sourceIdForSpec: (spec) => spec.sourceId(
          clientEventId: 'evt-${spec.id}',
          localDate: localDate,
        ),
        sourceIdForGroup: (spec, groupId) => buildMaatFlowResponseSourceId(
          flowKey: spec.flowKey,
          responseSpecId: groupId,
          clientEventId: 'evt-$groupId',
          localDate: localDate,
        ),
      );

      expect(
        projections
            .where(
              (projection) =>
                  projection.block.projectionKind ==
                  MaatJournalResponseProjectionKind.formatted,
            )
            .length,
        1,
      );
      expect(
        projections
            .where(
              (projection) =>
                  projection.block.projectionKind ==
                  MaatJournalResponseProjectionKind.plainUserText,
            )
            .length,
        1,
      );
      expect(
        projections.any(
          (projection) => projection.block.sourceId.contains(noJournalSpec.id),
        ),
        isFalse,
      );
    },
  );
}
