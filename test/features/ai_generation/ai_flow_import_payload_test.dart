import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/ai_generation/ai_flow_import_payload.dart';
import 'package:mobile/models/ai_flow_generation_response.dart';

void main() {
  group('buildAiFlowImportEvents', () {
    test('preserves explicit location links from generated notes', () {
      final response = AIFlowGenerationResponse(
        success: true,
        notes: jsonEncode([
          {
            'day_index': 0,
            'title': 'Day 1',
            'details': 'Open the class and follow along.',
            'all_day': false,
            'start_time': '07:00',
            'end_time': '07:30',
            'location': 'https://www.youtube.com/watch?v=FSwmDWL68gw',
          },
        ]),
      );

      final events = buildAiFlowImportEvents(response);

      expect(events, hasLength(1));
      expect(
        events.first['location'],
        'https://www.youtube.com/watch?v=FSwmDWL68gw',
      );
      expect(events.first['start_time'], '07:00');
      expect(events.first['end_time'], '07:30');
    });

    test('extracts a direct link from details when location is missing', () {
      final response = AIFlowGenerationResponse(
        success: true,
        notes: jsonEncode([
          {
            'day_index': 1,
            'title': 'Day 2',
            'details':
                'Use this class today: https://meet.google.com/abc-defg-hij).',
            'all_day': false,
            'start_time': '18:00',
            'end_time': '18:30',
          },
        ]),
      );

      final events = buildAiFlowImportEvents(response);

      expect(events, hasLength(1));
      expect(events.first['location'], 'https://meet.google.com/abc-defg-hij');
    });
  });
}
