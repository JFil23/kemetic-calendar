// lib/features/calendar/day_view.dart
//
// Day View - 24-hour timeline with pixel-perfect event layout
// Uses EventLayoutEngine for consistent positioning
//

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/shared/glossy_text.dart';
import 'package:mobile/core/touch_targets.dart';
import 'calendar_page.dart';
import 'day_view_chrome.dart';
import 'landscape_month_view.dart';
import 'track_sky_flow.dart';
import '../onboarding/day_view_date_coachmark.dart';
import '../../widgets/kemetic_day_info.dart';
import 'package:mobile/core/day_key.dart';
import '../../data/user_events_repo.dart';
import '../journal/journal_event_badge.dart';
import '../../utils/external_link_utils.dart';

const double _kMinEventBlockHeight = 64.0; // was 32.0
const double _kTimelineLabelWidth = 60.0;
const double _kTimelineRightPadding = 16.0;
const double _kEventColumnGap = 4.0;
const double _kSingleEventWidthFactor = 0.8;
const Color _dayGold = KemeticGold.base;
const String _kNewEventPreviewClientEventId = '__day_view_new_event_preview__';
const TextStyle _goldHeaderStyle = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w600,
  fontFamily: 'GentiumPlus',
  fontFamilyFallback: ['NotoSans', 'Roboto', 'Arial', 'sans-serif'],
);

bool _isTrackSkyFlowName(String? name) {
  final normalized = name?.trim().toLowerCase();
  return normalized == 'follow the sky' || normalized == 'track the sky';
}

enum _TrackSkyCardKind {
  moon,
  lunarEclipse,
  solarEclipse,
  meteor,
  planet,
  solarSeason,
  genericSky,
}

class _TrackSkyCardSpec {
  final _TrackSkyCardKind kind;
  final Gradient background;
  final Color borderColor;
  final Color accentColor;
  final Color accentSecondaryColor;
  final Color titleColor;
  final Color labelColor;
  final Color detailColor;
  final Color glowColor;

  const _TrackSkyCardSpec({
    required this.kind,
    required this.background,
    required this.borderColor,
    required this.accentColor,
    required this.accentSecondaryColor,
    required this.titleColor,
    required this.labelColor,
    required this.detailColor,
    required this.glowColor,
  });
}

_TrackSkyCardKind _trackSkyCardKindForTitle(String title) {
  if (title.contains('solar eclipse') || title.contains('ring of fire')) {
    return _TrackSkyCardKind.solarEclipse;
  }
  if (title.contains('lunar eclipse') ||
      title.contains('blood moon') ||
      title.contains('penumbral') ||
      title.contains('partial lunar')) {
    return _TrackSkyCardKind.lunarEclipse;
  }
  if (title.contains('moon')) return _TrackSkyCardKind.moon;
  if (title.contains('lyrids') ||
      title.contains('aquariids') ||
      title.contains('perseids') ||
      title.contains('geminids') ||
      title.contains('quadrantids') ||
      title.contains('meteor')) {
    return _TrackSkyCardKind.meteor;
  }
  if (title.contains('equinox') || title.contains('solstice')) {
    return _TrackSkyCardKind.solarSeason;
  }
  if (title.contains('planet') ||
      title.contains('conjunction') ||
      title.contains('opposition') ||
      title.contains('elongation') ||
      title.contains('venus') ||
      title.contains('mars') ||
      title.contains('jupiter') ||
      title.contains('saturn') ||
      title.contains('mercury')) {
    return _TrackSkyCardKind.planet;
  }
  return _TrackSkyCardKind.genericSky;
}

Color _trackSkyMoonTint(String title) {
  if (title.contains('blood')) return const Color(0xFFC7655D);
  if (title.contains('blue moon')) return const Color(0xFFA8D6FF);
  if (title.contains('pink')) return const Color(0xFFF5B4D7);
  if (title.contains('flower')) return const Color(0xFFFFE3B0);
  if (title.contains('strawberry')) return const Color(0xFFF39AA6);
  if (title.contains('harvest')) return const Color(0xFFF5C46B);
  if (title.contains('hunter')) return const Color(0xFFCF925B);
  if (title.contains('snow') || title.contains('cold')) {
    return const Color(0xFFEAF5FF);
  }
  if (title.contains('wolf')) return const Color(0xFFD9E6FF);
  if (title.contains('beaver')) return const Color(0xFFD7B58F);
  if (title.contains('buck')) return const Color(0xFFE0BF8C);
  if (title.contains('sturgeon')) return const Color(0xFFE7EEF9);
  return const Color(0xFFF4E7CF);
}

Color _trackSkyMeteorTint(String title) {
  if (title.contains('perseids')) return const Color(0xFF9FCAFF);
  if (title.contains('geminids')) return const Color(0xFFA9F5EF);
  if (title.contains('lyrids')) return const Color(0xFFD7C3FF);
  if (title.contains('quadrantids')) return const Color(0xFFEAF5FF);
  if (title.contains('aquariids')) return const Color(0xFF8DEAF7);
  return const Color(0xFFB9D0FF);
}

Color _trackSkyPlanetTint(String title) {
  if (title.contains('mars')) return const Color(0xFFE17D5D);
  if (title.contains('venus')) return const Color(0xFFF6E2C0);
  if (title.contains('jupiter')) return const Color(0xFFF4C88D);
  if (title.contains('saturn')) return const Color(0xFFE8D27A);
  if (title.contains('mercury')) return const Color(0xFFD9E1F0);
  return const Color(0xFFBFD2FF);
}

Color _trackSkySolarTint(String title) {
  if (title.contains('winter')) return const Color(0xFFF1D4A3);
  if (title.contains('summer')) return const Color(0xFFF7B45A);
  if (title.contains('autumn')) return const Color(0xFFF19A62);
  if (title.contains('vernal') || title.contains('spring')) {
    return const Color(0xFFF8CDA0);
  }
  return const Color(0xFFF3C47E);
}

_TrackSkyCardSpec _trackSkyCardSpecForEvent(EventItem event) {
  final title = event.title.trim().toLowerCase();
  final kind = _trackSkyCardKindForTitle(title);
  switch (kind) {
    case _TrackSkyCardKind.moon:
      final tint = _trackSkyMoonTint(title);
      return _TrackSkyCardSpec(
        kind: kind,
        background: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF040813),
            Color.lerp(const Color(0xFF16245D), tint, 0.16)!,
            const Color(0xFF2A1F52),
          ],
        ),
        borderColor: tint.withValues(alpha: 0.78),
        accentColor: tint,
        accentSecondaryColor: Colors.white,
        titleColor: const Color(0xFFF7FAFF),
        labelColor: const Color(0xFFE3EAFF),
        detailColor: const Color(0xFFD9E4FF),
        glowColor: tint.withValues(alpha: 0.56),
      );
    case _TrackSkyCardKind.lunarEclipse:
      final tint = _trackSkyMoonTint(title);
      return _TrackSkyCardSpec(
        kind: kind,
        background: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF05070F),
            Color.lerp(const Color(0xFF301126), tint, 0.34)!,
            const Color(0xFF120812),
          ],
        ),
        borderColor: tint.withValues(alpha: 0.82),
        accentColor: tint,
        accentSecondaryColor: const Color(0xFFFFD7BF),
        titleColor: const Color(0xFFFFF6F1),
        labelColor: const Color(0xFFFFE8DD),
        detailColor: const Color(0xFFFFD9CC),
        glowColor: tint.withValues(alpha: 0.56),
      );
    case _TrackSkyCardKind.solarEclipse:
      final tint = title.contains('ring of fire')
          ? const Color(0xFFFFA24B)
          : const Color(0xFFF4E6C1);
      return _TrackSkyCardSpec(
        kind: kind,
        background: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF03050B), Color(0xFF171B2E), Color(0xFF090B14)],
        ),
        borderColor: tint.withValues(alpha: 0.84),
        accentColor: tint,
        accentSecondaryColor: const Color(0xFFFFD26A),
        titleColor: const Color(0xFFFFF8EF),
        labelColor: const Color(0xFFFFEED5),
        detailColor: const Color(0xFFFFDCB0),
        glowColor: tint.withValues(alpha: 0.58),
      );
    case _TrackSkyCardKind.meteor:
      final tint = _trackSkyMeteorTint(title);
      return _TrackSkyCardSpec(
        kind: kind,
        background: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF050816),
            Color.lerp(const Color(0xFF1E1B54), tint, 0.2)!,
            const Color(0xFF0C1029),
          ],
        ),
        borderColor: tint.withValues(alpha: 0.82),
        accentColor: tint,
        accentSecondaryColor: Colors.white,
        titleColor: const Color(0xFFF4F8FF),
        labelColor: const Color(0xFFDCE8FF),
        detailColor: const Color(0xFFCAE3FF),
        glowColor: tint.withValues(alpha: 0.55),
      );
    case _TrackSkyCardKind.planet:
      final tint = _trackSkyPlanetTint(title);
      return _TrackSkyCardSpec(
        kind: kind,
        background: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF050915),
            Color.lerp(const Color(0xFF13224B), tint, 0.18)!,
            const Color(0xFF161038),
          ],
        ),
        borderColor: tint.withValues(alpha: 0.8),
        accentColor: tint,
        accentSecondaryColor: const Color(0xFFE9EFFF),
        titleColor: const Color(0xFFF8FAFF),
        labelColor: const Color(0xFFDDE6FF),
        detailColor: const Color(0xFFD7E2FF),
        glowColor: tint.withValues(alpha: 0.52),
      );
    case _TrackSkyCardKind.solarSeason:
      final tint = _trackSkySolarTint(title);
      return _TrackSkyCardSpec(
        kind: kind,
        background: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF071326),
            Color.lerp(const Color(0xFF5C2F57), tint, 0.26)!,
            Color.lerp(const Color(0xFFF18E5B), tint, 0.4)!,
          ],
          stops: const [0.0, 0.58, 1.0],
        ),
        borderColor: tint.withValues(alpha: 0.84),
        accentColor: tint,
        accentSecondaryColor: const Color(0xFFFFE7B8),
        titleColor: const Color(0xFFFFFAF1),
        labelColor: const Color(0xFFFFEFD5),
        detailColor: const Color(0xFFFFE1B7),
        glowColor: tint.withValues(alpha: 0.56),
      );
    case _TrackSkyCardKind.genericSky:
      return const _TrackSkyCardSpec(
        kind: _TrackSkyCardKind.genericSky,
        background: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF090D1E), Color(0xFF222A5B), Color(0xFF4B5EBB)],
        ),
        borderColor: Color(0xFFA4B1FF),
        accentColor: Color(0xFFDCE6FF),
        accentSecondaryColor: Colors.white,
        titleColor: Color(0xFFF8FAFF),
        labelColor: Color(0xFFE0E8FF),
        detailColor: Color(0xFFD8E2FF),
        glowColor: Color(0x88A4B1FF),
      );
  }
}

List<Widget> _buildTrackSkyCardStars({
  required String seed,
  required Color tint,
  required bool compact,
}) {
  final random = math.Random(seed.hashCode & 0x7fffffff);
  final count = compact ? 7 : 11;
  return List<Widget>.generate(count, (index) {
    final x = (-0.88 + random.nextDouble() * 1.76).clamp(-1.0, 1.0);
    final y = (-0.86 + random.nextDouble() * 1.72).clamp(-1.0, 1.0);
    final size = compact
        ? 0.9 + random.nextDouble() * 1.2
        : 1.0 + random.nextDouble() * 1.9;
    final opacity = 0.2 + random.nextDouble() * 0.42;
    final color = (index % 3 == 0 ? tint : Colors.white).withValues(
      alpha: opacity,
    );
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: Alignment(x.toDouble(), y.toDouble()),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color, blurRadius: compact ? 1.2 : 2.8),
              ],
            ),
          ),
        ),
      ),
    );
  });
}

Widget _buildTrackSkyCardAccent(
  _TrackSkyCardSpec spec,
  String title, {
  double size = 24,
}) {
  final lower = title.toLowerCase();

  Widget planet({
    required Color color,
    double? diameter,
    BoxBorder? border,
    List<BoxShadow>? shadow,
  }) {
    final d = diameter ?? size;
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: border,
        boxShadow: shadow,
      ),
    );
  }

  switch (spec.kind) {
    case _TrackSkyCardKind.moon:
      return planet(
        color: spec.accentColor,
        shadow: [
          BoxShadow(
            color: spec.glowColor.withValues(alpha: 0.42),
            blurRadius: 10,
          ),
        ],
      );
    case _TrackSkyCardKind.lunarEclipse:
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            planet(
              color: spec.accentColor,
              shadow: [
                BoxShadow(
                  color: spec.glowColor.withValues(alpha: 0.38),
                  blurRadius: 9,
                ),
              ],
            ),
            Positioned(
              left: size * (lower.contains('penumbral') ? 0.16 : 0.28),
              top: size * 0.05,
              child: planet(
                color: const Color(0xCC03050B),
                diameter: size * 0.82,
              ),
            ),
          ],
        ),
      );
    case _TrackSkyCardKind.solarEclipse:
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            planet(
              color: Colors.transparent,
              border: Border.all(color: spec.accentColor, width: 2),
              shadow: [
                BoxShadow(
                  color: spec.glowColor.withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ],
            ),
            planet(color: const Color(0xFF04060D), diameter: size * 0.64),
          ],
        ),
      );
    case _TrackSkyCardKind.meteor:
      return SizedBox(
        width: size + 10,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: 0,
              top: 5,
              child: planet(
                color: Colors.white,
                diameter: size * 0.28,
                shadow: [
                  BoxShadow(
                    color: spec.glowColor.withValues(alpha: 0.58),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 8,
              child: Transform.rotate(
                angle: -0.35,
                child: Container(
                  width: size * 0.85,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        spec.accentColor.withValues(alpha: 0.2),
                        spec.accentColor.withValues(alpha: 0.72),
                        Colors.white,
                      ],
                      stops: const [0.0, 0.34, 0.72, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    case _TrackSkyCardKind.planet:
      if (lower.contains('saturn')) {
        return SizedBox(
          width: size + 6,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: -0.25,
                child: Container(
                  width: size + 6,
                  height: 8,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: spec.accentSecondaryColor.withValues(alpha: 0.84),
                      width: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              planet(color: spec.accentColor, diameter: size * 0.62),
            ],
          ),
        );
      }
      if (lower.contains('conjunction')) {
        return SizedBox(
          width: size + 8,
          height: size,
          child: Stack(
            children: [
              Positioned(
                right: 0,
                top: 2,
                child: planet(
                  color: spec.accentSecondaryColor,
                  diameter: size * 0.46,
                ),
              ),
              Positioned(
                left: 0,
                bottom: 2,
                child: planet(color: spec.accentColor, diameter: size * 0.62),
              ),
            ],
          ),
        );
      }
      if (lower.contains('parade')) {
        final colors = [
          spec.accentColor,
          spec.accentSecondaryColor,
          const Color(0xFFE7C8FF),
        ];
        return SizedBox(
          width: size + 10,
          height: size,
          child: Stack(
            children: [
              for (int i = 0; i < colors.length; i++)
                Positioned(
                  left: i * 7.0,
                  top: i.isEven ? 1.5 : 5,
                  child: planet(color: colors[i], diameter: 5.2),
                ),
            ],
          ),
        );
      }
      return planet(
        color: spec.accentColor,
        shadow: [
          BoxShadow(
            color: spec.glowColor.withValues(alpha: 0.42),
            blurRadius: 8,
          ),
        ],
      );
    case _TrackSkyCardKind.solarSeason:
      return SizedBox(
        width: size + 8,
        height: size,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 2,
              child: Container(
                height: 1.6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      spec.accentSecondaryColor.withValues(alpha: 0.48),
                      spec.accentSecondaryColor,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 3,
              bottom: 2,
              child: planet(
                color: spec.accentColor,
                diameter: 8,
                shadow: [
                  BoxShadow(
                    color: spec.glowColor.withValues(alpha: 0.45),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    case _TrackSkyCardKind.genericSky:
      return planet(
        color: spec.accentSecondaryColor,
        diameter: 8,
        shadow: [
          BoxShadow(
            color: spec.glowColor.withValues(alpha: 0.42),
            blurRadius: 8,
          ),
        ],
      );
  }
}

// ========================================
// EVENT LAYOUT ENGINE
// ========================================

class EventLayoutEngine {
  static List<PositionedEventBlock> layoutEventsForDay({
    required List<NoteData> notes,
    required Map<int, FlowData> flowIndex,
    required double availableWidth,
    required double columnGap,
    required double textScale,
    required int day, // For debug logging
  }) {
    if (kDebugMode) {
      print('[EventLayoutEngine] Layout for day $day: ${notes.length} notes');
    }

    final events = _sortedEventsForDay(notes: notes, flowIndex: flowIndex);

    return layoutEventItems(
      events: events,
      availableWidth: availableWidth,
      columnGap: columnGap,
      textScale: textScale,
      day: day,
    );
  }

  static List<PositionedEventBlock> layoutEventItems({
    required List<EventItem> events,
    required double availableWidth,
    required double columnGap,
    required double textScale,
    required int day,
  }) {
    if (events.isEmpty) return [];

    final sortedEvents = [...events]..sort(_compareEventItemsBySchedule);
    final overlapGroups = _buildOverlapGroups(
      sortedEvents,
      textScale: textScale,
    );
    final blocks = <PositionedEventBlock>[];

    for (final group in overlapGroups) {
      final columnAssignments = _assignColumns(group, textScale: textScale);
      final highestColumn = columnAssignments.values.fold<int>(0, math.max);
      final totalColumns = highestColumn + 1;
      final columnWidth = _columnWidthForGroup(
        availableWidth: availableWidth,
        columnGap: columnGap,
        totalColumns: totalColumns,
      );

      for (final event in group) {
        final column = columnAssignments[event] ?? 0;
        final leftOffset = column * (columnWidth + columnGap);
        blocks.add(
          PositionedEventBlock(
            event: event,
            leftOffset: leftOffset,
            width: columnWidth,
          ),
        );
      }
    }

    blocks.sort((a, b) {
      final scheduleCmp = _compareEventItemsBySchedule(a.event, b.event);
      if (scheduleCmp != 0) return scheduleCmp;

      final leftCmp = a.leftOffset.compareTo(b.leftOffset);
      if (leftCmp != 0) return leftCmp;

      return a.width.compareTo(b.width);
    });

    if (kDebugMode) {
      print(
        '[EventLayoutEngine] Generated ${blocks.length} positioned blocks for day $day',
      );
    }

    return blocks;
  }

  static List<List<EventItem>> _buildOverlapGroups(
    List<EventItem> events, {
    required double textScale,
  }) {
    final groups = <List<EventItem>>[];
    var currentGroup = <EventItem>[];
    var currentGroupMaxBottom = -1.0;

    for (final event in events) {
      if (currentGroup.isEmpty) {
        currentGroup = [event];
        currentGroupMaxBottom = _eventVisualEndMin(event, textScale: textScale);
        continue;
      }

      if (event.startMin < currentGroupMaxBottom) {
        currentGroup.add(event);
        currentGroupMaxBottom = math.max(
          currentGroupMaxBottom,
          _eventVisualEndMin(event, textScale: textScale),
        );
        continue;
      }

      groups.add(currentGroup);
      currentGroup = [event];
      currentGroupMaxBottom = _eventVisualEndMin(event, textScale: textScale);
    }

    if (currentGroup.isNotEmpty) {
      groups.add(currentGroup);
    }

    return groups;
  }

  static double _columnWidthForGroup({
    required double availableWidth,
    required double columnGap,
    required int totalColumns,
  }) {
    if (totalColumns <= 1) {
      return availableWidth * _kSingleEventWidthFactor;
    }
    final totalGap = columnGap * (totalColumns - 1);
    return math.max((availableWidth - totalGap) / totalColumns, 0.0);
  }

  static Map<EventItem, int> _assignColumns(
    List<EventItem> events, {
    required double textScale,
  }) {
    final assignments = <EventItem, int>{};
    final columnBottoms = <int, double>{}; // column -> rendered visual bottom

    for (final event in events) {
      // Find first available column
      int column = 0;
      while (columnBottoms.containsKey(column) &&
          columnBottoms[column]! > event.startMin) {
        column++;
      }

      assignments[event] = column;
      columnBottoms[column] = _eventVisualEndMin(event, textScale: textScale);
    }

    return assignments;
  }
}

// ========================================
// DATA MODELS
// ========================================

class NoteData {
  final String? id;
  final String? clientEventId;
  final String title;
  final String? detail;
  final String? location;
  final bool allDay;
  final TimeOfDay? start;
  final TimeOfDay? end;
  final int? flowId;
  final Color? manualColor;
  final String? category;
  final bool isReminder;
  final String? reminderId;

  const NoteData({
    this.id,
    this.clientEventId,
    required this.title,
    this.detail,
    this.location,
    required this.allDay,
    this.start,
    this.end,
    this.flowId,
    this.manualColor,
    this.category,
    this.isReminder = false,
    this.reminderId,
  });
}

class FlowData {
  final int id;
  final String name;
  final Color color;
  final bool active;
  final String? notes;

  const FlowData({
    required this.id,
    required this.name,
    required this.color,
    required this.active,
    this.notes,
  });
}

class EventItem {
  final String? id;
  final String? clientEventId;
  final String title;
  final String? detail;
  final String? location;
  final int startMin;
  final int endMin;
  final int? flowId;
  final Color color;
  final Color? manualColor;
  final bool allDay;
  final String? category;
  final bool isReminder;
  final String? reminderId;

  const EventItem({
    this.id,
    this.clientEventId,
    required this.title,
    this.detail,
    this.location,
    required this.startMin,
    required this.endMin,
    this.flowId,
    required this.color,
    this.manualColor,
    required this.allDay,
    this.category,
    this.isReminder = false,
    this.reminderId,
  });

  @override
  String toString() {
    return 'EventItem(title: "$title", flowId: $flowId, color: $color, startMin: $startMin)';
  }
}

class DayViewSheetEventTarget {
  final int ky;
  final int km;
  final int kd;
  final EventItem event;

  const DayViewSheetEventTarget({
    required this.ky,
    required this.km,
    required this.kd,
    required this.event,
  });
}

List<NoteData> _dedupeDayNotesForUi(List<NoteData> notes) {
  if (notes.isEmpty) return notes;

  final seen = <String, NoteData>{};

  for (final note in notes) {
    final flowKey = note.flowId?.toString() ?? 'NO_FLOW';

    String startKey;
    String endKey;

    if (note.allDay) {
      startKey = 'ALLDAY';
      endKey = 'ALLDAY';
    } else if (note.start != null && note.end != null) {
      startKey = '${note.start!.hour * 60 + note.start!.minute}';
      endKey = '${note.end!.hour * 60 + note.end!.minute}';
    } else {
      startKey = 'NO_START';
      endKey = 'NO_END';
    }

    final titleKey = note.title.trim().toLowerCase();
    final key = '$flowKey|$startKey|$endKey|$titleKey';

    if (!seen.containsKey(key)) {
      seen[key] = note;
      continue;
    }

    final existing = seen[key]!;
    bool hasIdentity(NoteData n) =>
        (n.id != null && n.id!.trim().isNotEmpty) ||
        (n.clientEventId != null && n.clientEventId!.trim().isNotEmpty);

    if (!hasIdentity(existing) && hasIdentity(note)) {
      seen[key] = note;
    }
  }

  return seen.values.toList();
}

EventItem _eventItemFromNote(NoteData note, Map<int, FlowData> flowIndex) {
  final startMin = note.allDay
      ? 9 * 60
      : (note.start?.hour ?? 9) * 60 + (note.start?.minute ?? 0);
  final endMin = note.allDay
      ? 17 * 60
      : (note.end?.hour ?? 17) * 60 + (note.end?.minute ?? 0);

  Color eventColor = Colors.blue;
  if (note.manualColor != null) {
    eventColor = note.manualColor!;
  } else if (note.flowId != null) {
    final flow = flowIndex[note.flowId];
    if (flow != null) {
      eventColor = flow.color;
    }
  }

  return EventItem(
    id: note.id,
    clientEventId: note.clientEventId,
    title: note.title,
    detail: note.detail,
    location: note.location,
    startMin: startMin,
    endMin: endMin,
    flowId: note.flowId,
    color: eventColor,
    manualColor: note.manualColor,
    allDay: note.allDay,
    category: note.category,
    isReminder: note.isReminder,
    reminderId: note.reminderId,
  );
}

String _eventIdentityKey(EventItem event) {
  final id = event.id?.trim();
  if (id != null && id.isNotEmpty) return 'id:$id';

  final clientEventId = event.clientEventId?.trim();
  if (clientEventId != null && clientEventId.isNotEmpty) {
    return 'cid:$clientEventId';
  }

  final reminderId = event.reminderId?.trim();
  if (reminderId != null && reminderId.isNotEmpty) {
    return 'rid:$reminderId';
  }

  return [
    event.title.trim().toLowerCase(),
    event.startMin,
    event.endMin,
    event.flowId ?? '',
    event.location?.trim().toLowerCase() ?? '',
    event.detail?.trim().toLowerCase() ?? '',
    event.allDay,
    event.isReminder,
  ].join('|');
}

bool _eventsShareStableIdentity(EventItem a, EventItem b) {
  final aId = a.id?.trim();
  final bId = b.id?.trim();
  if (aId != null && aId.isNotEmpty && bId != null && bId.isNotEmpty) {
    return aId == bId;
  }

  final aClientId = a.clientEventId?.trim();
  final bClientId = b.clientEventId?.trim();
  if (aClientId != null &&
      aClientId.isNotEmpty &&
      bClientId != null &&
      bClientId.isNotEmpty) {
    return aClientId == bClientId;
  }

  final aReminderId = a.reminderId?.trim();
  final bReminderId = b.reminderId?.trim();
  if (aReminderId != null &&
      aReminderId.isNotEmpty &&
      bReminderId != null &&
      bReminderId.isNotEmpty) {
    return aReminderId == bReminderId;
  }

  return _eventIdentityKey(a) == _eventIdentityKey(b);
}

bool _eventsOverlap(EventItem a, EventItem b, {double textScale = 1.0}) {
  return _eventVisualTop(a) < _eventVisualEndMin(b, textScale: textScale) &&
      _eventVisualTop(b) < _eventVisualEndMin(a, textScale: textScale);
}

double _eventVisualTop(EventItem event) => event.startMin.toDouble();

double _eventVisualHeightForLayout(EventItem event, {double textScale = 1.0}) {
  final bool showTitle = event.title.trim().isNotEmpty;
  final bool showLocation =
      event.location != null && event.location!.trim().isNotEmpty;

  int durationMinutes = event.endMin - event.startMin;
  if (durationMinutes <= 0) {
    durationMinutes = 15;
  }
  if (durationMinutes > 180) {
    durationMinutes = 180;
  }

  final int reminderLineCount = (showTitle ? 1 : 0) + (showLocation ? 1 : 0);
  final double reminderHeight = math.max(
    _kMinEventBlockHeight / 2,
    (reminderLineCount * (14.0 * textScale)) + 12,
  );

  if (event.isReminder) {
    return reminderHeight;
  }

  final double rawHeight = durationMinutes.toDouble();
  return rawHeight < _kMinEventBlockHeight ? _kMinEventBlockHeight : rawHeight;
}

double _eventVisualEndMin(EventItem event, {double textScale = 1.0}) {
  return _eventVisualTop(event) +
      _eventVisualHeightForLayout(event, textScale: textScale);
}

int _compareEventItemsBySchedule(EventItem a, EventItem b) {
  final startCmp = a.startMin.compareTo(b.startMin);
  if (startCmp != 0) return startCmp;

  final endCmp = a.endMin.compareTo(b.endMin);
  if (endCmp != 0) return endCmp;

  return _eventIdentityKey(a).compareTo(_eventIdentityKey(b));
}

List<EventItem> _sortedEventsForDay({
  required List<NoteData> notes,
  required Map<int, FlowData> flowIndex,
}) {
  final events = [
    for (final note in notes) _eventItemFromNote(note, flowIndex),
  ];
  events.sort(_compareEventItemsBySchedule);
  return events;
}

class _DragPayload {
  final EventItem event;

  _DragPayload(this.event);

  int get durationMin =>
      (event.endMin - event.startMin).clamp(15, 12 * 60) as int;
}

class PositionedEventBlock {
  final EventItem event;
  final double leftOffset;
  final double width;

  const PositionedEventBlock({
    required this.event,
    required this.leftOffset,
    required this.width,
  });
}

class _ConstantIntListenable implements ValueListenable<int> {
  const _ConstantIntListenable(this.value);

  @override
  final int value;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

const _kZeroListenable = _ConstantIntListenable(0);

// Lightweight draft event used for long-press creation.

// ========================================
// DAY VIEW PAGE (Main entry point)
// ========================================

class DayViewPage extends StatefulWidget {
  final int initialKy;
  final int initialKm;
  final int initialKd;
  final bool showGregorian;
  final List<NoteData> Function(int ky, int km, int kd) notesForDay;
  final Map<int, FlowData> flowIndex;
  final Map<int, FlowData> Function()? flowIndexBuilder;
  final ValueListenable<int>? dataVersion;
  final String Function(int km) getMonthName;
  final double? initialScrollOffset; // optional: jump to a target time on open
  final int? focusStartMin; // minutes since midnight to auto-scroll/highlight
  final int? focusFlowId; // highlight a flow's events
  final String? focusTitle; // highlight by title when flow id missing
  final void Function(int?)? onManageFlows; // NEW: Callback to open My Flows
  final Future<void> Function(BuildContext context)? onShowActionsMenu;
  final Future<void> Function(BuildContext context)? onOpenQuickAdd;
  final Future<void> Function(BuildContext context)? onOpenProfile;
  final void Function(int ky, int km, int kd)? onAddNote;
  final Future<void> Function(int ky, int km, int kd, EventItem event)?
  onDeleteNote;
  final Future<void> Function(int ky, int km, int kd, EventItem event)?
  onEditNote;
  final Future<void> Function(
    int ky,
    int km,
    int kd,
    EventItem evt,
    int newStartMin,
  )?
  onMoveEventTime;
  final Future<void> Function(EventItem event)? onShareNote;
  final Future<void> Function(String reminderId)? onEditReminder;
  final Future<void> Function(String reminderId)? onEndReminder;
  final Future<void> Function(EventItem event)? onShareReminder;
  final void Function(
    int ky,
    int km,
    int kd, {
    TimeOfDay? start,
    TimeOfDay? end,
    bool allDay,
  })?
  onOpenAddNoteWithTime;
  // Optional: create a timed event directly (long-press)
  final void Function(
    int ky,
    int km,
    int kd, {
    required String title,
    String? detail,
    String? location,
    required TimeOfDay start,
    required TimeOfDay end,
    bool allDay,
  })?
  onCreateTimedEvent;

  /// Called when user taps "End Flow" on a flow event in the info bar.
  /// If null, the End Flow button is hidden.
  final void Function(int flowId)? onEndFlow;
  final Future<void> Function(String text)? onAppendToJournal;
  final Future<void> Function(int flowId)? onSaveFlow;
  final Future<Set<String>> Function({int? flowId, DateTime? completedOnDate})?
  loadCompletedClientEventIds;
  final Future<void> Function({
    required String clientEventId,
    required int flowId,
    required DateTime completedOnDate,
  })?
  onRecordCompletion;
  final Future<void> Function(String clientEventId)? onUnrecordCompletion;
  final bool showDayCardRevealCoachmarkForOnboarding;
  final VoidCallback? onDayCardRevealCoachmarkCompleted;

  const DayViewPage({
    super.key,
    required this.initialKy,
    required this.initialKm,
    required this.initialKd,
    required this.showGregorian,
    required this.notesForDay,
    required this.flowIndex,
    this.flowIndexBuilder,
    this.dataVersion,
    required this.getMonthName,
    this.initialScrollOffset,
    this.focusStartMin,
    this.focusFlowId,
    this.focusTitle,
    this.onManageFlows, // NEW
    this.onShowActionsMenu,
    this.onOpenQuickAdd,
    this.onOpenProfile,
    this.onAddNote, // 🔧 NEW
    this.onDeleteNote,
    this.onEditNote,
    this.onMoveEventTime,
    this.onShareNote,
    this.onEditReminder,
    this.onEndReminder,
    this.onShareReminder,
    this.onOpenAddNoteWithTime,
    this.onCreateTimedEvent, // NEW
    this.onEndFlow,
    this.onAppendToJournal,
    this.onSaveFlow,
    this.loadCompletedClientEventIds,
    this.onRecordCompletion,
    this.onUnrecordCompletion,
    this.showDayCardRevealCoachmarkForOnboarding = false,
    this.onDayCardRevealCoachmarkCompleted,
  });

  @override
  State<DayViewPage> createState() => _DayViewPageState();
}

class _DayViewPageState extends State<DayViewPage> {
  late PageController _pageController;
  late int _currentKy;
  late int _currentKm;
  late int _currentKd;
  late bool _showGregorian;
  late DateTime _initialGregorian; // Added for stable date arithmetic
  static const int _centerPage = 5000;
  int _gridInstance = 0; // Forces grid rebuilds when jumping
  double? _savedScrollOffset; // Added for scroll persistence

  // ✅ Today button guard to prevent duplicate state updates
  bool _isJumpingToToday = false;

  // 🔧 ADD THIS: Persistent scroll controller for mini calendar
  late ScrollController _miniCalendarScrollController;

  // 🔧 NEW: Orientation tracking for bidirectional lock
  Orientation? _lastOrientation;
  bool _showDayCardRevealCoachmark = false;
  bool _hasResolvedDayCardRevealCoachmarkOnboarding = false;
  final GlobalKey _dayCardRevealTargetKey = GlobalKey(
    debugLabel: 'day_view_date_reveal_target',
  );

  @override
  void initState() {
    super.initState();
    _currentKy = widget.initialKy;
    _currentKm = widget.initialKm;
    _currentKd = widget.initialKd;
    _showGregorian = widget.showGregorian;
    _initialGregorian = KemeticMath.toGregorian(
      _currentKy,
      _currentKm,
      _currentKd,
    );
    _savedScrollOffset = widget.initialScrollOffset;
    _pageController = PageController(initialPage: _centerPage);

    // 🔧 Initialize mini calendar scroll controller with starting position
    final dayCount = _currentKm == 13
        ? (KemeticMath.isLeapKemeticYear(_currentKy) ? 6 : 5)
        : 30;
    final initialScroll =
        ((_currentKd - 5).clamp(
          0,
          (dayCount - 10).clamp(0, dayCount),
        )).toDouble() *
        34; // 30 width + 4 margin
    _miniCalendarScrollController = ScrollController(
      initialScrollOffset: initialScroll,
    );
    _scheduleDayCardRevealCoachmarkCheck();
  }

  @override
  void didUpdateWidget(covariant DayViewPage old) {
    super.didUpdateWidget(old);
    if (!old.showDayCardRevealCoachmarkForOnboarding &&
        widget.showDayCardRevealCoachmarkForOnboarding) {
      _scheduleDayCardRevealCoachmarkCheck();
    }
    if (old.showGregorian != widget.showGregorian) {
      _showGregorian = widget.showGregorian;
    }
    if (old.initialKy != widget.initialKy ||
        old.initialKm != widget.initialKm ||
        old.initialKd != widget.initialKd) {
      final g = KemeticMath.toGregorian(
        widget.initialKy,
        widget.initialKm,
        widget.initialKd ?? 1,
      );
      setState(() {
        _initialGregorian = g;
        _currentKy = widget.initialKy;
        _currentKm = widget.initialKm;
        _currentKd = widget.initialKd ?? 1;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_centerPage); // reset paging anchor
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollMiniCalendarToCenter(_currentKd); // keep gold circle centered
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _miniCalendarScrollController.dispose(); // 🔧 Don't forget to dispose
    super.dispose();
  }

  void _toggleDateDisplay() {
    if (!mounted) return;
    setState(() {
      _showGregorian = !_showGregorian;
    });
  }

  String _buildHeaderDateLabel(
    BuildContext context,
    DateTime currentGregorian,
  ) {
    if (_showGregorian) {
      return MaterialLocalizations.of(
        context,
      ).formatMediumDate(currentGregorian);
    }

    final kemeticMonthLabel = widget.getMonthName(_currentKm).split(' ').first;
    return '$kemeticMonthLabel $_currentKd, ${currentGregorian.year}';
  }

  void _scheduleDayCardRevealCoachmarkCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybePresentDayCardRevealCoachmark());
    });
  }

  Future<void> _maybePresentDayCardRevealCoachmark() async {
    if (!mounted ||
        _showDayCardRevealCoachmark ||
        !widget.showDayCardRevealCoachmarkForOnboarding) {
      return;
    }
    setState(() => _showDayCardRevealCoachmark = true);
    _markDayCardRevealCoachmarkOnboardingSeen();
    unawaited(_autoDismissDayCardRevealCoachmark());
  }

  Future<void> _handleDayCardRevealCoachmarkCompleted() async {
    if (mounted && _showDayCardRevealCoachmark) {
      setState(() => _showDayCardRevealCoachmark = false);
    }
    _markDayCardRevealCoachmarkOnboardingSeen();
  }

  void _markDayCardRevealCoachmarkOnboardingSeen() {
    if (_hasResolvedDayCardRevealCoachmarkOnboarding) return;
    _hasResolvedDayCardRevealCoachmarkOnboarding = true;
    widget.onDayCardRevealCoachmarkCompleted?.call();
  }

  Future<void> _autoDismissDayCardRevealCoachmark() async {
    await Future<void>.delayed(const Duration(seconds: 4));
    if (!mounted || !_showDayCardRevealCoachmark) return;
    setState(() => _showDayCardRevealCoachmark = false);
  }

  /// Generate the day key for Kemetic day info lookup
  String _getKemeticDayKey(int kYear, int kMonth, int kDay) {
    // kYear parameter kept for API consistency but not used in day key generation.
    // Day keys use DECAN (1-3), not year. Decan is computed from kDay in kemeticDayKey().
    //
    // Guard obvious invalid months; allow epagomenal month 13 but only when
    // we actually have a day card for the generated key (prevents empty dropdowns).
    if (kMonth < 1 || kMonth > 13) {
      return 'unknown_${kDay}_$kYear';
    }

    final key = kemeticDayKey(kMonth, kDay);
    return KemeticDayData.dayInfoMap.containsKey(key)
        ? key
        : 'unknown_${kDay}_$kYear';
  }

  ({int kYear, int kMonth, int kDay}) _dateForPage(int pageIndex) {
    final offset = pageIndex - _centerPage;
    final targetGregorian = _initialGregorian.add(Duration(days: offset));
    return KemeticMath.fromGregorian(targetGregorian);
  }

  void _onPageChanged(int pageIndex) {
    final kDate = _dateForPage(pageIndex);

    setState(() {
      _currentKy = kDate.kYear;
      _currentKm = kDate.kMonth;
      _currentKd = kDate.kDay;
    });

    // ✅ Don't duplicate state updates during Today jump
    if (_isJumpingToToday) return;

    // Animate mini calendar when day changes
    _scrollMiniCalendar();
  }

  void _onScrollChanged(double offset) {
    _savedScrollOffset = offset;
  }

  Future<void> _jumpToToday() async {
    if (_isJumpingToToday || !_pageController.hasClients) return;

    final now = DateTime.now();
    final today = KemeticMath.fromGregorian(now);
    final targetGregorian = KemeticMath.toGregorian(
      today.kYear,
      today.kMonth,
      today.kDay,
    );
    final diffDays = targetGregorian.difference(_initialGregorian).inDays;
    final targetPage = _centerPage + diffDays;

    // Reset saved scroll so the timeline recenters on the current time.
    _savedScrollOffset = null;
    _isJumpingToToday = true;

    try {
      await _pageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
      if (!mounted) return;
      setState(() {
        _currentKy = today.kYear;
        _currentKm = today.kMonth;
        _currentKd = today.kDay;
        _gridInstance++; // rebuild grid to honor cleared scroll offset
      });
      _scrollMiniCalendarToCenter(_currentKd);
    } finally {
      _isJumpingToToday = false;
    }
  }

  // 🔧 ADD THIS METHOD: Animates the mini calendar scroll
  void _scrollMiniCalendar() {
    if (!_miniCalendarScrollController.hasClients) return;

    final dayCount = _currentKm == 13
        ? (KemeticMath.isLeapKemeticYear(_currentKy) ? 6 : 5)
        : 30;

    // Calculate target scroll position (keep current day around position 5)
    final targetScroll =
        ((_currentKd - 5).clamp(
          0,
          (dayCount - 10).clamp(0, dayCount),
        )).toDouble() *
        34; // 30 width + 4 margin

    // Animate to the new position
    _miniCalendarScrollController.animateTo(
      targetScroll,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _scrollMiniCalendarToCenter(int day) {
    // tune to your chip size/gaps; 34.0 is a common width
    const chipW = 34.0;
    const centerIndex = 5; // places selection near the middle of the row
    final target = (day - centerIndex).clamp(0, 27) * chipW;
    if (_miniCalendarScrollController.hasClients) {
      _miniCalendarScrollController.animateTo(
        target.toDouble(),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  Map<int, FlowData> _activeFlowIndex() =>
      widget.flowIndexBuilder?.call() ?? widget.flowIndex;

  List<EventItem> _eventsForKemeticDay(int ky, int km, int kd) {
    final notes = _dedupeDayNotesForUi(widget.notesForDay(ky, km, kd));
    return _sortedEventsForDay(notes: notes, flowIndex: _activeFlowIndex());
  }

  DayViewSheetEventTarget? _resolveAdjacentEventTarget({
    required int ky,
    required int km,
    required int kd,
    required EventItem event,
    required bool forward,
  }) {
    final currentEvents = _eventsForKemeticDay(ky, km, kd);
    final currentIndex = currentEvents.indexWhere(
      (candidate) => _eventsShareStableIdentity(candidate, event),
    );

    if (currentIndex >= 0) {
      final sameDayIndex = forward ? currentIndex + 1 : currentIndex - 1;
      if (sameDayIndex >= 0 && sameDayIndex < currentEvents.length) {
        return DayViewSheetEventTarget(
          ky: ky,
          km: km,
          kd: kd,
          event: currentEvents[sameDayIndex],
        );
      }
    }

    final currentGregorian = KemeticMath.toGregorian(ky, km, kd);
    final direction = forward ? 1 : -1;
    for (int offset = 1; offset <= 366; offset++) {
      final nextGregorian = currentGregorian.add(
        Duration(days: direction * offset),
      );
      final nextKemetic = KemeticMath.fromGregorian(nextGregorian);
      final nextDayEvents = _eventsForKemeticDay(
        nextKemetic.kYear,
        nextKemetic.kMonth,
        nextKemetic.kDay,
      );
      if (nextDayEvents.isEmpty) continue;
      return DayViewSheetEventTarget(
        ky: nextKemetic.kYear,
        km: nextKemetic.kMonth,
        kd: nextKemetic.kDay,
        event: forward ? nextDayEvents.first : nextDayEvents.last,
      );
    }

    return null;
  }

  DayViewSheetEventTarget _resolveCurrentEventTarget(
    DayViewSheetEventTarget target,
  ) {
    final currentEvents = _eventsForKemeticDay(target.ky, target.km, target.kd);
    if (currentEvents.isEmpty) return target;

    for (final candidate in currentEvents) {
      if (!_eventsShareStableIdentity(candidate, target.event)) continue;
      return DayViewSheetEventTarget(
        ky: target.ky,
        km: target.km,
        kd: target.kd,
        event: candidate,
      );
    }

    return target;
  }

  Future<void> _animateToKemeticDate(int ky, int km, int kd) async {
    final targetGregorian = KemeticMath.toGregorian(ky, km, kd);
    final diffDays = targetGregorian.difference(_initialGregorian).inDays;
    final targetPage = _centerPage + diffDays;

    if (_pageController.hasClients) {
      await _pageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    }

    if (!mounted) return;
    setState(() {
      _currentKy = ky;
      _currentKm = km;
      _currentKd = kd;
    });
    _scrollMiniCalendarToCenter(kd);
  }

  // 🔧 NEW: Convert Kemetic date to total days for navigation
  int _kemeticToTotalDays(int ky, int km, int kd) {
    // Approximate total days since epoch
    return ky * 365 + (km - 1) * 30 + kd;
  }

  @override
  Widget build(BuildContext context) {
    final dataListenable = widget.dataVersion ?? _kZeroListenable;
    final size = MediaQuery.sizeOf(context);
    final isTablet = size.shortestSide >= 600;

    return ValueListenableBuilder<int>(
      valueListenable: dataListenable,
      builder: (context, _, __) {
        final reportedOrientation = MediaQuery.of(context).orientation;
        // Tablets should stay on the portrait day view regardless of rotation.
        final effectiveOrientation = isTablet
            ? Orientation.portrait
            : reportedOrientation;

        // Track orientation changes for debugging
        if (_lastOrientation != null &&
            _lastOrientation != effectiveOrientation) {
          if (kDebugMode) {
            print(
              '\n📱 [DAY VIEW] Orientation changed: $_lastOrientation → $effectiveOrientation',
            );
          }
        }
        _lastOrientation = effectiveOrientation;
        final flowIndex = widget.flowIndexBuilder?.call() ?? widget.flowIndex;

        return Scaffold(
          backgroundColor: const Color(0xFF000000), // True black
          body: OrientationBuilder(
            builder: (context, orientation) {
              final orient = isTablet ? Orientation.portrait : orientation;
              if (orient == Orientation.landscape) {
                return LandscapeMonthView(
                  initialKy: _currentKy,
                  initialKm: _currentKm,
                  initialKd: _currentKd,
                  showGregorian: _showGregorian,
                  dataVersion: widget.dataVersion,
                  notesForDay: widget.notesForDay,
                  flowIndex: flowIndex,
                  getMonthName: widget.getMonthName,
                  onManageFlows: widget.onManageFlows,
                  onAddNote: widget.onAddNote,
                  onDeleteNote: widget.onDeleteNote,
                  onEditNote: widget.onEditNote,
                  onMoveEventTime: widget.onMoveEventTime,
                  onMonthChanged: (ky, km) {
                    // ✅ HANDLE MONTH CHANGE IN DAY VIEW
                    if (kDebugMode) {
                      print(
                        '🔄 [DAY VIEW] Landscape month changed: Year $ky, Month $km',
                      );
                    }
                    setState(() {
                      _currentKy = ky;
                      _currentKm = km;
                      // Keep current day if still valid in new month
                      final maxDay = km == 13
                          ? (KemeticMath.isLeapKemeticYear(ky) ? 6 : 5)
                          : 30;
                      if (_currentKd > maxDay) {
                        _currentKd = maxDay;
                      }
                    });
                  },
                  onShareNote: widget.onShareNote,
                  onEditReminder: widget.onEditReminder,
                  onEndReminder: widget.onEndReminder,
                  onShareReminder: widget.onShareReminder,
                  onEndFlow: widget.onEndFlow,
                  onAppendToJournal: widget.onAppendToJournal,
                  onSaveFlow: widget.onSaveFlow,
                );
              }

              // Portrait day view
              final portraitDayView = Column(
                children: [
                  // Custom Apple-style header
                  KemeticDayViewHeader(
                    currentKy: _currentKy,
                    currentKm: _currentKm,
                    currentKd: _currentKd,
                    showGregorian: _showGregorian,
                    getMonthName: widget.getMonthName,
                    miniCalendarScrollController: _miniCalendarScrollController,
                    onSelectDay: (day) {
                      final currentGregorian = KemeticMath.toGregorian(
                        _currentKy,
                        _currentKm,
                        _currentKd,
                      );
                      final targetGregorian = KemeticMath.toGregorian(
                        _currentKy,
                        _currentKm,
                        day,
                      );
                      final offsetDays = targetGregorian
                          .difference(currentGregorian)
                          .inDays;
                      if (!_pageController.hasClients) return;
                      final basePage =
                          _pageController.page?.round() ?? _centerPage;
                      final targetPage = basePage + offsetDays;

                      _pageController.animateToPage(
                        targetPage,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
                    onToggleDateDisplay: _toggleDateDisplay,
                    onClose: () => Navigator.pop(context),
                    onJumpToToday: _jumpToToday,
                    onOpenQuickAdd:
                        widget.onOpenQuickAdd ??
                        (btnCtx) async {
                          final state = CalendarPage.globalKey.currentState;
                          if (state != null) {
                            await state.openQuickAddFromOutside();
                            return;
                          }
                          if (!btnCtx.mounted) return;
                          ScaffoldMessenger.of(btnCtx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'New note is unavailable right now.',
                              ),
                            ),
                          );
                        },
                    onShowActionsMenu:
                        widget.onShowActionsMenu ??
                        (btnCtx) async {
                          await CalendarPage.globalKey.currentState
                              ?.showActionsMenuFromOutside(
                                btnCtx,
                                includeNewNote: false,
                              );
                        },
                    onOpenProfile:
                        widget.onOpenProfile ??
                        (ctx) async {
                          await CalendarPage.globalKey.currentState
                              ?.openProfileFromOutside(ctx);
                        },
                    dateButtonBuilder: (context, currentGregorian) {
                      final headerDateLabel = _buildHeaderDateLabel(
                        context,
                        currentGregorian,
                      );
                      return KemeticDayButton(
                        key: _dayCardRevealTargetKey,
                        dayKey: _getKemeticDayKey(
                          _currentKy,
                          _currentKm,
                          _currentKd,
                        ),
                        kYear: _currentKy,
                        openOnTap: false,
                        onOpen: () {
                          unawaited(_handleDayCardRevealCoachmarkCompleted());
                        },
                        child: _showGregorian
                            ? GlossyText(
                                text: headerDateLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                                gradient: blueGloss,
                                maxLines: 1,
                                softWrap: false,
                                textAlign: TextAlign.center,
                              )
                            : Text(
                                headerDateLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                                softWrap: false,
                                textAlign: TextAlign.center,
                              ),
                      );
                    },
                  ),

                  // Existing page view with timeline
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      itemBuilder: (context, index) {
                        final kDate = _dateForPage(index);
                        return DayViewGrid(
                          key: ValueKey(
                            '${kDate.kYear}-${kDate.kMonth}-${kDate.kDay}-$_gridInstance',
                          ), // Add key
                          ky: kDate.kYear,
                          km: kDate.kMonth,
                          kd: kDate.kDay,
                          notes: widget.notesForDay(
                            kDate.kYear,
                            kDate.kMonth,
                            kDate.kDay,
                          ),
                          dataVersion: widget.dataVersion,
                          showGregorian: _showGregorian,
                          flowIndex: flowIndex,
                          initialScrollOffset: _savedScrollOffset, // 🔧 NEW
                          focusStartMin: widget.focusStartMin,
                          focusFlowId: widget.focusFlowId,
                          focusTitle: widget.focusTitle,
                          onScrollChanged: _onScrollChanged, // 🔧 NEW
                          onManageFlows:
                              widget.onManageFlows, // NEW: Pass callback down
                          onAddNote: widget.onAddNote,
                          onDeleteNote: widget.onDeleteNote,
                          onEditNote: widget.onEditNote,
                          onMoveEventTime: widget.onMoveEventTime,
                          onShareNote: widget.onShareNote,
                          onEditReminder: widget.onEditReminder,
                          onEndReminder: widget.onEndReminder,
                          onShareReminder: widget.onShareReminder,
                          onOpenAddNoteWithTime: widget.onOpenAddNoteWithTime,
                          onCreateTimedEvent: widget.onCreateTimedEvent,
                          onEndFlow:
                              widget.onEndFlow, // Pass End Flow callback down
                          onAppendToJournal: widget.onAppendToJournal,
                          onSaveFlow: widget.onSaveFlow,
                          loadCompletedClientEventIds:
                              widget.loadCompletedClientEventIds,
                          onRecordCompletion: widget.onRecordCompletion,
                          onUnrecordCompletion: widget.onUnrecordCompletion,
                          resolveCurrentEventTarget: _resolveCurrentEventTarget,
                          resolveAdjacentEvent: _resolveAdjacentEventTarget,
                          onNavigateToDay: _animateToKemeticDate,
                        );
                      },
                    ),
                  ),
                ],
              );

              return Stack(
                children: [
                  portraitDayView,
                  if (_showDayCardRevealCoachmark)
                    Positioned.fill(
                      child: DayViewDateCoachmark(
                        targetKey: _dayCardRevealTargetKey,
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  String _getGregorianMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}

// ========================================
// DAY VIEW GRID (Timeline view)
// ========================================

class DayViewGrid extends StatefulWidget {
  final int ky;
  final int km;
  final int kd;
  final List<NoteData> notes;
  final ValueListenable<int>? dataVersion;
  final bool showGregorian;
  final Map<int, FlowData> flowIndex;
  final double? initialScrollOffset; // 🔧 NEW
  final int? focusStartMin; // minutes since midnight
  final int? focusFlowId;
  final String? focusTitle;
  final void Function(double offset)? onScrollChanged; // 🔧 NEW
  final void Function(int? flowId)? onManageFlows; // NEW
  final void Function(int ky, int km, int kd)? onAddNote;
  final Future<void> Function(int ky, int km, int kd, EventItem event)?
  onDeleteNote;
  final Future<void> Function(int ky, int km, int kd, EventItem event)?
  onEditNote;
  final Future<void> Function(
    int ky,
    int km,
    int kd,
    EventItem evt,
    int newStartMin,
  )?
  onMoveEventTime;
  final Future<void> Function(EventItem event)? onShareNote;
  final Future<void> Function(String reminderId)? onEditReminder;
  final Future<void> Function(String reminderId)? onEndReminder;
  final Future<void> Function(EventItem event)? onShareReminder;
  final void Function(
    int ky,
    int km,
    int kd, {
    TimeOfDay? start,
    TimeOfDay? end,
    bool allDay,
  })?
  onOpenAddNoteWithTime;
  final void Function(
    int ky,
    int km,
    int kd, {
    required String title,
    String? detail,
    String? location,
    required TimeOfDay start,
    required TimeOfDay end,
    bool allDay,
  })?
  onCreateTimedEvent;
  final void Function(int flowId)? onEndFlow;
  final Future<void> Function(String text)? onAppendToJournal;
  final Future<void> Function(int flowId)? onSaveFlow;
  final Future<Set<String>> Function({int? flowId, DateTime? completedOnDate})?
  loadCompletedClientEventIds;
  final Future<void> Function({
    required String clientEventId,
    required int flowId,
    required DateTime completedOnDate,
  })?
  onRecordCompletion;
  final Future<void> Function(String clientEventId)? onUnrecordCompletion;
  final DayViewSheetEventTarget Function(DayViewSheetEventTarget target)?
  resolveCurrentEventTarget;
  final DayViewSheetEventTarget? Function({
    required int ky,
    required int km,
    required int kd,
    required EventItem event,
    required bool forward,
  })?
  resolveAdjacentEvent;
  final Future<void> Function(int ky, int km, int kd)? onNavigateToDay;

  const DayViewGrid({
    super.key,
    required this.ky,
    required this.km,
    required this.kd,
    required this.notes,
    this.dataVersion,
    required this.showGregorian,
    required this.flowIndex,
    this.initialScrollOffset, // 🔧 NEW
    this.focusStartMin,
    this.focusFlowId,
    this.focusTitle,
    this.onScrollChanged, // 🔧 NEW
    this.onManageFlows, // NEW
    this.onAddNote, // 🔧 NEW
    this.onDeleteNote,
    this.onEditNote,
    this.onMoveEventTime,
    this.onShareNote,
    this.onEditReminder,
    this.onEndReminder,
    this.onShareReminder,
    this.onOpenAddNoteWithTime,
    this.onCreateTimedEvent, // NEW
    this.onEndFlow,
    this.onAppendToJournal,
    this.onSaveFlow,
    this.loadCompletedClientEventIds,
    this.onRecordCompletion,
    this.onUnrecordCompletion,
    this.resolveCurrentEventTarget,
    this.resolveAdjacentEvent,
    this.onNavigateToDay,
  });

  @override
  State<DayViewGrid> createState() => _DayViewGridState();
}

class _DayViewGridState extends State<DayViewGrid> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _timelineKey = GlobalKey();
  BuildContext? _timelineCtx;

  // 🔧 OPTIMIZATION: Cache layout results
  List<PositionedEventBlock>? _cachedBlocks;
  int? _cachedNotesHash;
  int? _cachedFlowHash;
  List<PositionedEventBlock> _displayBlocks = const [];
  final Map<TrackSkyTimeZone, TrackSkyFlowData> _trackSkyDataByTimeZone =
      <TrackSkyTimeZone, TrackSkyFlowData>{};
  final Set<TrackSkyTimeZone> _trackSkyLoadingTimeZones = <TrackSkyTimeZone>{};
  bool _hasScrolledToInitial = false; // Added for scroll persistence
  int? _tempDragStartMin; // minutes since midnight
  bool _isDraggingEvent = false;
  int? _dragPreviewStartMin;
  EventItem? _dragPreviewEvent;
  int? _lastDragSnappedMinute; // backup of last snapped minute during drag
  int? get _focusStartMin => widget.focusStartMin;
  int? get _focusFlowId => widget.focusFlowId;
  String? get _focusTitle => widget.focusTitle;

  ButtonStyle _endButtonStyle(BuildContext context) {
    // Slightly smaller footprint (~12% shorter) to avoid pushing other controls.
    return withExpandedTouchTargets(
      context,
      OutlinedButton.styleFrom(
        side: const BorderSide(color: _dayGold),
        foregroundColor: _dayGold,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        minimumSize: const Size(0, 35),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
      ),
    );
  }

  Widget _buildEndFlowButton(
    int? flowId, {
    required BuildContext actionContext,
  }) {
    final onEndFlow = widget.onEndFlow;
    final id = flowId;
    final enabled = onEndFlow != null && id != null;
    return OutlinedButton.icon(
      style: _endButtonStyle(actionContext),
      onPressed: enabled
          ? () {
              Navigator.pop(actionContext);
              onEndFlow(id);
            }
          : null,
      icon: const Icon(Icons.stop_circle),
      label: const Text('End Flow'),
    );
  }

  Widget _buildEndNoteButton(
    EventItem event, {
    required int ky,
    required int km,
    required int kd,
    required BuildContext actionContext,
    BuildContext? closeContext,
  }) {
    final enabled = widget.onDeleteNote != null;
    return OutlinedButton.icon(
      style: _endButtonStyle(actionContext),
      onPressed: enabled
          ? () async {
              Navigator.pop(closeContext ?? actionContext);
              await widget.onDeleteNote!(ky, km, kd, event);
            }
          : null,
      icon: const Icon(Icons.delete_outline),
      label: const Text('End Note'),
    );
  }

  Widget _buildEndReminderButton(
    EventItem event, {
    required BuildContext actionContext,
    BuildContext? closeContext,
  }) {
    final enabled = widget.onEndReminder != null && event.reminderId != null;
    return OutlinedButton.icon(
      style: _endButtonStyle(actionContext),
      onPressed: enabled
          ? () async {
              Navigator.pop(closeContext ?? actionContext);
              final reminderId = event.reminderId;
              if (reminderId != null) {
                await widget.onEndReminder?.call(reminderId);
              }
            }
          : null,
      icon: const Icon(Icons.stop_circle),
      label: const Text('End Reminder'),
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll); // Added listener
    _primeTrackSkyFlowData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSavedOrCurrentTime(); // Renamed method
    });
  }

  @override
  void didUpdateWidget(covariant DayViewGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_computeFlowIndexHash(oldWidget.flowIndex) !=
        _computeFlowIndexHash(widget.flowIndex)) {
      _primeTrackSkyFlowData();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll); // Removed listener
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients && widget.onScrollChanged != null) {
      widget.onScrollChanged!(_scrollController.offset);
    }
  }

  RenderBox? _findTimelineBox() {
    final ctx = _timelineKey.currentContext ?? _timelineCtx;
    final ro = ctx?.findRenderObject();
    return ro is RenderBox ? ro : null;
  }

  int? _snappedMinuteFromGlobalOffset(Offset globalOffset, {RenderBox? box}) {
    final renderBox = box ?? _findTimelineBox();
    if (renderBox == null) return null;
    final local = renderBox.globalToLocal(globalOffset);
    final scrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    final double y = local.dy + scrollOffset;
    return ((y / 15).round() * 15).clamp(0, 24 * 60 - 1).toInt();
  }

  void _clearDragPreview() {
    if (_dragPreviewEvent == null && _dragPreviewStartMin == null) return;
    _dragPreviewEvent = null;
    _dragPreviewStartMin = null;
    if (mounted) setState(() {});
  }

  bool _maybeAutoScroll(RenderBox box, double localDy) {
    if (!_scrollController.hasClients ||
        !_scrollController.position.hasPixels ||
        !_scrollController.position.hasContentDimensions ||
        !_scrollController.position.hasViewportDimension) {
      return false;
    }
    const threshold = 56.0;
    const step = 18.0;
    double? target;
    if (localDy < threshold) {
      target = (_scrollController.offset - step).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
    } else if (localDy > box.size.height - threshold) {
      target = (_scrollController.offset + step).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
    }
    if (target != null && target != _scrollController.offset) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
      return true;
    }
    return false;
  }

  void _handleDragUpdate(EventItem event, DragUpdateDetails details) {
    _dragPreviewEvent ??= event;
    final box = _findTimelineBox();
    if (box == null) return;

    bool shouldSetState = false;
    final snapped = _snappedMinuteFromGlobalOffset(
      details.globalPosition,
      box: box,
    );
    final local = box.globalToLocal(details.globalPosition);
    if (kDebugMode) {
      final scrollOffset = _scrollController.hasClients
          ? _scrollController.offset
          : 0.0;
      final double y = local.dy + scrollOffset;
      debugPrint(
        '[DayView] dragUpdate global=${details.globalPosition} local.dy=${local.dy.toStringAsFixed(2)} scroll=${scrollOffset.toStringAsFixed(2)} y=${y.toStringAsFixed(2)} snapped=$snapped previewMin=$_dragPreviewStartMin',
      );
    }
    if (snapped != null && snapped != _dragPreviewStartMin) {
      _dragPreviewStartMin = snapped;
      _lastDragSnappedMinute = snapped;
      HapticFeedback.selectionClick();
      shouldSetState = true;
    }

    final scrolled = _maybeAutoScroll(box, local.dy);
    if (scrolled) {
      final rescanned = _snappedMinuteFromGlobalOffset(
        details.globalPosition,
        box: box,
      );
      if (rescanned != null && rescanned != _dragPreviewStartMin) {
        _dragPreviewStartMin = rescanned;
        _lastDragSnappedMinute = rescanned;
        HapticFeedback.selectionClick();
      }
      shouldSetState = true;
    }

    if (shouldSetState && mounted) {
      setState(() {});
    }
  }

  List<PositionedEventBlock> _eventBlocksTouchingHour(
    int hour, {
    List<PositionedEventBlock>? hourBlocks,
  }) {
    final rowStart = hour * 60.0;
    final rowEnd = rowStart + 60.0;
    final blocks = hourBlocks ?? _displayBlocks;
    return blocks.where((block) {
      final visualStart = block.event.startMin.toDouble();
      final visualEnd = visualStart + _eventVisualHeight(block.event);
      return visualStart < rowEnd && visualEnd > rowStart;
    }).toList();
  }

  bool _isPointOverEventBlock(
    Offset localPosition,
    int hour, {
    List<PositionedEventBlock>? hourBlocks,
  }) {
    final rowStart = hour * 60.0;
    for (final block in _eventBlocksTouchingHour(
      hour,
      hourBlocks: hourBlocks,
    )) {
      final visualStart = block.event.startMin.toDouble();
      final visualEnd = visualStart + _eventVisualHeight(block.event);
      final top = math.max(visualStart, rowStart) - rowStart;
      final heightInRow =
          math.min(visualEnd, rowStart + 60.0) -
          math.max(visualStart, rowStart);
      if (heightInRow <= 0) continue;
      final rect = Rect.fromLTWH(
        block.leftOffset,
        top,
        block.width,
        heightInRow,
      );
      if (rect.contains(localPosition)) {
        return true;
      }
    }
    return false;
  }

  /// Launch URL/email/phone, or treat as address and open in Maps.
  Future<void> _launchLocation(String raw) async {
    await launchExternalTarget(raw);
  }

  /// Turn a block of text into TextSpans with clickable URLs.
  List<TextSpan> _buildTextSpans(String text) {
    final spans = <TextSpan>[];
    final regex = externalLinkPattern;
    int start = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      final raw = match.group(0)!;
      final url = normalizeExternalLinkToken(raw);
      if (url.isEmpty) {
        start = match.end;
        continue;
      }
      spans.add(
        TextSpan(
          text: url,
          style: const TextStyle(
            decoration: TextDecoration.underline,
            color: Color(0xFF4DA3FF),
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              await launchExternalTarget(url, fallbackToMaps: false);
            },
        ),
      );
      if (raw.length > url.length) {
        spans.add(TextSpan(text: raw.substring(url.length)));
      }
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return spans;
  }

  void _scrollToSavedOrCurrentTime() {
    if (!_scrollController.hasClients || _hasScrolledToInitial) return;

    // 1) Focused event wins
    if (_focusStartMin != null) {
      const hourHeight = 60.0;
      final targetOffset = (_focusStartMin! / 60) * hourHeight - 120;
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      _hasScrolledToInitial = true;
      return;
    }

    // 2) Saved scroll offset next
    if (widget.initialScrollOffset != null) {
      _scrollController.jumpTo(widget.initialScrollOffset!);
      _hasScrolledToInitial = true;
      return;
    }

    // 3) Fallback: scroll to current time
    final now = DateTime.now().toLocal();
    final minutesSinceMidnight = now.hour * 60 + now.minute;
    const hourHeight = 60.0;
    final targetOffset =
        (minutesSinceMidnight / 60) * hourHeight -
        200; // 200px above current time

    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
    _hasScrolledToInitial = true;
  }

  /// Dedupe notes before rendering to handle legacy duplicates
  /// Two notes are duplicates if they have:
  /// - Same flow ID
  /// - Same start time (to the minute, or both all-day)
  /// - Same end time (to the minute, or both all-day)
  /// - Same title (normalized)
  List<NoteData> _dedupeNotesForUI(List<NoteData> notes) {
    return _dedupeDayNotesForUi(notes);
  }

  bool _eventsMatch(EventItem a, EventItem b) {
    return _eventsShareStableIdentity(a, b) || identical(a, b);
  }

  List<PositionedEventBlock> _buildDisplayBlocks(
    List<PositionedEventBlock> base,
  ) {
    final preview = _buildCreationPreviewEvent();
    final needsDragRelayout =
        _dragPreviewEvent != null && _dragPreviewStartMin != null;
    if (!needsDragRelayout && preview == null) {
      return base;
    }

    final displayEvents = <EventItem>[for (final block in base) block.event];

    if (needsDragRelayout) {
      final dragPreview = _dragPreviewEvent!;
      final int startMin = _dragPreviewStartMin!.clamp(0, 24 * 60 - 1).toInt();
      final int duration = (dragPreview.endMin - dragPreview.startMin)
          .clamp(15, 12 * 60)
          .toInt();
      final int endMin = (startMin + duration).clamp(0, 24 * 60 - 1).toInt();

      displayEvents.removeWhere((event) => _eventsMatch(event, dragPreview));
      displayEvents.add(
        EventItem(
          id: dragPreview.id,
          clientEventId: dragPreview.clientEventId,
          title: dragPreview.title,
          detail: dragPreview.detail,
          location: dragPreview.location,
          startMin: startMin,
          endMin: endMin,
          flowId: dragPreview.flowId,
          color: dragPreview.color,
          manualColor: dragPreview.manualColor,
          allDay: dragPreview.allDay,
          category: dragPreview.category,
          isReminder: dragPreview.isReminder,
          reminderId: dragPreview.reminderId,
        ),
      );
    }

    if (preview != null) {
      displayEvents.add(preview);
    }

    return EventLayoutEngine.layoutEventItems(
      events: displayEvents,
      availableWidth: _timelineAvailableWidth(context),
      columnGap: _kEventColumnGap,
      textScale: _layoutTextScale(context),
      day: widget.kd,
    );
  }

  EventItem? _buildCreationPreviewEvent() {
    final startMin = _tempDragStartMin;
    if (startMin == null) return null;
    return EventItem(
      clientEventId: _kNewEventPreviewClientEventId,
      title: 'New Event',
      detail: null,
      location: null,
      startMin: startMin,
      endMin: (startMin + 60).clamp(0, 24 * 60),
      flowId: null,
      color: _dayGold,
      manualColor: null,
      allDay: false,
      category: null,
    );
  }

  bool _isPreviewBlock(PositionedEventBlock block) {
    if (block.event.clientEventId == _kNewEventPreviewClientEventId) {
      return true;
    }
    if (_dragPreviewEvent == null || _dragPreviewStartMin == null) {
      return false;
    }
    if (_dragPreviewStartMin != block.event.startMin) return false;
    return _eventsMatch(block.event, _dragPreviewEvent!);
  }

  String _formatPreviewTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour12:${m.toString().padLeft(2, '0')} $period';
  }

  List<Widget> _buildPreviewTimeChipForHour(int hour) {
    final start =
        _tempDragStartMin ??
        (_dragPreviewEvent != null ? _dragPreviewStartMin : null);
    if (start == null) return const [];
    if (start < hour * 60 || start >= (hour + 1) * 60) return const [];
    final top = (start - hour * 60).clamp(0, 59).toDouble();
    return [
      Positioned(
        right: 8,
        top: (top - 10).clamp(0.0, 44.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Text(
            _formatPreviewTime(start),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ];
  }

  bool _looksLikeCidDetail(String text) {
    final trimmed = text.trim().replaceAll(RegExp(r'\s+'), '');
    final withPrefix = trimmed.startsWith('kemet_cid:')
        ? trimmed.substring('kemet_cid:'.length)
        : trimmed;
    final cidPattern = RegExp(
      r'^ky=\d+-km=\d+-kd=\d+\|s=\d+\|t=[^|]+\|f=[^|]+$',
    );
    return cidPattern.hasMatch(withPrefix);
  }

  /// Remove lines that are just cid tokens or legacy flowLocalId lines.
  String _stripCidLines(String detail) {
    final lines = detail.split(RegExp(r'\r?\n'));
    final cidRegex = RegExp(
      r'^(kemet_cid:)?ky=\d+-km=\d+-kd=\d+\|s=\d+\|t=[^|]+\|f=[^|]+$',
    );
    final kept = lines.where((line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) return false; // drop blank lines
      if (trimmed.startsWith('flowLocalId=')) return false;
      final norm = trimmed.replaceAll(RegExp(r'\s+'), '');
      if (cidRegex.hasMatch(norm)) return false;
      if (norm.toLowerCase().startsWith('kemet_cid:reminder:')) return false;
      if (norm.toLowerCase().startsWith('reminder:')) return false;
      return true;
    }).toList();
    return kept.join('\n').trim();
  }

  int _computeNotesHash(List<NoteData> notes) {
    return Object.hashAll(
      notes.map(
        (n) => Object.hash(
          n.title,
          n.detail,
          n.location,
          n.allDay,
          n.start?.hour,
          n.start?.minute,
          n.end?.hour,
          n.end?.minute,
          n.flowId,
          n.manualColor?.value,
          n.category,
          n.isReminder,
          n.reminderId,
        ),
      ),
    );
  }

  int _computeFlowIndexHash(Map<int, FlowData> flowIndex) {
    if (flowIndex.isEmpty) return 0;
    final entries = flowIndex.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Object.hashAll(
      entries.map(
        (e) => Object.hash(
          e.key,
          e.value.name,
          e.value.color.value,
          e.value.active,
          e.value.notes,
        ),
      ),
    );
  }

  TrackSkyTimeZone? _trackSkyTimeZoneForFlow(FlowData? flow) {
    final raw = flow?.notes;
    if (raw == null || raw.isEmpty) return null;
    for (final token in raw.split(';')) {
      final trimmed = token.trim();
      if (!trimmed.startsWith('sky_tz=')) continue;
      switch (trimmed.substring('sky_tz='.length)) {
        case 'pacific':
          return TrackSkyTimeZone.pacific;
        case 'mountain':
          return TrackSkyTimeZone.mountain;
        case 'central':
          return TrackSkyTimeZone.central;
        case 'eastern':
          return TrackSkyTimeZone.eastern;
      }
    }
    return null;
  }

  Future<void> _primeTrackSkyFlowData() async {
    final neededTimeZones = widget.flowIndex.values
        .where((flow) => _isTrackSkyFlowName(flow.name))
        .map(_trackSkyTimeZoneForFlow)
        .whereType<TrackSkyTimeZone>()
        .toSet();
    for (final timezone in neededTimeZones) {
      if (_trackSkyDataByTimeZone.containsKey(timezone) ||
          _trackSkyLoadingTimeZones.contains(timezone)) {
        continue;
      }
      _trackSkyLoadingTimeZones.add(timezone);
      unawaited(() async {
        try {
          final data = await loadTrackSkyFlowData(timezone);
          if (!mounted) return;
          setState(() {
            _trackSkyDataByTimeZone[timezone] = data;
          });
        } catch (_) {
        } finally {
          _trackSkyLoadingTimeZones.remove(timezone);
        }
      }());
    }
  }

  TrackSkyEvent? _resolveTrackSkyEvent(
    EventItem event, {
    required int ky,
    required int km,
    required int kd,
  }) {
    final flow = widget.flowIndex[event.flowId];
    if (!_isTrackSkyFlowName(flow?.name)) return null;
    final timezone = _trackSkyTimeZoneForFlow(flow);
    if (timezone == null) return null;
    final data = _trackSkyDataByTimeZone[timezone];
    if (data == null) {
      _primeTrackSkyFlowData();
      return null;
    }

    final targetDate = DateUtils.dateOnly(KemeticMath.toGregorian(ky, km, kd));
    final normalizedTitle = event.title.trim().toLowerCase();
    final exactMatches = data.events.where((candidate) {
      if (candidate.title.trim().toLowerCase() != normalizedTitle) return false;
      final candidateDate = DateUtils.dateOnly(
        trackSkyEventStartLocal(candidate, timezone),
      );
      if (!DateUtils.isSameDay(candidateDate, targetDate)) return false;
      if (event.allDay != candidate.schedule.allDay) return false;
      if (event.allDay) return true;
      final candidateStart = trackSkyEventStartLocal(candidate, timezone);
      final candidateStartMin =
          candidateStart.hour * 60 + candidateStart.minute;
      return candidateStartMin == event.startMin;
    }).toList();
    if (exactMatches.isNotEmpty) return exactMatches.first;

    final dayMatches = data.events.where((candidate) {
      if (candidate.title.trim().toLowerCase() != normalizedTitle) return false;
      final candidateDate = DateUtils.dateOnly(
        trackSkyEventStartLocal(candidate, timezone),
      );
      return DateUtils.isSameDay(candidateDate, targetDate);
    }).toList();
    if (dayMatches.isNotEmpty) return dayMatches.first;

    return null;
  }

  String _trackSkyDisplayDetail(
    EventItem event, {
    required int ky,
    required int km,
    required int kd,
  }) {
    final resolved = _resolveTrackSkyEvent(event, ky: ky, km: km, kd: kd);
    if (resolved != null) {
      return resolved.detailSummary;
    }

    final raw = event.detail;
    if (raw == null || raw.isEmpty) return '';
    String displayDetail = raw;
    if (displayDetail.startsWith('flowLocalId=')) {
      final semi = displayDetail.indexOf(';');
      if (semi > 0 && semi < displayDetail.length - 1) {
        displayDetail = displayDetail.substring(semi + 1).trim();
      } else {
        return '';
      }
    }
    displayDetail = kemeticizeTrackSkyText(
      normalizeTrackSkyDetailText(_stripCidLines(displayDetail)),
      anchorDate: KemeticMath.toGregorian(ky, km, kd),
    );
    if (displayDetail.isEmpty || _looksLikeCidDetail(displayDetail)) {
      return '';
    }
    return displayDetail;
  }

  String _trackSkyTeaserText(
    EventItem event, {
    required int ky,
    required int km,
    required int kd,
  }) {
    final resolved = _resolveTrackSkyEvent(event, ky: ky, km: km, kd: kd);
    if (resolved != null && resolved.teaserText.isNotEmpty) {
      return resolved.teaserText;
    }
    final detail = _trackSkyDisplayDetail(event, ky: ky, km: km, kd: kd);
    if (detail.isEmpty) return '';
    final firstPipe = detail.indexOf(' | ');
    return firstPipe >= 0 ? detail.substring(0, firstPipe).trim() : detail;
  }

  double _timelineAvailableWidth(BuildContext context) {
    return math.max(
      MediaQuery.of(context).size.width -
          _kTimelineLabelWidth -
          _kTimelineRightPadding,
      0.0,
    );
  }

  double _layoutTextScale(BuildContext context) {
    final textScaler = MediaQuery.maybeTextScalerOf(context);
    if (textScaler == null) return 1.0;
    return textScaler.scale(14.0) / 14.0;
  }

  double _overlapHitHeightForBlock(PositionedEventBlock block) {
    final baseHeight = _eventHitHeight(block.event);
    final textScale = _layoutTextScale(context);
    return _displayBlocks
        .where(
          (candidate) => _eventsOverlap(
            candidate.event,
            block.event,
            textScale: textScale,
          ),
        )
        .map((candidate) => _eventHitHeight(candidate.event))
        .fold<double>(baseHeight, math.max);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ NEW: Dedupe notes before rendering to handle legacy duplicates
    final dedupedNotes = _dedupeNotesForUI(widget.notes);

    // 🔧 OPTIMIZATION: Only recalculate layout if notes or flows changed
    final notesHash = _computeNotesHash(dedupedNotes);
    final flowHash = _computeFlowIndexHash(widget.flowIndex);
    if (_cachedBlocks == null ||
        _cachedNotesHash != notesHash ||
        _cachedFlowHash != flowHash) {
      if (kDebugMode) {
        final originalCount = widget.notes.length;
        final dedupedCount = dedupedNotes.length;
        if (originalCount != dedupedCount) {
          print(
            '[DayView] Deduplicated events: $originalCount → $dedupedCount (removed ${originalCount - dedupedCount} duplicates)',
          );
        }
      }

      _cachedBlocks = EventLayoutEngine.layoutEventsForDay(
        notes: dedupedNotes, // ✅ Use deduped notes
        flowIndex: widget.flowIndex,
        availableWidth: _timelineAvailableWidth(context),
        columnGap: _kEventColumnGap,
        textScale: _layoutTextScale(context),
        day: widget.kd,
      );
      _cachedNotesHash = notesHash;
      _cachedFlowHash = flowHash;
    }

    _displayBlocks = _buildDisplayBlocks(_cachedBlocks ?? []);

    return Column(
      children: [
        // Timeline grid
        Expanded(
          child: DragTarget<_DragPayload>(
            key: _timelineKey,
            builder: (context, candidateData, rejectedData) {
              _timelineCtx = context;
              return ListView.builder(
                key: const PageStorageKey('day_timeline_list'),
                clipBehavior: Clip.none,
                controller: _scrollController,
                cacheExtent: 600, // 🔧 OPTIMIZATION: Cache more items
                itemCount: 24,
                itemBuilder: (context, hour) {
                  return _buildHourRow(hour);
                },
              );
            },
            onWillAccept: (data) => data != null,
            onMove: (details) {
              final snapped = _snappedMinuteFromGlobalOffset(details.offset);
              if (snapped == null) return;
              _dragPreviewEvent ??= details.data.event;
              if (snapped == _dragPreviewStartMin) return;
              _dragPreviewStartMin = snapped;
              _lastDragSnappedMinute = snapped;
              HapticFeedback.selectionClick();
              if (mounted) setState(() {});
              if (kDebugMode) {
                debugPrint(
                  '[DayView] onMove offset=${details.offset} snapped=$snapped',
                );
              }
            },
            onAcceptWithDetails: (details) {
              if (kDebugMode) {
                debugPrint('[DayView] DragTarget onAcceptWithDetails');
              }
              // Reject drop while the timeline is still scrolling.
              if (_scrollController.hasClients &&
                  _scrollController.position.isScrollingNotifier.value) {
                if (kDebugMode) {
                  debugPrint(
                    '[DayView] DragTarget: rejecting drop while scrolling',
                  );
                }
                return;
              }
              final event = details.data.event;
              int? committedMinute;
              if (_dragPreviewStartMin != null &&
                  _dragPreviewEvent != null &&
                  _eventsMatch(event, _dragPreviewEvent!)) {
                committedMinute = _dragPreviewStartMin;
                if (kDebugMode) {
                  debugPrint(
                    '[DayView] drop: using preview minute $committedMinute for id=${event.id} cid=${event.clientEventId}',
                  );
                }
              }

              if (committedMinute == null && _lastDragSnappedMinute != null) {
                committedMinute = _lastDragSnappedMinute;
                if (kDebugMode) {
                  debugPrint(
                    '[DayView] drop: using last snapped minute $committedMinute for id=${event.id} cid=${event.clientEventId}',
                  );
                }
              }

              if (committedMinute == null) {
                committedMinute = _snappedMinuteFromGlobalOffset(
                  details.offset,
                );
                if (committedMinute == null) {
                  if (kDebugMode) {
                    debugPrint(
                      '[DayView] drop ignored: unable to compute snapped minute (all paths)',
                    );
                  }
                  return;
                }
                if (kDebugMode) {
                  debugPrint(
                    '[DayView] drop: fallback snap minute $committedMinute for id=${event.id} cid=${event.clientEventId}',
                  );
                }
              }
              // Temporary: avoid no-op when preview didn't update; prefer fixing drag path if logs show _handleDragUpdate not updating.
              if (committedMinute == event.startMin &&
                  _lastDragSnappedMinute != null &&
                  _lastDragSnappedMinute != event.startMin) {
                if (kDebugMode) {
                  debugPrint(
                    '[DayView] drop: no-op escape using last snapped minute $_lastDragSnappedMinute',
                  );
                }
                committedMinute = _lastDragSnappedMinute;
              }
              if (kDebugMode) {
                debugPrint(
                  '[DayView] drop commit minute=$committedMinute id=${event.id} cid=${event.clientEventId} title="${event.title}" start=${event.startMin} end=${event.endMin}',
                );
              }

              widget.onMoveEventTime?.call(
                widget.ky,
                widget.km,
                widget.kd,
                event,
                committedMinute!,
              );
              _clearDragPreview();
              _lastDragSnappedMinute = null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHourRow(int hour) {
    final hourBlocks = _displayBlocks
        .where(
          (b) =>
              b.event.startMin >= hour * 60 &&
              b.event.startMin < (hour + 1) * 60,
        )
        .toList();

    return Container(
      height: 60,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: const Color(0xFF1A1A1A), width: 0.5),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none, // allow events to span into next hour
        children: [
          // Hour label
          Positioned(
            left: 8,
            top: 4,
            child: Text(
              _formatHour(hour),
              style: const TextStyle(fontSize: 11, color: Color(0xFF808080)),
            ),
          ),

          // Long-press area (covers event region, not label)
          Positioned.fill(
            left: 60,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onLongPressStart: (details) {
                if (kDebugMode) {
                  debugPrint('[DayView] hour row longPressStart hour=$hour');
                }
                if (_isDraggingEvent) return;
                if (_isPointOverEventBlock(
                  details.localPosition,
                  hour,
                  hourBlocks: hourBlocks,
                )) {
                  if (kDebugMode) {
                    debugPrint(
                      '[DayView] hour row longPressStart skipped (over block)',
                    );
                  }
                  return;
                }
                // Ignore if scrolling in progress
                if (_scrollController.hasClients &&
                    _scrollController.position.isScrollingNotifier.value) {
                  return;
                }
                _handleLongPressStart(details);
              },
              onLongPressMoveUpdate: (details) {
                if (_isDraggingEvent) return;
                _handleLongPressMove(details);
              },
              onLongPressEnd: (_) {
                if (_isDraggingEvent) return;
                _handleLongPressEnd();
              },
            ),
          ),

          // Current time indicator within this hour (only if today)
          if (_isToday() && _isCurrentHour(hour))
            Positioned(
              left: 0,
              right: 0,
              top: DateTime.now().toLocal().minute.toDouble(),
              child: _buildNowLine(),
            ),

          // Drag preview target band/line
          if (_dragPreviewStartMin != null &&
              _dragPreviewEvent != null &&
              _dragPreviewStartMin! >= hour * 60 &&
              _dragPreviewStartMin! < (hour + 1) * 60) ...[
            Builder(
              builder: (_) {
                final top = (_dragPreviewStartMin! - hour * 60)
                    .clamp(0, 59)
                    .toDouble();
                const bandHeight = 15.0;
                final bandTop = (top - bandHeight / 2).clamp(
                  0.0,
                  60.0 - bandHeight,
                );
                return Stack(
                  children: [
                    Positioned(
                      left: 60,
                      right: 8,
                      top: bandTop,
                      child: IgnorePointer(
                        child: Container(
                          height: bandHeight,
                          decoration: BoxDecoration(
                            color: _dayGold.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 60,
                      right: 8,
                      top: top,
                      child: IgnorePointer(
                        child: Container(
                          height: 1.5,
                          color: _dayGold.withOpacity(0.85),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],

          // Event blocks
          ..._buildHourBlocks(hourBlocks),

          // Overflow portions of earlier blocks need their own hit targets.
          ..._buildOverflowTapProxiesForHour(hour),

          // Drag preview time chip (if active)
          ..._buildPreviewTimeChipForHour(hour),
        ],
      ),
    );
  }

  /// Build event blocks for a single hour using the day-wide overlap layout.
  List<Widget> _buildHourBlocks(List<PositionedEventBlock> hourBlocks) {
    if (hourBlocks.isEmpty) return const [];

    final sortedBlocks = [...hourBlocks]
      ..sort((a, b) {
        final leftCmp = a.leftOffset.compareTo(b.leftOffset);
        if (leftCmp != 0) return leftCmp;
        return _compareEventItemsBySchedule(a.event, b.event);
      });

    return [
      for (final block in sortedBlocks)
        Positioned(
          left: _kTimelineLabelWidth + block.leftOffset,
          top: (block.event.startMin % 60).toDouble(),
          child: _buildInteractiveEvent(
            block,
            hitHeight: _overlapHitHeightForBlock(block),
          ),
        ),
    ];
  }

  List<Widget> _buildOverflowTapProxiesForHour(int hour) {
    final rowStart = hour * 60.0;
    final rowEnd = rowStart + 60.0;
    final spillBlocks = _displayBlocks.where((block) {
      final visualStart = block.event.startMin.toDouble();
      final visualEnd = visualStart + _eventVisualHeight(block.event);
      return visualStart < rowStart && visualEnd > rowStart;
    }).toList();

    if (spillBlocks.isEmpty) return const [];

    return [
      for (final block in spillBlocks)
        Builder(
          builder: (_) {
            final visualStart = block.event.startMin.toDouble();
            final visualEnd = visualStart + _eventVisualHeight(block.event);
            final visibleTop = math.max(visualStart, rowStart) - rowStart;
            final visibleHeight =
                math.min(visualEnd, rowEnd) - math.max(visualStart, rowStart);
            if (visibleHeight <= 0) return const SizedBox.shrink();

            return Positioned(
              left: _kTimelineLabelWidth + block.leftOffset,
              top: visibleTop,
              child: _buildOverflowTapProxy(block, height: visibleHeight),
            );
          },
        ),
    ];
  }

  Widget _buildOverflowTapProxy(
    PositionedEventBlock block, {
    required double height,
  }) {
    final event = block.event;
    final hitWidth = block.width + 4;

    Widget targetBox() => SizedBox(width: hitWidth, height: height);

    if (!_isEventDraggable(event)) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _showEventDetail(event),
        onLongPress: () {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("This event can't be moved"),
              duration: Duration(milliseconds: 1200),
            ),
          );
        },
        child: targetBox(),
      );
    }

    return LongPressDraggable<_DragPayload>(
      data: _DragPayload(event),
      delay: const Duration(milliseconds: 350),
      feedback: Material(
        color: Colors.transparent,
        child: _buildEventBlock(block, isPreview: false),
      ),
      childWhenDragging: targetBox(),
      onDragUpdate: (details) => _handleDragUpdate(event, details),
      onDragStarted: () {
        _isDraggingEvent = true;
        _dragPreviewEvent = event;
        _dragPreviewStartMin = event.startMin;
        _lastDragSnappedMinute = event.startMin;
        HapticFeedback.selectionClick();
        if (kDebugMode) {
          debugPrint('[DayView] overflow proxy drag title="${event.title}"');
        }
        setState(() {});
      },
      onDraggableCanceled: (_, __) {
        _isDraggingEvent = false;
        _clearDragPreview();
        _lastDragSnappedMinute = null;
      },
      onDragEnd: (_) {
        _isDraggingEvent = false;
        _clearDragPreview();
      },
      onDragCompleted: () {
        _isDraggingEvent = false;
        _clearDragPreview();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _showEventDetail(event),
        child: targetBox(),
      ),
    );
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    if (_isDraggingEvent) return;
    final snappedMinutes = _snappedMinuteFromGlobalOffset(
      details.globalPosition,
    );
    if (snappedMinutes == null) return;
    HapticFeedback.mediumImpact();
    _tempDragStartMin = snappedMinutes;
    if (mounted) setState(() {});
  }

  void _handleLongPressMove(LongPressMoveUpdateDetails details) {
    if (_isDraggingEvent) return;
    if (_tempDragStartMin == null) return;
    final box = _findTimelineBox();
    if (box == null) return;

    bool shouldSetState = false;
    final snapped = _snappedMinuteFromGlobalOffset(
      details.globalPosition,
      box: box,
    );
    if (snapped != null && snapped != _tempDragStartMin) {
      _tempDragStartMin = snapped;
      HapticFeedback.selectionClick();
      shouldSetState = true;
    }

    final local = box.globalToLocal(details.globalPosition);
    final scrolled = _maybeAutoScroll(box, local.dy);
    if (scrolled) {
      final rescanned = _snappedMinuteFromGlobalOffset(
        details.globalPosition,
        box: box,
      );
      if (rescanned != null && rescanned != _tempDragStartMin) {
        _tempDragStartMin = rescanned;
        HapticFeedback.selectionClick();
      }
      shouldSetState = true;
    }

    if (shouldSetState && mounted) {
      setState(() {});
    }
  }

  void _handleLongPressEnd() {
    if (_isDraggingEvent) return;
    final startMin = _tempDragStartMin;
    if (startMin == null) return;
    if (mounted) {
      setState(() {
        _tempDragStartMin = null;
      });
    } else {
      _tempDragStartMin = null;
    }

    final endMin = (startMin + 60).clamp(0, 24 * 60);
    final startHour = (startMin ~/ 60) % 24;
    final startMinute = startMin % 60;
    final endHour = (endMin ~/ 60) % 24;
    final endMinute = endMin % 60;

    if (widget.onOpenAddNoteWithTime != null) {
      widget.onOpenAddNoteWithTime!(
        widget.ky,
        widget.km,
        widget.kd,
        start: TimeOfDay(hour: startHour, minute: startMinute),
        end: TimeOfDay(hour: endHour, minute: endMinute),
        allDay: false,
      );
      return;
    }

    if (widget.onCreateTimedEvent != null) {
      widget.onCreateTimedEvent!(
        widget.ky,
        widget.km,
        widget.kd,
        title: '',
        detail: null,
        location: null,
        start: TimeOfDay(hour: startHour, minute: startMinute),
        end: TimeOfDay(hour: endHour, minute: endMinute),
        allDay: false,
      );
    }
  }

  bool _isEventDraggable(EventItem event) {
    final draggable = !event.isReminder && !event.allDay;
    if (!draggable && kDebugMode) {
      debugPrint(
        '[DayView] not draggable title="${event.title}" flowId=${event.flowId} isReminder=${event.isReminder} allDay=${event.allDay}',
      );
    }
    return draggable;
  }

  Widget _buildInteractiveEvent(
    PositionedEventBlock block, {
    double? hitHeight,
  }) {
    final event = block.event;
    final isPreview = _isPreviewBlock(block);
    final effectiveHitHeight = math.max(
      hitHeight ?? _eventHitHeight(event),
      _eventHitHeight(event),
    );
    final effectiveHitWidth = block.width + 4;

    if (isPreview) {
      return IgnorePointer(child: _buildEventBlock(block, isPreview: true));
    }

    Widget buildHitTarget(Widget child) {
      return SizedBox(
        width: effectiveHitWidth,
        height: effectiveHitHeight,
        child: Align(alignment: Alignment.topLeft, child: child),
      );
    }

    if (!_isEventDraggable(event)) {
      final visual = _buildEventBlock(block, isPreview: false);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showEventDetail(event),
        onLongPress: () {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("This event can't be moved"),
              duration: Duration(milliseconds: 1200),
            ),
          );
        },
        child: buildHitTarget(visual),
      );
    }

    Widget buildVisual({double? opacity}) {
      final visual = _buildEventBlock(block, isPreview: false);
      if (opacity == null) return visual;
      return Opacity(opacity: opacity, child: visual);
    }

    return LongPressDraggable<_DragPayload>(
      data: _DragPayload(event),
      delay: const Duration(milliseconds: 350),
      feedback: Material(
        color: Colors.transparent,
        child: buildVisual(opacity: 0.8),
      ),
      childWhenDragging: buildHitTarget(buildVisual(opacity: 0.35)),
      onDragUpdate: (details) => _handleDragUpdate(event, details),
      onDragStarted: () {
        _isDraggingEvent = true;
        _dragPreviewEvent = event;
        _dragPreviewStartMin = event.startMin;
        _lastDragSnappedMinute = event.startMin;
        HapticFeedback.selectionClick();
        if (kDebugMode) {
          debugPrint('[DayView] onDragStarted title="${event.title}"');
        }
        setState(() {});
      },
      onDraggableCanceled: (_, __) {
        _isDraggingEvent = false;
        _clearDragPreview();
        _lastDragSnappedMinute = null;
      },
      onDragEnd: (_) {
        _isDraggingEvent = false;
        _clearDragPreview();
      },
      onDragCompleted: () {
        _isDraggingEvent = false;
        _clearDragPreview();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showEventDetail(event),
        child: buildHitTarget(buildVisual()),
      ),
    );
  }

  double _eventVisualHeight(EventItem event) {
    return _eventVisualHeightForLayout(
      event,
      textScale: _layoutTextScale(context),
    );
  }

  double _eventHitHeight(EventItem event) => _eventVisualHeight(event) + 2;

  Widget _buildEventBlock(
    PositionedEventBlock block, {
    bool isPreview = false,
  }) {
    final event = block.event;
    final flow = widget.flowIndex[event.flowId];
    final isTrackSky = _isTrackSkyFlowName(flow?.name);
    final trackSkySpec = isTrackSky ? _trackSkyCardSpecForEvent(event) : null;

    // 🔍 DEBUG: Log block being rendered
    if (kDebugMode) {
      print(
        '[_buildEventBlock] Rendering: title="${event.title}", flowId=${event.flowId}, cid=${event.clientEventId}',
      );
    }

    final int durationMinutes = (event.endMin - event.startMin).clamp(15, 180);
    final double height = _eventVisualHeight(event);

    final borderRadius = BorderRadius.circular(isTrackSky ? 8 : 4);

    if (isTrackSky) {
      return Container(
        width: block.width,
        height: height,
        margin: const EdgeInsets.only(right: 4, bottom: 2),
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isPreview ? 0.16 : 0.28),
              blurRadius: kIsWeb ? 8 : 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: trackSkySpec!.glowColor.withValues(
                alpha: isPreview ? 0.08 : 0.14,
              ),
              blurRadius: kIsWeb ? 10 : 14,
              spreadRadius: -3,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: trackSkySpec.background,
                  borderRadius: borderRadius,
                  border: Border.all(
                    color: trackSkySpec.borderColor.withValues(
                      alpha: isPreview ? 0.7 : 0.92,
                    ),
                    width: 0.9,
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ..._buildTrackSkyCardStars(
                    seed: event.title,
                    tint: trackSkySpec.accentColor,
                    compact: durationMinutes < 80,
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            const Color(0xA804060C),
                            const Color(0x7A04060C),
                            const Color(0x1804060C),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.34, 0.62, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 7,
                    child: Opacity(
                      opacity: isPreview ? 0.82 : 1.0,
                      child: _buildTrackSkyCardAccent(
                        trackSkySpec,
                        event.title,
                        size: math.min(height - 18, 24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 11,
                vertical: event.isReminder ? 4 : 4,
              ),
              child: _buildEventTextContents(
                event,
                durationMinutes,
                isPreview: isPreview,
              ),
            ),
          ],
        ),
      );
    }

    final fillColor = isPreview
        ? event.color.withValues(alpha: 0.12)
        : event.color.withValues(alpha: 0.2);
    final BoxBorder border = isPreview
        ? Border.all(color: event.color.withValues(alpha: 0.65), width: 1.5)
        : Border(left: BorderSide(color: event.color, width: 3));

    return Container(
      width: block.width,
      height: height,
      margin: const EdgeInsets.only(right: 4, bottom: 2),
      decoration: BoxDecoration(
        color: fillColor,
        border: border,
        borderRadius: borderRadius,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 4,
        vertical: event.isReminder ? 3 : 4,
      ),
      clipBehavior: Clip.hardEdge, // ✅ Prevent overflow
      child: _buildEventTextContents(
        event,
        durationMinutes,
        isPreview: isPreview,
      ),
    );
  }

  /// ✅ FIX #2B: Separate method for text content with empty title handling
  Widget _buildEventTextContents(
    EventItem event,
    int durationMinutes, {
    bool isPreview = false,
  }) {
    final flow = widget.flowIndex[event.flowId];
    final bool hasFlow = flow != null;
    final bool isTrackSky = _isTrackSkyFlowName(flow?.name);
    final trackSkySpec = isTrackSky ? _trackSkyCardSpecForEvent(event) : null;

    final showTitle = event.title.trim().isNotEmpty;
    final showLocation =
        event.location != null && event.location!.trim().isNotEmpty;
    final titleColor = isTrackSky
        ? trackSkySpec!.titleColor.withValues(alpha: isPreview ? 0.94 : 1.0)
        : (isPreview ? Colors.white70 : Colors.white);
    final flowColor = hasFlow && !isTrackSky
        ? event.color.withValues(alpha: isPreview ? 0.75 : 1.0)
        : null;
    final locationColor = isTrackSky
        ? trackSkySpec!.detailColor.withValues(alpha: isPreview ? 0.78 : 0.96)
        : Colors.white.withValues(alpha: isPreview ? 0.55 : 0.7);
    final titleMaxLines = (event.isReminder || hasFlow || durationMinutes < 90)
        ? 1
        : 2;
    final trackSkyTeaser = isTrackSky
        ? _trackSkyTeaserText(
            event,
            ky: widget.ky,
            km: widget.km,
            kd: widget.kd,
          )
        : '';

    Widget buildTrackSkyText(
      String text, {
      required TextStyle style,
      required int maxLines,
      required TextOverflow overflow,
    }) {
      if (kIsWeb) {
        return Text(
          text,
          style: style.copyWith(
            shadows: const [
              Shadow(
                color: Color(0x22FFF8D6),
                offset: Offset(0, -0.2),
                blurRadius: 0.2,
              ),
            ],
          ),
          maxLines: maxLines,
          overflow: overflow,
        );
      }
      final highlightStyle = style.copyWith(
        color: Colors.white.withValues(alpha: isPreview ? 0.56 : 0.74),
        shadows: null,
      );
      final shadowStyle = style.copyWith(
        color: const Color(
          0xFF02050C,
        ).withValues(alpha: isPreview ? 0.28 : 0.42),
        shadows: null,
      );
      final fillStyle = style.copyWith(color: style.color);
      return Stack(
        children: [
          ExcludeSemantics(
            child: Transform.translate(
              offset: const Offset(-0.3, -0.3),
              child: Text(
                text,
                style: highlightStyle,
                maxLines: maxLines,
                overflow: overflow,
              ),
            ),
          ),
          ExcludeSemantics(
            child: Transform.translate(
              offset: const Offset(0.55, 0.72),
              child: Text(
                text,
                style: shadowStyle,
                maxLines: maxLines,
                overflow: overflow,
              ),
            ),
          ),
          Text(text, style: fillStyle, maxLines: maxLines, overflow: overflow),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min, // ✅ Don't expand unnecessarily
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Flow name first (if available). Skip for reminders to avoid overflow in short block.
        if (hasFlow && !event.isReminder) ...[
          isTrackSky
              ? buildTrackSkyText(
                  flow.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: trackSkySpec!.labelColor.withValues(
                      alpha: isPreview ? 0.9 : 1.0,
                    ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : Text(
                  flow.name,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: flowColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          SizedBox(height: isTrackSky ? 1 : 2),
        ],

        // Note title - only render if meaningful
        if (showTitle)
          isTrackSky
              ? buildTrackSkyText(
                  event.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                  maxLines: titleMaxLines,
                  overflow: TextOverflow.ellipsis,
                )
              : Text(
                  event.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: titleColor,
                  ),
                  maxLines: titleMaxLines,
                  overflow: TextOverflow.ellipsis,
                )
        else
          isTrackSky
              ? buildTrackSkyText(
                  hasFlow ? '(flow block)' : '(scheduled)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: trackSkySpec!.labelColor.withValues(
                      alpha: isPreview ? 0.8 : 0.9,
                    ),
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : Text(
                  // Fallback so you don't get giant red nothing-brick
                  hasFlow ? '(flow block)' : '(scheduled)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: isPreview ? Colors.white60 : Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

        if (isTrackSky &&
            trackSkyTeaser.isNotEmpty &&
            durationMinutes >= 45) ...[
          const SizedBox(height: 1),
          buildTrackSkyText(
            trackSkyTeaser,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: trackSkySpec!.detailColor.withValues(
                alpha: isPreview ? 0.82 : 0.96,
              ),
            ),
            maxLines: durationMinutes >= 90 ? 2 : 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],

        // Location (clickable)
        if (showLocation && !isTrackSky)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: InkWell(
              onTap: () => _launchLocation(event.location!.trim()),
              child: Text(
                event.location!.trim(),
                style: TextStyle(
                  fontSize: 10,
                  color: locationColor,
                  decoration: TextDecoration.underline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNowLine() {
    return Container(height: 1, color: Colors.red.withOpacity(0.45));
  }

  bool _isCurrentHour(int hour) {
    final now = DateTime.now().toLocal();
    return now.hour == hour;
  }

  bool _isToday() {
    final now = DateTime.now().toLocal();
    final todayK = KemeticMath.fromGregorian(now);
    return widget.ky == todayK.kYear &&
        widget.km == todayK.kMonth &&
        widget.kd == todayK.kDay;
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }

  String _buildBadgeToken(
    EventItem event, {
    required int ky,
    required int km,
    required int kd,
  }) {
    final g = KemeticMath.toGregorian(ky, km, kd);
    final dayStart = DateTime(g.year, g.month, g.day);
    final start = dayStart.add(Duration(minutes: event.startMin));
    final end = dayStart.add(Duration(minutes: event.endMin));
    final id = 'badge-${DateTime.now().microsecondsSinceEpoch}';
    final rawDesc = event.detail?.trim() ?? '';
    final cleanedDesc = rawDesc.isEmpty ? null : _stripCidLines(rawDesc);
    final descForToken = (cleanedDesc == null || cleanedDesc.isEmpty)
        ? null
        : cleanedDesc;
    return EventBadgeToken.buildToken(
      id: id,
      title: event.title.isEmpty ? 'Scheduled block' : event.title,
      start: start,
      end: end,
      color: event.color,
      description: descForToken,
    );
  }

  Future<void> _quickAddToJournal(
    EventItem event, {
    required int ky,
    required int km,
    required int kd,
  }) async {
    final cb = widget.onAppendToJournal;
    if (cb == null) return;

    final token = _buildBadgeToken(event, ky: ky, km: km, kd: kd);
    try {
      await cb('$token ');
    } catch (_) {
      // ignore errors silently to avoid blocking UI
    }
  }

  Future<void> _handleAddToJournal(
    EventItem event, {
    required int ky,
    required int km,
    required int kd,
    BuildContext? sheetContext,
  }) async {
    if (sheetContext != null) {
      Navigator.pop(sheetContext);
    }
    await _quickAddToJournal(event, ky: ky, km: km, kd: kd);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Added to journal'),
          backgroundColor: _dayGold,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  String _detailSheetTargetKey(DayViewSheetEventTarget target) =>
      '${target.ky}:${target.km}:${target.kd}:${_eventIdentityKey(target.event)}';

  ({List<DayViewSheetEventTarget> pages, int currentIndex})
  _detailSheetPagesForTarget(DayViewSheetEventTarget target) {
    final previous = widget.resolveAdjacentEvent?.call(
      ky: target.ky,
      km: target.km,
      kd: target.kd,
      event: target.event,
      forward: false,
    );
    final next = widget.resolveAdjacentEvent?.call(
      ky: target.ky,
      km: target.km,
      kd: target.kd,
      event: target.event,
      forward: true,
    );

    final pages = <DayViewSheetEventTarget>[
      if (previous != null) previous,
      target,
      if (next != null) next,
    ];
    return (pages: pages, currentIndex: previous != null ? 1 : 0);
  }

  Widget _buildEventDetailSheetPage({
    required DayViewSheetEventTarget target,
    bool scrollable = true,
  }) {
    final currentEvent = target.event;
    final flow = widget.flowIndex[currentEvent.flowId];
    final bool isReminder = currentEvent.isReminder;
    final bool isNutrition =
        currentEvent.detail != null && currentEvent.detail!.contains('Source:');
    final bool isTrackSky = _isTrackSkyFlowName(flow?.name);
    final trackSkySpec = isTrackSky
        ? _trackSkyCardSpecForEvent(currentEvent)
        : null;

    Widget? metaChip;
    if (flow != null) {
      final skyMetaSpec = isTrackSky ? trackSkySpec! : null;
      metaChip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          gradient: isTrackSky ? skyMetaSpec!.background : null,
          color: isTrackSky ? null : flow.color.withValues(alpha: 0.16),
          border: isTrackSky
              ? Border.all(
                  color: skyMetaSpec!.borderColor.withValues(alpha: 0.78),
                )
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: isTrackSky
            ? Text(
                flow.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: skyMetaSpec!.titleColor,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.42),
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              )
            : Text(
                flow.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: flow.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
      );
    } else if (isReminder) {
      metaChip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: KemeticGold.base.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(8),
        ),
        child: KemeticGold.text(
          'Reminder',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
    } else if (isNutrition) {
      metaChip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: KemeticGold.base.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KemeticGold.icon(Icons.local_drink, size: 14),
            const SizedBox(width: 4),
            KemeticGold.text(
              'Nutrition',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (metaChip != null) metaChip,
        if (metaChip != null) const SizedBox(height: 12),
        KemeticGold.text(
          currentEvent.title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(Icons.access_time, size: 16, color: Color(0xFF808080)),
            const SizedBox(width: 8),
            Text(
              _formatTimeRange(currentEvent.startMin, currentEvent.endMin),
              style: const TextStyle(color: Color(0xFF808080)),
            ),
          ],
        ),
        if (currentEvent.location != null &&
            currentEvent.location!.isNotEmpty) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _launchLocation(currentEvent.location!.trim()),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 16,
                  color: Color(0xFF808080),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    currentEvent.location!,
                    style: const TextStyle(
                      color: Color(0xFF808080),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if ((isTrackSky &&
                _trackSkyDisplayDetail(
                  currentEvent,
                  ky: target.ky,
                  km: target.km,
                  kd: target.kd,
                ).isNotEmpty) ||
            (currentEvent.detail != null &&
                currentEvent.detail!.isNotEmpty)) ...[
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final displayDetail = isTrackSky
                  ? _trackSkyDisplayDetail(
                      currentEvent,
                      ky: target.ky,
                      km: target.km,
                      kd: target.kd,
                    )
                  : () {
                      var rawDetail = currentEvent.detail!;
                      if (rawDetail.startsWith('flowLocalId=')) {
                        final semi = rawDetail.indexOf(';');
                        if (semi > 0 && semi < rawDetail.length - 1) {
                          rawDetail = rawDetail.substring(semi + 1).trim();
                        } else {
                          return '';
                        }
                      }
                      return _stripCidLines(rawDetail);
                    }();
              if (displayDetail.isEmpty || _looksLikeCidDetail(displayDetail)) {
                return const SizedBox.shrink();
              }

              return RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  children: _buildTextSpans(displayDetail),
                ),
              );
            },
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _dayGold.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: scrollable
            ? SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: body,
              )
            : body,
      ),
    );
  }

  Widget _buildEventDetailTopActionRow({
    required BuildContext rootContext,
    required BuildContext sheetContext,
    required DayViewSheetEventTarget target,
  }) {
    final currentEvent = target.event;
    final flow = widget.flowIndex[currentEvent.flowId];
    final isReminder = currentEvent.isReminder;

    return Row(
      children: [
        const Spacer(),
        if (flow != null)
          _buildEndFlowButton(flow.id, actionContext: sheetContext)
        else if (isReminder)
          _buildEndReminderButton(
            currentEvent,
            actionContext: sheetContext,
            closeContext: sheetContext,
          )
        else if (widget.onDeleteNote != null)
          _buildEndNoteButton(
            currentEvent,
            ky: target.ky,
            km: target.km,
            kd: target.kd,
            actionContext: sheetContext,
            closeContext: sheetContext,
          ),
        const SizedBox(width: 8),
        _buildEventDetailOverflowButton(
          rootContext: rootContext,
          sheetContext: sheetContext,
          target: target,
        ),
      ],
    );
  }

  Widget _buildEventDetailPrimaryAction({
    required BuildContext sheetContext,
    required DayViewSheetEventTarget target,
  }) {
    final currentEvent = target.event;
    final flow = widget.flowIndex[currentEvent.flowId];
    final isReminder = currentEvent.isReminder;

    if (flow != null) {
      final enabled = CalendarPage.globalKey.currentState?.mounted ?? false;
      return TextButton.icon(
        onPressed: enabled
            ? () async {
                Navigator.pop(sheetContext);
                await CalendarPage.shareFlowFromEvent(currentEvent);
              }
            : null,
        icon: enabled
            ? KemeticGold.icon(Icons.share_outlined)
            : const Icon(Icons.share_outlined, color: Color(0xFF404040)),
        label: enabled
            ? KemeticGold.text(
                'Share Flow',
                style: _goldHeaderStyle.copyWith(fontSize: 15),
              )
            : const Text(
                'Share Flow',
                style: TextStyle(color: Color(0xFF404040)),
              ),
      );
    }

    if (isReminder) {
      final enabled =
          widget.onEditReminder != null && currentEvent.reminderId != null;
      return TextButton.icon(
        onPressed: enabled
            ? () async {
                Navigator.pop(sheetContext);
                await widget.onEditReminder!(currentEvent.reminderId!);
              }
            : null,
        icon: enabled
            ? KemeticGold.icon(Icons.notifications_active_outlined)
            : const Icon(
                Icons.notifications_active_outlined,
                color: Color(0xFF404040),
              ),
        label: enabled
            ? KemeticGold.text(
                'Reminder',
                style: _goldHeaderStyle.copyWith(fontSize: 15),
              )
            : const Text(
                'Reminder',
                style: TextStyle(color: Color(0xFF404040)),
              ),
      );
    }

    final enabled = widget.onEditNote != null;
    return TextButton.icon(
      onPressed: enabled
          ? () async {
              Navigator.pop(sheetContext);
              await widget.onEditNote!(
                target.ky,
                target.km,
                target.kd,
                currentEvent,
              );
            }
          : null,
      icon: enabled
          ? KemeticGold.icon(Icons.note_alt_outlined)
          : const Icon(Icons.note_alt_outlined, color: Color(0xFF404040)),
      label: enabled
          ? KemeticGold.text(
              'Note',
              style: _goldHeaderStyle.copyWith(fontSize: 15),
            )
          : const Text('Note', style: TextStyle(color: Color(0xFF404040))),
    );
  }

  Widget _buildEventDetailOverflowButton({
    required BuildContext rootContext,
    required BuildContext sheetContext,
    required DayViewSheetEventTarget target,
  }) {
    final currentEvent = target.event;
    final flow = widget.flowIndex[currentEvent.flowId];
    final isReminder = currentEvent.isReminder;

    return PopupMenuButton<String>(
      icon: KemeticGold.icon(Icons.more_vert),
      tooltip: 'Event options',
      color: const Color(0xFF000000),
      onSelected: (value) async {
        if (value == 'journal') {
          await _handleAddToJournal(
            currentEvent,
            ky: target.ky,
            km: target.km,
            kd: target.kd,
            sheetContext: sheetContext,
          );
        } else if (value == 'edit' && flow != null) {
          Navigator.pop(sheetContext);
          widget.onManageFlows?.call(flow.id);
        } else if (value == 'invite_people') {
          Navigator.pop(sheetContext);
          if (isReminder && widget.onShareReminder != null) {
            await widget.onShareReminder!(currentEvent);
          } else if (widget.onShareNote != null) {
            await widget.onShareNote!(currentEvent);
          }
        } else if (value == 'save' && flow != null) {
          Navigator.pop(sheetContext);
          if (widget.onSaveFlow != null) {
            await widget.onSaveFlow!(flow.id);
          } else {
            try {
              await UserEventsRepo(
                Supabase.instance.client,
              ).setFlowSaved(flowId: flow.id, isSaved: true);
              if (rootContext.mounted) {
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  const SnackBar(
                    content: Text('Saved to Saved Flows'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } catch (e) {
              if (rootContext.mounted) {
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  SnackBar(content: Text('Unable to save flow: $e')),
                );
              }
            }
          }
        } else if (value == 'edit_reminder' &&
            isReminder &&
            widget.onEditReminder != null &&
            currentEvent.reminderId != null) {
          Navigator.pop(sheetContext);
          await widget.onEditReminder!(currentEvent.reminderId!);
        } else if (value == 'edit_note' &&
            flow == null &&
            !isReminder &&
            widget.onEditNote != null) {
          Navigator.pop(sheetContext);
          await widget.onEditNote!(
            target.ky,
            target.km,
            target.kd,
            currentEvent,
          );
        }
      },
      itemBuilder: (context) => [
        if (widget.onAppendToJournal != null)
          PopupMenuItem(
            value: 'journal',
            child: Row(
              children: [
                KemeticGold.icon(Icons.library_add_check),
                const SizedBox(width: 12),
                const Text(
                  'Add to journal',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        if (flow != null && !isReminder)
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                KemeticGold.icon(Icons.edit),
                const SizedBox(width: 12),
                const Text('Edit Flow', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        if (flow != null && !isReminder && widget.onShareNote != null)
          PopupMenuItem(
            value: 'invite_people',
            child: Row(
              children: [
                KemeticGold.icon(Icons.person_add_alt_1),
                const SizedBox(width: 12),
                const Text(
                  'Invite People',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        if (flow != null && !isReminder)
          PopupMenuItem(
            value: 'save',
            child: Row(
              children: [
                KemeticGold.icon(Icons.bookmark_add),
                const SizedBox(width: 12),
                const Text('Save Flow', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        if (isReminder &&
            widget.onEditReminder != null &&
            currentEvent.reminderId != null)
          PopupMenuItem(
            value: 'edit_reminder',
            child: Row(
              children: [
                KemeticGold.icon(Icons.edit),
                const SizedBox(width: 12),
                const Text(
                  'Edit Reminder',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        if (isReminder && widget.onShareReminder != null)
          PopupMenuItem(
            value: 'invite_people',
            child: Row(
              children: [
                KemeticGold.icon(Icons.person_add_alt_1),
                const SizedBox(width: 12),
                const Text(
                  'Invite People',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        if (flow == null && !isReminder && widget.onEditNote != null)
          PopupMenuItem(
            value: 'edit_note',
            child: Row(
              children: [
                KemeticGold.icon(Icons.edit),
                const SizedBox(width: 12),
                const Text('Edit Note', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        if (flow == null && !isReminder && widget.onShareNote != null)
          PopupMenuItem(
            value: 'invite_people',
            child: Row(
              children: [
                KemeticGold.icon(Icons.person_add_alt_1),
                const SizedBox(width: 12),
                const Text(
                  'Invite People',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEventDetailBottomActionRow({
    required BuildContext sheetContext,
    required DayViewSheetEventTarget target,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildEventDetailPrimaryAction(
          sheetContext: sheetContext,
          target: target,
        ),
        TextButton(
          onPressed: () => Navigator.pop(sheetContext),
          child: KemeticGold.text(
            'Close',
            style: _goldHeaderStyle.copyWith(fontSize: 15),
          ),
        ),
      ],
    );
  }

  // Show event detail sheet
  void _showEventDetail(EventItem event) {
    final rootContext = context;
    final sheetDataListenable = widget.dataVersion ?? _kZeroListenable;
    final currentTarget = ValueNotifier<DayViewSheetEventTarget>(
      DayViewSheetEventTarget(
        ky: widget.ky,
        km: widget.km,
        kd: widget.kd,
        event: event,
      ),
    );
    final measuredHeights = ValueNotifier<Map<String, double>>({});
    final initialPages = _detailSheetPagesForTarget(currentTarget.value);
    PageController sheetPageController = PageController(
      initialPage: initialPages.currentIndex,
    );

    if (kDebugMode) {
      print('[_showEventDetail] Event: "${event.title}"');
      print(
        '[_showEventDetail] Event flowId: ${event.flowId} (${event.flowId.runtimeType})',
      );
      print('[_showEventDetail] Event color: ${event.color}');
      print(
        '[_showEventDetail] FlowIndex keys: ${widget.flowIndex.keys.toList()}',
      );
      print('[_showEventDetail] FlowIndex length: ${widget.flowIndex.length}');
    }

    void updateMeasuredHeight(String key, double height) {
      final normalized = height.ceilToDouble();
      if (normalized <= 0) return;
      final previous = measuredHeights.value[key];
      if (previous != null && (previous - normalized).abs() < 1) return;
      final nextHeights = Map<String, double>.from(measuredHeights.value);
      nextHeights[key] = normalized;
      measuredHeights.value = nextHeights;
    }

    void resetSheetPageController(int initialPage) {
      final previous = sheetPageController;
      sheetPageController = PageController(initialPage: initialPage);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        previous.dispose();
      });
    }

    Future<void> moveToTarget(DayViewSheetEventTarget nextTarget) async {
      final previousTarget = currentTarget.value;
      currentTarget.value = nextTarget;
      if (widget.onNavigateToDay != null &&
          (nextTarget.ky != previousTarget.ky ||
              nextTarget.km != previousTarget.km ||
              nextTarget.kd != previousTarget.kd)) {
        unawaited(
          widget.onNavigateToDay!(nextTarget.ky, nextTarget.km, nextTarget.kd),
        );
      }
      HapticFeedback.selectionClick();
    }

    showModalBottomSheet(
      context: rootContext,
      backgroundColor: const Color(0xFF000000),
      isScrollControlled: true,
      builder: (sheetContext) {
        return ValueListenableBuilder<int>(
          valueListenable: sheetDataListenable,
          builder: (context, _, child) {
            return ValueListenableBuilder<DayViewSheetEventTarget>(
              valueListenable: currentTarget,
              builder: (context, rawTarget, _) {
                final target =
                    widget.resolveCurrentEventTarget?.call(rawTarget) ??
                    rawTarget;
                final pages = _detailSheetPagesForTarget(target);
                final currentKey = _detailSheetTargetKey(target);
                final pageViewKey = ValueKey<String>(
                  '$currentKey:${pages.currentIndex}:${pages.pages.length}',
                );

                return ValueListenableBuilder<Map<String, double>>(
                  valueListenable: measuredHeights,
                  builder: (context, heights, child) {
                    final maxSheetHeight = math.min(
                      MediaQuery.sizeOf(context).height * 0.72,
                      560.0,
                    );
                    final sheetHeight = (heights[currentKey] ?? 200.0)
                        .clamp(0.0, math.max(180.0, maxSheetHeight - 112.0))
                        .toDouble();

                    return SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Offstage(
                            child: Column(
                              children: [
                                for (final pageTarget in pages.pages)
                                  _MeasureSize(
                                    key: ValueKey<String>(
                                      _detailSheetTargetKey(pageTarget),
                                    ),
                                    onChange: (size) {
                                      updateMeasuredHeight(
                                        _detailSheetTargetKey(pageTarget),
                                        size.height,
                                      );
                                    },
                                    child: SizedBox(
                                      width: MediaQuery.sizeOf(context).width,
                                      child: _buildEventDetailSheetPage(
                                        target: pageTarget,
                                        scrollable: false,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildEventDetailTopActionRow(
                                  rootContext: rootContext,
                                  sheetContext: sheetContext,
                                  target: target,
                                ),
                                const SizedBox(height: 10),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                  alignment: Alignment.bottomCenter,
                                  child: SizedBox(
                                    height: sheetHeight,
                                    child: PageView.builder(
                                      key: pageViewKey,
                                      controller: sheetPageController,
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: pages.pages.length,
                                      onPageChanged: (index) {
                                        if (index == pages.currentIndex) {
                                          return;
                                        }
                                        final nextTarget = pages.pages[index];
                                        final nextPages =
                                            _detailSheetPagesForTarget(
                                              nextTarget,
                                            );
                                        resetSheetPageController(
                                          nextPages.currentIndex,
                                        );
                                        unawaited(moveToTarget(nextTarget));
                                      },
                                      itemBuilder: (context, index) {
                                        return _buildEventDetailSheetPage(
                                          target: pages.pages[index],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildEventDetailBottomActionRow(
                                  sheetContext: sheetContext,
                                  target: target,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    ).whenComplete(() {
      currentTarget.dispose();
      measuredHeights.dispose();
      sheetPageController.dispose();
    });
  }

  String _formatTimeRange(int startMin, int endMin) {
    final startHour = startMin ~/ 60;
    final startMinute = startMin % 60;
    final endHour = endMin ~/ 60;
    final endMinute = endMin % 60;

    String formatTime(int h, int m) {
      final period = h >= 12 ? 'PM' : 'AM';
      final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$hour12:${m.toString().padLeft(2, '0')} $period';
    }

    return '${formatTime(startHour, startMinute)} – ${formatTime(endHour, endMinute)}';
  }
}

class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({super.key, required this.onChange, required super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _MeasureSizeRenderObject(onChange);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _MeasureSizeRenderObject renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _MeasureSizeRenderObject extends RenderProxyBox {
  _MeasureSizeRenderObject(this.onChange);

  ValueChanged<Size> onChange;
  Size? _oldSize;

  @override
  void performLayout() {
    super.performLayout();
    final newSize = child?.size;
    if (newSize == null || newSize == _oldSize) return;
    _oldSize = newSize;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onChange(newSize);
    });
  }
}

// Day View - 24-hour timeline with pixel-perfect event layout
// Uses EventLayoutEngine for consistent positioning
//
