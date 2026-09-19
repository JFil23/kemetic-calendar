import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_event_visual_style.dart';

void main() {
  group('CalendarEventVisualStyle', () {
    test('archived flows use the generic historical event palette', () {
      final block = resolveCalendarEventVisualStyle(
        eventColor: Colors.red,
        eventTitle: 'Weighing 9: Seal the Record',
        behaviorPayload: const <String, dynamic>{
          'flow_key': 'the-weighing',
          'kind': 'maat_the_weighing_event',
        },
      );
      final detail = block.asDetailSurface();

      expect(block.graphic, isNull);
      expect(detail.paletteKey, block.paletteKey);
      expect(detail.graphic, same(block.graphic));
      expect(_hueDistance(block.source, detail.source), lessThan(3));
    });

    test('reminder visuals preserve explicit event colors when requested', () {
      const magenta = Color(0xFFE85DFF);
      const reminderFallback = Color(0xFF5CAA5F);

      final generic = resolveCalendarEventVisualStyle(
        eventColor: magenta,
        eventTitle: 'journal every night',
        isReminder: true,
      );
      final sharedCalendarReminder = resolveCalendarEventVisualStyle(
        eventColor: magenta,
        eventTitle: 'Family Salon',
        isReminder: true,
        preserveEventColorForReminder: true,
      );
      final detail = sharedCalendarReminder.asDetailSurface();

      expect(_hueDistance(generic.source, reminderFallback), lessThan(3));
      expect(_hueDistance(sharedCalendarReminder.source, magenta), lessThan(3));
      expect(_hueDistance(detail.source, magenta), lessThan(3));
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
          label: 'Offering Table staged identity',
          eventTitle: 'Day 1: The First Water',
          eventColor: Colors.brown,
          behaviorPayload: const <String, dynamic>{
            'flow_key': 'the-offering-table',
            'kind': 'maat_offering_table_day',
            'day': 1,
          },
          graphicKind: CalendarEventGraphicKind.offeringTable,
        ),
        _PaletteCase(
          label: 'Djed staged identity',
          eventTitle: 'Set your footing',
          eventColor: Colors.orange,
          behaviorPayload: const <String, dynamic>{
            'flow_key': 'the-djed',
            'kind': 'maat_djed_v2_event',
          },
          graphicKind: CalendarEventGraphicKind.djed,
        ),
        _PaletteCase(
          label: 'Reading House staged identity',
          eventTitle: 'Open the Text',
          eventColor: Colors.teal,
          behaviorPayload: const <String, dynamic>{
            'flow_key': 'the-reading-house',
            'kind': 'maat_reading_house_sitting',
          },
          graphicKind: CalendarEventGraphicKind.readingHouse,
        ),
        _PaletteCase(
          label: 'Dawn House Rite',
          flowName: 'Dawn House Rite',
          eventTitle: 'Day 1: Open the House',
          eventColor: Colors.orange,
        ),
        _PaletteCase(
          label: 'Evening Threshold Rite',
          flowName: 'The Closing',
          eventTitle: 'Day 1: Close the threshold',
          eventColor: Colors.deepPurple,
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
          behaviorPayload: c.behaviorPayload,
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
    this.behaviorPayload,
    this.graphicKind,
    this.isReminder = false,
    this.isNutrition = false,
  });

  final String label;
  final String? flowName;
  final Map<String, dynamic>? behaviorPayload;
  final String eventTitle;
  final Color eventColor;
  final CalendarEventGraphicKind? graphicKind;
  final bool isReminder;
  final bool isNutrition;
}

double _hueDistance(Color a, Color b) {
  final aHue = HSLColor.fromColor(a).hue;
  final bHue = HSLColor.fromColor(b).hue;
  final direct = (aHue - bHue).abs();
  return direct > 180 ? 360 - direct : direct;
}
