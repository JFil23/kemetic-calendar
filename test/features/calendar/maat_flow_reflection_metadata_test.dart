import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/maat_flow_reflection_metadata.dart';

void main() {
  test('resolver returns distinct response hints for activity tiers', () {
    final metadata = resolveMaatFlowReflectionMetadata(
      flowId: 'the-offering-table',
      eventId: 'event-2',
      flowTitle: 'The Offering Table',
      eventTitle: 'Return the Cup',
    );

    final low = resolveMaatFlowResponseHint(
      metadata: metadata,
      completionStatus: CompletionStatus.observed,
      activityTier: MaatFlowActivityTier.low,
    );
    final partial = resolveMaatFlowResponseHint(
      metadata: metadata,
      completionStatus: CompletionStatus.observed,
      activityTier: MaatFlowActivityTier.partial,
    );
    final consistent = resolveMaatFlowResponseHint(
      metadata: metadata,
      completionStatus: CompletionStatus.observed,
      activityTier: MaatFlowActivityTier.consistent,
    );
    final strong = resolveMaatFlowResponseHint(
      metadata: metadata,
      completionStatus: CompletionStatus.observed,
      activityTier: MaatFlowActivityTier.strong,
    );

    expect({low, partial, consistent, strong}, hasLength(4));
    expect(low, contains('carried you today'));
    expect(partial, contains('caught part'));
    expect(consistent, contains('returning to the work'));
    expect(strong, contains('pattern is forming'));
  });

  test('completion status can override activity tier response', () {
    final metadata = resolveMaatFlowReflectionMetadata(
      flowId: 'the-tending',
      eventTitle: 'Name the Need',
    );

    expect(
      resolveMaatFlowResponseHint(
        metadata: metadata,
        completionStatus: CompletionStatus.partial,
        activityTier: MaatFlowActivityTier.strong,
      ),
      metadata.partialActivityResponseHint,
    );
    expect(
      resolveMaatFlowResponseHint(
        metadata: metadata,
        completionStatus: CompletionStatus.skipped,
        activityTier: MaatFlowActivityTier.strong,
      ),
      metadata.lowActivityResponseHint,
    );
  });

  test('payload resolver preserves Ma_at event guidance metadata', () {
    final metadata = resolveMaatFlowReflectionMetadataFromPayload(
      <String, dynamic>{
        'flow_key': 'the-djed',
        'event_number': 5,
        'reflection_guidance': <String, dynamic>{
          'theme': 'Stability under pressure',
          'ritualAction': 'Stand upright',
          'reflectionIntent': 'Name what held.',
        },
      },
    );

    expect(metadata.flowId, 'the-djed');
    expect(metadata.eventId, 'event-5');
    expect(metadata.theme, 'Stability under pressure');
    expect(metadata.ritualAction, 'Stand upright');
    expect(metadata.reflectionIntent, 'Name what held.');
  });
}
