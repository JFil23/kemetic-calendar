import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/ai_flow_generation_response.dart';

void main() {
  test('copyWith preserves requested flow range dates', () {
    const response = AIFlowGenerationResponse(
      success: true,
      flowName: 'Yoga Flow',
      notes: '[]',
    );

    final updated = response.copyWith(
      requestedStartDate: DateTime(2026, 4, 19),
      requestedEndDate: DateTime(2026, 4, 28),
    );

    expect(updated.flowName, 'Yoga Flow');
    expect(updated.requestedStartDate, DateTime(2026, 4, 19));
    expect(updated.requestedEndDate, DateTime(2026, 4, 28));
  });

  test('fromJson parses requested flow range dates when present', () {
    final response = AIFlowGenerationResponse.fromJson({
      'success': true,
      'flow_name': 'Yoga Flow',
      'requested_start_date': '2026-04-19',
      'requested_end_date': '2026-04-28',
      'notes': const [],
    });

    expect(response.requestedStartDate, DateTime(2026, 4, 19));
    expect(response.requestedEndDate, DateTime(2026, 4, 28));
  });

  test('fromJson preserves ai_metadata for downstream flow persistence', () {
    final response = AIFlowGenerationResponse.fromJson({
      'success': true,
      'flow_name': 'Study Flow',
      'notes': const [],
      'ai_metadata': {
        'generated': true,
        'plan_spec': {
          'version': 'flowspec_v2',
          'actions': [
            {'action_id': 'a001'},
          ],
        },
      },
    });

    expect(response.aiMetadata?['generated'], isTrue);
    expect(
      (response.aiMetadata?['plan_spec'] as Map<String, dynamic>)['version'],
      'flowspec_v2',
    );
  });
}
