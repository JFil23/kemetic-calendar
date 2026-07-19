import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/evening_threshold_rite_flow.dart';
import 'package:mobile/features/calendar/maat_flow_completion_response_persistence.dart';
import 'package:mobile/features/calendar/maat_flow_response_journal_blocks.dart';
import 'package:mobile/features/calendar/maat_flow_response_models.dart';
import 'package:mobile/features/calendar/maat_flow_response_projection.dart';
import 'package:mobile/features/calendar/maat_flow_response_resolver.dart';

void main() {
  const responseText = 'Tonight I release the need to be perfect.';
  final localDate = DateTime(2026, 7, 11);

  MaatFlowResponseSpec closingSpec() {
    return resolveMaatFlowResponseSpecs(
      flowKey: kEveningThresholdRiteFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    ).singleWhere((spec) => spec.id == 'closing-release-tonight');
  }

  test(
    'completion metadata persists raw response and supports clear intent',
    () {
      final spec = closingSpec();
      final sourceId = spec.sourceId(
        clientEventId: 'evt-hidden-practice',
        localDate: localDate,
      );
      final metadata = buildMaatCompletionResponseMetadata(
        existingMetadata: const <String, dynamic>{'status': 'observed'},
        specs: <MaatFlowResponseSpec>[spec],
        currentValues: <String, MaatFlowResponseValue>{
          spec.id: MaatFlowResponseValue.text(
            specId: spec.id,
            text: responseText,
            multiline: true,
          ),
        },
        dirtySpecIds: <String>{spec.id},
        clientEventId: 'evt-hidden-practice',
        flowId: 42,
        localDate: localDate,
        eventKey: null,
        completedAt: DateTime.utc(2026, 7, 11, 15, 27),
        sourceIdForSpec: (_) => sourceId,
        sourceIdForGroup: (_, _) => sourceId,
      );

      final restored = extractMaatCompletionResponseValues(
        metadata,
        specs: <MaatFlowResponseSpec>[spec],
      );
      expect(restored.values[spec.id]?.text, responseText);
      expect(restored.values[spec.id]?.kind, MaatFlowResponseKind.multiline);
      expect(restored.records.single.sourceId, sourceId);
      expect(restored.records.single.journalBehavior, spec.journalBehavior);

      Map<String, dynamic> metadataWithJournalBehavior(
        Object? journalBehavior, {
        bool remove = false,
      }) {
        final copy = Map<String, dynamic>.from(metadata);
        final envelope = Map<String, dynamic>.from(
          copy[kMaatCompletionResponsesMetadataKey] as Map,
        );
        final records = Map<String, dynamic>.from(envelope['records'] as Map);
        final record = Map<String, dynamic>.from(records[spec.id] as Map);
        if (remove) {
          record.remove('journal_behavior');
        } else {
          record['journal_behavior'] = journalBehavior;
        }
        records[spec.id] = record;
        envelope['records'] = records;
        copy[kMaatCompletionResponsesMetadataKey] = envelope;
        return copy;
      }

      for (final compatibilityCase in <Map<String, dynamic>>[
        metadataWithJournalBehavior(null, remove: true),
        metadataWithJournalBehavior('future_behavior'),
        metadataWithJournalBehavior(MaatFlowJournalBehavior.none.wireName),
      ]) {
        final compatible = extractMaatCompletionResponseValues(
          compatibilityCase,
          specs: <MaatFlowResponseSpec>[spec],
        );
        expect(compatible.values[spec.id]?.text, responseText);
        expect(compatible.records.single.journalBehavior, spec.journalBehavior);
      }

      final statusOnly = buildMaatCompletionResponseMetadata(
        existingMetadata: metadata,
        specs: <MaatFlowResponseSpec>[spec],
        currentValues: const <String, MaatFlowResponseValue>{},
        dirtySpecIds: const <String>{},
        clientEventId: 'evt-hidden-practice',
        flowId: 42,
        localDate: localDate,
        eventKey: null,
        completedAt: DateTime.utc(2026, 7, 11, 15, 30),
        sourceIdForSpec: (_) => sourceId,
        sourceIdForGroup: (_, _) => sourceId,
      );
      expect(
        extractMaatCompletionResponseValues(
          statusOnly,
          specs: <MaatFlowResponseSpec>[spec],
        ).values[spec.id]?.text,
        responseText,
      );

      final cleared = buildMaatCompletionResponseMetadata(
        existingMetadata: metadata,
        specs: <MaatFlowResponseSpec>[spec],
        currentValues: <String, MaatFlowResponseValue>{
          spec.id: MaatFlowResponseValue.text(
            specId: spec.id,
            text: '',
            multiline: true,
          ),
        },
        dirtySpecIds: <String>{spec.id},
        clientEventId: 'evt-hidden-practice',
        flowId: 42,
        localDate: localDate,
        eventKey: null,
        completedAt: DateTime.utc(2026, 7, 11, 15, 31),
        sourceIdForSpec: (_) => sourceId,
        sourceIdForGroup: (_, _) => sourceId,
      );
      expect(
        extractMaatCompletionResponseValues(
          cleared,
          specs: <MaatFlowResponseSpec>[spec],
        ).values,
        isNot(contains(spec.id)),
      );
    },
  );

  test('completion projection updates one plain user-text journal source', () {
    final spec = closingSpec();
    final sourceId = spec.sourceId(
      clientEventId: 'evt-hidden-practice',
      localDate: localDate,
    );
    final values = <String, MaatFlowResponseValue>{
      spec.id: MaatFlowResponseValue.text(
        specId: spec.id,
        text: responseText,
        multiline: true,
      ),
    };

    final projections = buildMaatJournalResponseProjections(
      specs: <MaatFlowResponseSpec>[spec],
      values: values,
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
    expect(projections.single.block.sourceId, sourceId);
    expect(
      projections.single.block.blockId,
      maatJournalResponseBlockId(sourceId),
    );
    expect(projections.single.block.text, responseText);
    expect(projections.single.block.text, isNot(contains('The Closing:')));
    expect(projections.single.block.text, isNot(contains('I release Tonight')));

    final updated = buildMaatJournalResponseProjections(
      specs: <MaatFlowResponseSpec>[spec],
      values: <String, MaatFlowResponseValue>{
        spec.id: MaatFlowResponseValue.text(
          specId: spec.id,
          text: 'Tonight I release the old pressure.',
          multiline: true,
        ),
      },
      completionStatus: CompletionStatus.observed,
      localDate: localDate,
      sourceIdForSpec: (_) => sourceId,
      sourceIdForGroup: (_, _) => sourceId,
    );
    expect(updated.single.block.blockId, projections.single.block.blockId);
    expect(updated.single.block.sourceId, projections.single.block.sourceId);
    expect(updated.single.block.text, 'Tonight I release the old pressure.');
    expect(updated.single.block.text, isNot(contains(responseText)));
  });
}
