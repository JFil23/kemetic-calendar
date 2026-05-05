import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/calendar_event_markers.dart';

void main() {
  group('calendarEventMarkerColors', () {
    test('preserves standalone markers, including repeated colors', () {
      final colors = calendarEventMarkerColors<Color>(const [
        Colors.blue,
        Colors.blue,
        Colors.pink,
      ], colorOf: (color) => color);

      expect(colors, const [Colors.blue, Colors.blue, Colors.pink]);
    });

    test('collapses multiple events with the same marker group', () {
      final colors = calendarEventMarkerColors<({Color color, int? flowId})>(
        const [
          (color: Colors.blue, flowId: 7),
          (color: Colors.blue, flowId: 7),
          (color: Colors.pink, flowId: 8),
        ],
        colorOf: (event) => event.color,
        groupBy: (event) =>
            event.flowId == null ? null : 'flow:${event.flowId}',
      );

      expect(colors, const [Colors.blue, Colors.pink]);
    });

    test('caps compact calendar markers at three', () {
      final colors = calendarEventMarkerColors<Color>(const [
        Colors.blue,
        Colors.pink,
        Colors.orange,
        Colors.green,
      ], colorOf: (color) => color);

      expect(colors, const [Colors.blue, Colors.pink, Colors.orange]);
    });
  });
}
