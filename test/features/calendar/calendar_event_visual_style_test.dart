import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_event_visual_style.dart';

void main() {
  group('CalendarEventVisualStyle', () {
    test('The Weighing detail surface preserves the event block palette', () {
      final block = resolveCalendarEventVisualStyle(
        eventColor: Colors.red,
        eventTitle: 'Weighing 9: Seal the Record',
        behaviorPayload: const <String, dynamic>{
          'flow_key': 'the-weighing',
          'kind': 'maat_the_weighing_event',
        },
      );
      final detail = block.asDetailSurface();

      expect(block.graphic?.kind, CalendarEventGraphicKind.theWeighing);
      expect(block.paletteKey, 'graphic:theWeighing');
      expect(detail.paletteKey, block.paletteKey);
      expect(detail.graphic, same(block.graphic));
      expect(_isRedOrange(block.source), isFalse);
      expect(_isRedOrange(detail.source), isFalse);
      expect(_hueDistance(block.source, detail.source), lessThan(3));
    });

    test('detail surfaces keep representative event palettes in lockstep', () {
      final cases = <_PaletteCase>[
        _PaletteCase(
          label: 'Track sky',
          flowName: 'Follow the sky',
          eventTitle: 'Strawberry Moon + Micromoon (Full)',
          eventColor: Colors.indigo,
          graphicKind: CalendarEventGraphicKind.trackSky,
        ),
        _PaletteCase(
          label: 'Dawn House Rite',
          flowName: 'Dawn House Rite',
          eventTitle: 'Day 1: Open the House',
          eventColor: Colors.orange,
          graphicKind: CalendarEventGraphicKind.dawnHouseRite,
        ),
        _PaletteCase(
          label: 'Evening Threshold Rite',
          flowName: 'The Closing',
          eventTitle: 'Day 1: Close the threshold',
          eventColor: Colors.deepPurple,
          graphicKind: CalendarEventGraphicKind.eveningThresholdRite,
        ),
        _PaletteCase(
          label: 'Generated flow',
          flowName: '10-day Spanish practice',
          eventTitle: 'Evening Reflection',
          eventColor: const Color(0xFF9D4EDD),
        ),
        _PaletteCase(
          label: 'Reminder',
          eventTitle: 'journal every night',
          eventColor: Colors.red,
          isReminder: true,
        ),
        _PaletteCase(
          label: 'Nutrition',
          eventTitle: 'Breakfast',
          eventColor: Colors.red,
          isNutrition: true,
        ),
        _PaletteCase(
          label: 'Normal calendar event',
          eventTitle: 'Dentist',
          eventColor: Colors.teal,
        ),
      ];

      for (final c in cases) {
        final block = resolveCalendarEventVisualStyle(
          eventColor: c.eventColor,
          flowName: c.flowName,
          eventTitle: c.eventTitle,
          isReminder: c.isReminder,
          isNutrition: c.isNutrition,
        );
        final detail = block.asDetailSurface();

        expect(detail.paletteKey, block.paletteKey, reason: c.label);
        expect(detail.graphic, same(block.graphic), reason: c.label);
        expect(_hueDistance(block.source, detail.source), lessThan(3));
        if (c.graphicKind != null) {
          expect(block.graphic?.kind, c.graphicKind, reason: c.label);
        } else {
          expect(block.graphic, isNull, reason: c.label);
        }
      }
    });
  });
}

class _PaletteCase {
  const _PaletteCase({
    required this.label,
    required this.eventTitle,
    required this.eventColor,
    this.flowName,
    this.graphicKind,
    this.isReminder = false,
    this.isNutrition = false,
  });

  final String label;
  final String? flowName;
  final String eventTitle;
  final Color eventColor;
  final CalendarEventGraphicKind? graphicKind;
  final bool isReminder;
  final bool isNutrition;
}

bool _isRedOrange(Color color) {
  final hue = HSLColor.fromColor(color).hue;
  return hue <= 32 || hue >= 342;
}

double _hueDistance(Color a, Color b) {
  final aHue = HSLColor.fromColor(a).hue;
  final bHue = HSLColor.fromColor(b).hue;
  final direct = (aHue - bHue).abs();
  return direct > 180 ? 360 - direct : direct;
}
