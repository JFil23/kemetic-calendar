import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/evening_threshold_rite_flow.dart';
import 'package:mobile/features/calendar/maat_flow_response_models.dart';
import 'package:mobile/features/calendar/maat_flow_response_resolver.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';

void main() {
  test(
    'Evening Threshold closing formatter preserves ritual journal voice',
    () {
      final spec = resolveMaatFlowResponseSpecs(
        flowKey: kEveningThresholdRiteFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).singleWhere((spec) => spec.id == 'closing-release-tonight');

      final previews = buildMaatFlowResponseJournalPreviews(
        specs: <MaatFlowResponseSpec>[spec],
        values: <String, MaatFlowResponseValue>{
          spec.id: MaatFlowResponseValue.text(
            specId: spec.id,
            text: 'the need to control tomorrow',
            multiline: true,
          ),
        },
        completionStatus: CompletionStatus.observed,
        clientEventId: 'evt-hidden-practice',
        localDate: DateTime(2026, 7, 11),
      );

      expect(previews, hasLength(1));
      expect(
        previews.single.text,
        'The Closing: I release the need to control tomorrow.',
      );
    },
  );

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
