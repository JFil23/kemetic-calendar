import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/evening_threshold_rite_flow.dart';
import 'package:mobile/features/calendar/maat_flow_response_projection.dart';
import 'package:mobile/features/calendar/maat_flow_response_models.dart';
import 'package:mobile/features/calendar/maat_flow_response_resolver.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';

void main() {
  test('Evening Threshold closing projection carries exact journal text', () {
    final spec = resolveMaatFlowResponseSpecs(
      flowKey: kEveningThresholdRiteFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    ).singleWhere((spec) => spec.id == 'closing-release-tonight');
    const text = 'Tonight I release the need to be perfect.';
    final localDate = DateTime(2026, 7, 11);
    final sourceId = spec.sourceId(
      clientEventId: 'evt-hidden-practice',
      localDate: localDate,
    );

    final projections = buildMaatJournalResponseProjections(
      specs: <MaatFlowResponseSpec>[spec],
      values: <String, MaatFlowResponseValue>{
        spec.id: MaatFlowResponseValue.text(
          specId: spec.id,
          text: text,
          multiline: true,
        ),
      },
      completionStatus: CompletionStatus.observed,
      localDate: localDate,
      sourceIdForSpec: (_) => sourceId,
      sourceIdForGroup: (_, _) => sourceId,
    );

    expect(projections, hasLength(1));
    expect(
      projections.single.block.projectionKind,
      MaatJournalResponseProjectionKind.plainUserText,
    );
    expect(projections.single.block.text, text);
    expect(projections.single.block.text, isNot(contains('The Closing:')));
    expect(projections.single.block.text, isNot(contains('I release Tonight')));
  });

  test('Offering Table grouped formatter writes one grouped sentence', () {
    final specs = resolveMaatFlowResponseSpecs(
      flowKey: kOfferingTableFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final fed = specs.singleWhere((spec) => spec.id == 'offering-table-fed');
    final provided = specs.singleWhere(
      (spec) => spec.id == 'offering-table-provided',
    );

    final previews = buildMaatFlowResponseJournalPreviews(
      specs: specs,
      values: <String, MaatFlowResponseValue>{
        fed.id: MaatFlowResponseValue.chips(
          specId: fed.id,
          optionIds: <String>['water', 'rest'],
        ),
        provided.id: MaatFlowResponseValue.text(
          specId: provided.id,
          text: 'closing the laptop early',
          multiline: true,
        ),
      },
      completionStatus: CompletionStatus.observed,
      clientEventId: 'evt-offering-table',
      localDate: DateTime(2026, 7, 11),
    );

    expect(previews, hasLength(1));
    expect(
      previews.single.text,
      'The Offering Table: I fed water and rest by closing the laptop early.',
    );
  });
}
