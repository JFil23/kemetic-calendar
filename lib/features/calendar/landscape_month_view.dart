// lib/features/calendar/landscape_month_view.dart
//
// Landscape Month View - Full month grid with INFINITE scrolling
// Styled to match day_view.dart's beautiful detail sheets
//

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/app_haptics.dart';
import '../../services/app_restoration_service.dart';
import 'day_view.dart'; // For NoteData, FlowData
import 'calendar_page.dart' show KemeticMath;
import 'maat_flow_response_journal_blocks.dart';
import 'package:mobile/features/calendar/kemetic_time_constants.dart';
import 'dart:math' as math;
import 'package:mobile/shared/glossy_text.dart';
import 'package:mobile/widgets/month_name_text.dart';

// ========================================
// SHARED CONSTANTS FOR LANDSCAPE VIEW
// ========================================
const Color _landscapeGold = KemeticGold.base;
const Color _landscapeBg = Color(0xFF000000); // True black
const Color _landscapeSurface = Color(0xFF0D0D0F); // Dark surface
const Color _landscapeDivider = Color(0xFF1A1A1A); // Divider lines
const Gradient _trackSkyFlowGoldGloss = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [
    Color(0xFFFFF1BF),
    Color(0xFFF8DA79),
    Color(0xFFFFF8D9),
    Color(0xFFF1CE67),
  ],
  stops: [0.0, 0.34, 0.66, 1.0],
);
const double kLandscapeHeaderHeight = 58.0; // Day number header height

void _logLandscape(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

bool _isLandscapeTrackSkyFlowName(String? name) {
  final normalized = name?.trim().toLowerCase();
  return normalized == 'follow the sky' || normalized == 'track the sky';
}

enum _LandscapeTrackSkyKind {
  moon,
  lunarEclipse,
  solarEclipse,
  meteor,
  planet,
  solarSeason,
  genericSky,
}

class _LandscapeTrackSkySpec {
  final _LandscapeTrackSkyKind kind;
  final Gradient background;
  final Color borderColor;
  final Color titleColor;
  final Color flowColor;
  final Color glowColor;
  final Color accentColor;
  final Color secondaryAccentColor;

  const _LandscapeTrackSkySpec({
    required this.kind,
    required this.background,
    required this.borderColor,
    required this.titleColor,
    required this.flowColor,
    required this.glowColor,
    required this.accentColor,
    required this.secondaryAccentColor,
  });
}

_LandscapeTrackSkyKind _landscapeTrackSkyKindForTitle(String title) {
  if (title.contains('solar eclipse') || title.contains('ring of fire')) {
    return _LandscapeTrackSkyKind.solarEclipse;
  }
  if (title.contains('lunar eclipse') ||
      title.contains('blood moon') ||
      title.contains('penumbral') ||
      title.contains('partial lunar')) {
    return _LandscapeTrackSkyKind.lunarEclipse;
  }
  if (title.contains('moon')) return _LandscapeTrackSkyKind.moon;
  if (title.contains('lyrids') ||
      title.contains('aquariids') ||
      title.contains('perseids') ||
      title.contains('geminids') ||
      title.contains('quadrantids') ||
      title.contains('meteor')) {
    return _LandscapeTrackSkyKind.meteor;
  }
  if (title.contains('equinox') || title.contains('solstice')) {
    return _LandscapeTrackSkyKind.solarSeason;
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
    return _LandscapeTrackSkyKind.planet;
  }
  return _LandscapeTrackSkyKind.genericSky;
}

Color _landscapeTrackSkyMoonTint(String title) {
  if (title.contains('blood')) return const Color(0xFFC7655D);
  if (title.contains('pink')) return const Color(0xFFF5B4D7);
  if (title.contains('flower')) return const Color(0xFFFFE3B0);
  if (title.contains('strawberry')) return const Color(0xFFF39AA6);
  if (title.contains('harvest')) return const Color(0xFFF5C46B);
  if (title.contains('hunter')) return const Color(0xFFCF925B);
  if (title.contains('snow') || title.contains('cold')) {
    return const Color(0xFFEAF5FF);
  }
  if (title.contains('wolf')) return const Color(0xFFD9E6FF);
  return const Color(0xFFF4E7CF);
}

Color _landscapeTrackSkyMeteorTint(String title) {
  if (title.contains('perseids')) return const Color(0xFF9FCAFF);
  if (title.contains('geminids')) return const Color(0xFFA9F5EF);
  if (title.contains('lyrids')) return const Color(0xFFD7C3FF);
  if (title.contains('quadrantids')) return const Color(0xFFEAF5FF);
  if (title.contains('aquariids')) return const Color(0xFF8DEAF7);
  return const Color(0xFFB9D0FF);
}

Color _landscapeTrackSkyPlanetTint(String title) {
  if (title.contains('mars')) return const Color(0xFFE17D5D);
  if (title.contains('venus')) return const Color(0xFFF6E2C0);
  if (title.contains('jupiter')) return const Color(0xFFF4C88D);
  if (title.contains('saturn')) return const Color(0xFFE8D27A);
  if (title.contains('mercury')) return const Color(0xFFD9E1F0);
  return const Color(0xFFBFD2FF);
}

Color _landscapeTrackSkySolarTint(String title) {
  if (title.contains('winter')) return const Color(0xFFF1D4A3);
  if (title.contains('summer')) return const Color(0xFFF7B45A);
  if (title.contains('autumn')) return const Color(0xFFF19A62);
  if (title.contains('vernal') || title.contains('spring')) {
    return const Color(0xFFF8CDA0);
  }
  return const Color(0xFFF3C47E);
}

_LandscapeTrackSkySpec _landscapeTrackSkySpecForEvent(EventItem event) {
  final title = event.title.trim().toLowerCase();
  final kind = _landscapeTrackSkyKindForTitle(title);

  switch (kind) {
    case _LandscapeTrackSkyKind.moon:
      final moonTint = _landscapeTrackSkyMoonTint(title);
      return _LandscapeTrackSkySpec(
        kind: kind,
        background: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF040813),
            Color.lerp(const Color(0xFF17275F), moonTint, 0.18)!,
            const Color(0xFF24174A),
          ],
        ),
        borderColor: moonTint.withValues(alpha: 0.82),
        titleColor: const Color(0xFFF8FAFF),
        flowColor: moonTint.withValues(alpha: 0.96),
        glowColor: moonTint.withValues(alpha: 0.34),
        accentColor: moonTint,
        secondaryAccentColor: Colors.white,
      );
    case _LandscapeTrackSkyKind.lunarEclipse:
      final eclipseTint = _landscapeTrackSkyMoonTint(title);
      return _LandscapeTrackSkySpec(
        kind: kind,
        background: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF05070F),
            Color.lerp(const Color(0xFF2E1024), eclipseTint, 0.34)!,
            const Color(0xFF120812),
          ],
        ),
        borderColor: eclipseTint.withValues(alpha: 0.8),
        titleColor: const Color(0xFFFFF6F1),
        flowColor: const Color(0xFFFFE0D2),
        glowColor: eclipseTint.withValues(alpha: 0.36),
        accentColor: eclipseTint,
        secondaryAccentColor: const Color(0xFFFFD7BF),
      );
    case _LandscapeTrackSkyKind.solarEclipse:
      final ringTint = title.contains('ring of fire')
          ? const Color(0xFFFFA24B)
          : const Color(0xFFF4E6C1);
      return _LandscapeTrackSkySpec(
        kind: kind,
        background: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF03050B), Color(0xFF171B2E), Color(0xFF090B14)],
        ),
        borderColor: ringTint.withValues(alpha: 0.82),
        titleColor: const Color(0xFFFFF8EF),
        flowColor: ringTint,
        glowColor: ringTint.withValues(alpha: 0.38),
        accentColor: ringTint,
        secondaryAccentColor: const Color(0xFFFFD26A),
      );
    case _LandscapeTrackSkyKind.meteor:
      final meteorTint = _landscapeTrackSkyMeteorTint(title);
      return _LandscapeTrackSkySpec(
        kind: kind,
        background: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF050816),
            Color.lerp(const Color(0xFF1E1B54), meteorTint, 0.2)!,
            const Color(0xFF0C1029),
          ],
        ),
        borderColor: meteorTint.withValues(alpha: 0.8),
        titleColor: const Color(0xFFF4F8FF),
        flowColor: meteorTint,
        glowColor: meteorTint.withValues(alpha: 0.36),
        accentColor: meteorTint,
        secondaryAccentColor: Colors.white,
      );
    case _LandscapeTrackSkyKind.planet:
      final planetTint = _landscapeTrackSkyPlanetTint(title);
      return _LandscapeTrackSkySpec(
        kind: kind,
        background: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF050915),
            Color.lerp(const Color(0xFF14254F), planetTint, 0.18)!,
            const Color(0xFF15113A),
          ],
        ),
        borderColor: planetTint.withValues(alpha: 0.78),
        titleColor: const Color(0xFFF8FAFF),
        flowColor: planetTint,
        glowColor: planetTint.withValues(alpha: 0.34),
        accentColor: planetTint,
        secondaryAccentColor: const Color(0xFFE9EFFF),
      );
    case _LandscapeTrackSkyKind.solarSeason:
      final solarTint = _landscapeTrackSkySolarTint(title);
      return _LandscapeTrackSkySpec(
        kind: kind,
        background: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF071326),
            Color.lerp(const Color(0xFF5C2F57), solarTint, 0.24)!,
            Color.lerp(const Color(0xFFF18E5B), solarTint, 0.38)!,
          ],
          stops: const [0.0, 0.58, 1.0],
        ),
        borderColor: solarTint.withValues(alpha: 0.82),
        titleColor: const Color(0xFFFFFAF1),
        flowColor: const Color(0xFFFFE7B8),
        glowColor: solarTint.withValues(alpha: 0.36),
        accentColor: solarTint,
        secondaryAccentColor: const Color(0xFFFFE7B8),
      );
    case _LandscapeTrackSkyKind.genericSky:
      return const _LandscapeTrackSkySpec(
        kind: _LandscapeTrackSkyKind.genericSky,
        background: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF050916), Color(0xFF17265B), Color(0xFF25133C)],
        ),
        borderColor: Color(0xFF9FB6FF),
        titleColor: Color(0xFFF7FAFF),
        flowColor: Color(0xFFDCE6FF),
        glowColor: Color(0x552F6FFF),
        accentColor: Color(0xFFB8C8FF),
        secondaryAccentColor: Colors.white,
      );
  }
}

List<Widget> _buildLandscapeTrackSkyStars({
  required String seed,
  required Color tint,
  required bool compact,
}) {
  final random = math.Random(seed.hashCode & 0x7fffffff);
  final count = compact ? 5 : 9;
  return List<Widget>.generate(count, (index) {
    final x = (-0.8 + random.nextDouble() * 1.7).clamp(-1.0, 1.0);
    final y = (-0.78 + random.nextDouble() * 1.45).clamp(-1.0, 1.0);
    final size = compact
        ? 0.9 + random.nextDouble() * 0.8
        : 1.0 + random.nextDouble() * 1.5;
    final opacity = 0.26 + random.nextDouble() * 0.42;
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
                BoxShadow(
                  color: color,
                  blurRadius: compact ? 1.2 : 2.6,
                  spreadRadius: compact ? 0 : 0.08,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  });
}

Widget _buildLandscapeTrackSkyAccent(
  _LandscapeTrackSkySpec spec,
  String title, {
  required bool compact,
}) {
  final lower = title.toLowerCase();
  final double size = compact ? 10.0 : 14.0;

  Widget orb({
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
        shape: BoxShape.circle,
        color: color,
        border: border,
        boxShadow: shadow,
      ),
    );
  }

  switch (spec.kind) {
    case _LandscapeTrackSkyKind.moon:
      return orb(
        color: spec.accentColor,
        shadow: [BoxShadow(color: spec.glowColor, blurRadius: compact ? 4 : 7)],
      );
    case _LandscapeTrackSkyKind.lunarEclipse:
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            orb(
              color: spec.accentColor,
              shadow: [
                BoxShadow(color: spec.glowColor, blurRadius: compact ? 4 : 7),
              ],
            ),
            Positioned(
              left: size * (lower.contains('penumbral') ? 0.16 : 0.28),
              top: size * 0.05,
              child: orb(color: const Color(0xCC03050B), diameter: size * 0.82),
            ),
          ],
        ),
      );
    case _LandscapeTrackSkyKind.solarEclipse:
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            orb(
              color: Colors.transparent,
              border: Border.all(
                color: spec.accentColor,
                width: compact ? 1.0 : 1.4,
              ),
              shadow: [
                BoxShadow(color: spec.glowColor, blurRadius: compact ? 5 : 8),
              ],
            ),
            orb(color: const Color(0xFF04060D), diameter: size * 0.64),
          ],
        ),
      );
    case _LandscapeTrackSkyKind.meteor:
      return SizedBox(
        width: size + 8,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: 0,
              top: compact ? 2.3 : 3.0,
              child: orb(
                color: Colors.white,
                diameter: compact ? 3.4 : 4.8,
                shadow: [
                  BoxShadow(color: spec.glowColor, blurRadius: compact ? 4 : 7),
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: compact ? 3.1 : 5.0,
              child: Transform.rotate(
                angle: -0.35,
                child: Container(
                  width: compact ? 11 : 16,
                  height: compact ? 1.2 : 1.8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        spec.accentColor.withValues(alpha: 0.18),
                        spec.accentColor.withValues(alpha: 0.7),
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
    case _LandscapeTrackSkyKind.planet:
      if (lower.contains('saturn')) {
        return SizedBox(
          width: size + 5,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: -0.25,
                child: Container(
                  width: size + 5,
                  height: compact ? 3.0 : 4.2,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: spec.secondaryAccentColor.withValues(alpha: 0.82),
                      width: compact ? 0.8 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              orb(color: spec.accentColor, diameter: size * 0.64),
            ],
          ),
        );
      }
      if (lower.contains('conjunction')) {
        return SizedBox(
          width: size + 4,
          height: size,
          child: Stack(
            children: [
              Positioned(
                right: 0,
                top: compact ? 0.8 : 1.2,
                child: orb(
                  color: spec.secondaryAccentColor,
                  diameter: size * 0.52,
                ),
              ),
              Positioned(
                left: 0,
                bottom: compact ? 0.8 : 1.3,
                child: orb(color: spec.accentColor, diameter: size * 0.64),
              ),
            ],
          ),
        );
      }
      return orb(
        color: spec.accentColor,
        shadow: [BoxShadow(color: spec.glowColor, blurRadius: compact ? 4 : 7)],
      );
    case _LandscapeTrackSkyKind.solarSeason:
      return SizedBox(
        width: size + 6,
        height: size,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: compact ? 1.0 : 2.0,
              child: Container(
                height: compact ? 1.0 : 1.4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      spec.secondaryAccentColor.withValues(alpha: 0.5),
                      spec.secondaryAccentColor,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              right: compact ? 2.0 : 4.0,
              bottom: compact ? 1.1 : 2.1,
              child: orb(
                color: spec.accentColor,
                diameter: compact ? 4.4 : 6.2,
                shadow: [
                  BoxShadow(color: spec.glowColor, blurRadius: compact ? 4 : 7),
                ],
              ),
            ),
          ],
        ),
      );
    case _LandscapeTrackSkyKind.genericSky:
      return orb(
        color: spec.accentColor,
        diameter: compact ? 4.2 : 5.8,
        shadow: [BoxShadow(color: spec.glowColor, blurRadius: compact ? 4 : 7)],
      );
  }
}

class _LandscapeDragPayload {
  final EventItem event;
  final int day;

  _LandscapeDragPayload(this.event, this.day);

  int get durationMin => (event.endMin - event.startMin).clamp(15, 12 * 60);
}

// ========================================
// MAIN LANDSCAPE MONTH VIEW WIDGET
// Entry point from both Main Calendar and Day View
// ========================================

class LandscapeMonthView extends StatelessWidget {
  final int initialKy;
  final int initialKm;
  final int? initialKd; // Optional - from day view
  final bool showGregorian;
  final ValueListenable<int>? dataVersion;
  final List<NoteData> Function(int ky, int km, int kd) notesForDay;
  final Map<int, FlowData> flowIndex;
  final Set<int> activeLedgerFlowIds;
  final String Function(int km) getMonthName;
  final void Function(int? flowId)? onManageFlows;
  final void Function(int ky, int km, int kd)? onAddNote;
  final void Function(int ky, int km)? onMonthChanged; // ✅ NEW CALLBACK
  final void Function(int ky, int km)? onVisibleMonthCommitted;
  final ValueChanged<VoidCallback?>? onTodayActionChanged;
  final void Function(int flowId)? onEndFlow;
  final Future<void> Function(int ky, int km, int kd, EventItem evt)?
  onDeleteNote;
  final Future<void> Function(int ky, int km, int kd, EventItem evt)?
  onEditNote;
  final Future<void> Function(String reminderId)? onEditReminder;
  final Future<void> Function(String reminderId)? onEndReminder;
  final Future<void> Function(EventItem evt)? onShareReminder;
  final Future<void> Function(
    int ky,
    int km,
    int kd,
    EventItem evt,
    int newStartMin,
  )?
  onMoveEventTime;
  final Future<void> Function(EventItem evt)? onShareNote;
  final Future<void> Function(String text)? onAppendToJournal;
  final MaatJournalResponseBlockWriter? onWriteJournalResponse;
  final Future<void> Function(int flowId)? onSaveFlow;
  final Future<void> Function({
    required String clientEventId,
    required int flowId,
    required DateTime completedOnDate,
    Map<String, dynamic>? metadata,
  })?
  onRecordCompletion;
  final Future<void> Function(String clientEventId)? onUnrecordCompletion;
  final Future<void> Function(String badgeId)? onRemoveCompletionBadge;
  final EventDetailRestorationState? initialEventDetailRestorationState;
  final ValueChanged<EventDetailRestorationState?>?
  onEventDetailRestorationChanged;
  final bool Function()? shouldPreserveEventDetailRestorationOnClose;
  final bool embeddedInCalendarScaffold;

  const LandscapeMonthView({
    super.key,
    required this.initialKy,
    required this.initialKm,
    this.initialKd,
    required this.showGregorian,
    this.dataVersion,
    required this.notesForDay,
    required this.flowIndex,
    this.activeLedgerFlowIds = const <int>{},
    required this.getMonthName,
    this.onManageFlows,
    this.onAddNote,
    this.onMonthChanged, // ✅ NEW CALLBACK
    this.onVisibleMonthCommitted,
    this.onTodayActionChanged,
    this.onEndFlow,
    this.onDeleteNote,
    this.onEditNote,
    this.onEditReminder,
    this.onEndReminder,
    this.onShareReminder,
    this.onMoveEventTime,
    this.onShareNote,
    this.onAppendToJournal,
    this.onWriteJournalResponse,
    this.onSaveFlow,
    this.onRecordCompletion,
    this.onUnrecordCompletion,
    this.onRemoveCompletionBadge,
    this.initialEventDetailRestorationState,
    this.onEventDetailRestorationChanged,
    this.shouldPreserveEventDetailRestorationOnClose,
    this.embeddedInCalendarScaffold = false,
  });

  @override
  Widget build(BuildContext context) {
    return LandscapeMonthPager(
      initialKy: initialKy,
      initialKm: initialKm,
      initialDay: initialKd,
      showGregorian: showGregorian,
      dataVersion: dataVersion,
      notesForDay: notesForDay,
      flowIndex: flowIndex,
      activeLedgerFlowIds: activeLedgerFlowIds,
      getMonthName: getMonthName,
      onManageFlows: onManageFlows,
      onAddNote: onAddNote,
      onMonthChanged: onMonthChanged, // ✅ PASS CALLBACK DOWN
      onVisibleMonthCommitted: onVisibleMonthCommitted,
      onTodayActionChanged: onTodayActionChanged,
      onEndFlow: onEndFlow,
      onDeleteNote: onDeleteNote,
      onEditNote: onEditNote,
      onEditReminder: onEditReminder,
      onEndReminder: onEndReminder,
      onShareReminder: onShareReminder,
      onMoveEventTime: onMoveEventTime,
      onShareNote: onShareNote,
      onAppendToJournal: onAppendToJournal,
      onWriteJournalResponse: onWriteJournalResponse,
      onSaveFlow: onSaveFlow,
      onRecordCompletion: onRecordCompletion,
      onUnrecordCompletion: onUnrecordCompletion,
      onRemoveCompletionBadge: onRemoveCompletionBadge,
      initialEventDetailRestorationState: initialEventDetailRestorationState,
      onEventDetailRestorationChanged: onEventDetailRestorationChanged,
      shouldPreserveEventDetailRestorationOnClose:
          shouldPreserveEventDetailRestorationOnClose,
      embeddedInCalendarScaffold: embeddedInCalendarScaffold,
    );
  }
}

// ========================================
// LANDSCAPE MONTH PAGER
// PageView for infinite month scrolling
// ========================================

class LandscapeMonthPager extends StatefulWidget {
  final int initialKy;
  final int initialKm;
  final int? initialDay;
  final bool showGregorian;
  final ValueListenable<int>? dataVersion;
  final List<NoteData> Function(int ky, int km, int kd) notesForDay;
  final Map<int, FlowData> flowIndex;
  final Set<int> activeLedgerFlowIds;
  final String Function(int km) getMonthName;
  final void Function(int? flowId)? onManageFlows;
  final void Function(int ky, int km, int kd)? onAddNote;
  final void Function(int ky, int km)? onMonthChanged; // ✅ NEW CALLBACK
  final void Function(int ky, int km)? onVisibleMonthCommitted;
  final ValueChanged<VoidCallback?>? onTodayActionChanged;
  final void Function(int flowId)? onEndFlow;
  final Future<void> Function(int ky, int km, int kd, EventItem evt)?
  onDeleteNote;
  final Future<void> Function(int ky, int km, int kd, EventItem evt)?
  onEditNote;
  final Future<void> Function(String reminderId)? onEditReminder;
  final Future<void> Function(String reminderId)? onEndReminder;
  final Future<void> Function(EventItem evt)? onShareReminder;
  final Future<void> Function(
    int ky,
    int km,
    int kd,
    EventItem evt,
    int newStartMin,
  )?
  onMoveEventTime;
  final Future<void> Function(EventItem evt)? onShareNote;
  final Future<void> Function(String text)? onAppendToJournal;
  final MaatJournalResponseBlockWriter? onWriteJournalResponse;
  final Future<void> Function(int flowId)? onSaveFlow;
  final Future<void> Function({
    required String clientEventId,
    required int flowId,
    required DateTime completedOnDate,
    Map<String, dynamic>? metadata,
  })?
  onRecordCompletion;
  final Future<void> Function(String clientEventId)? onUnrecordCompletion;
  final Future<void> Function(String badgeId)? onRemoveCompletionBadge;
  final EventDetailRestorationState? initialEventDetailRestorationState;
  final ValueChanged<EventDetailRestorationState?>?
  onEventDetailRestorationChanged;
  final bool Function()? shouldPreserveEventDetailRestorationOnClose;
  final bool embeddedInCalendarScaffold;

  const LandscapeMonthPager({
    super.key,
    required this.initialKy,
    required this.initialKm,
    this.initialDay,
    required this.showGregorian,
    this.dataVersion,
    required this.notesForDay,
    required this.flowIndex,
    this.activeLedgerFlowIds = const <int>{},
    required this.getMonthName,
    this.onManageFlows,
    this.onAddNote,
    this.onMonthChanged, // ✅ NEW CALLBACK
    this.onVisibleMonthCommitted,
    this.onTodayActionChanged,
    this.onEndFlow,
    this.onDeleteNote,
    this.onEditNote,
    this.onEditReminder,
    this.onEndReminder,
    this.onShareReminder,
    this.onMoveEventTime,
    this.onShareNote,
    this.onAppendToJournal,
    this.onWriteJournalResponse,
    this.onSaveFlow,
    this.onRecordCompletion,
    this.onUnrecordCompletion,
    this.onRemoveCompletionBadge,
    this.initialEventDetailRestorationState,
    this.onEventDetailRestorationChanged,
    this.shouldPreserveEventDetailRestorationOnClose,
    this.embeddedInCalendarScaffold = false,
  });

  @override
  State<LandscapeMonthPager> createState() => _LandscapeMonthPagerState();
}

class _LandscapeMonthPagerState extends State<LandscapeMonthPager> {
  late PageController _pageController;
  static const int _centerPage = 100000; // Match your _LandscapePager's _origin

  // 🔧 NEW: Track current page for AppBar display
  int _currentPage = 100000;

  // ✅ HARDENING 3: Debounce onPageChanged to prevent redundant callbacks
  int? _lastNotifiedPage;

  // ✅ FIX 3: Animation guard to prevent remapping during animation
  bool _isAnimating = false;

  // ✅ FIX 1: Track actual displayed month (avoids stale widget.initialKy/Km)
  ({int kYear, int kMonth})? _actualMonth;

  // ✅ Today Button Fix: Stable internal base (doesn't depend on widget props)
  late int _baseTotalMonths; // ✅ Use late (safer than = 0)

  // ✅ Today Button Fix: Dual flags to prevent shuffle
  bool _isJumpingToToday = false; // Blocks onPageChanged during Today jump
  bool _suppressRemap = false; // Blocks didUpdateWidget remap

  Gradient get _monthTitleGradient =>
      widget.showGregorian ? whiteGloss : goldGloss;

  void _publishTodayAction() {
    widget.onTodayActionChanged?.call(_jumpToToday);
  }

  // ✅ FIX A: Canonical month math - Year 1, Month 1 = index 0
  /// Absolute month index where (Year 1, Month 1) == 0
  int _toTotalMonths(int ky, int km) {
    // km expected 1..13, ky can be any integer (…,-1,0,1,2,…)
    return (ky - 1) * 13 + (km - 1); // ✅ Year 1, Month 1 = 0
  }

  /// Calculate absolute page for a month using stable internal base
  /// This avoids dependency on potentially stale widget.initialKy/Km
  int _pageForAbsolute(int ky, int km) {
    final total = _toTotalMonths(ky, km);
    return _centerPage + (total - _baseTotalMonths);
  }

  /// Inverse of _toTotalMonths with Euclidean normalization
  ({int kYear, int kMonth}) _fromTotalMonths(int total) {
    // m0 in 0..12 even for negative totals
    final m0 = ((total % 13) + 13) % 13;
    // Floor-like division because we removed the remainder first
    final y0 = (total - m0) ~/ 13;
    return (kYear: y0 + 1, kMonth: m0 + 1); // ✅ Convert back to 1-indexed
  }

  ({int kYear, int kMonth}) _monthForPage(int page) {
    final delta = page - _centerPage;
    final total = _baseTotalMonths + delta; // ✅ Use canonical base
    return _fromTotalMonths(total);
  }

  ({int kYear, int kMonth}) _currentVisibleMonth() {
    if (_pageController.hasClients) {
      final roundedPage = _pageController.page?.round();
      if (roundedPage != null) {
        return _monthForPage(roundedPage);
      }
    }
    return _actualMonth ?? _monthForPage(_currentPage);
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _centerPage);
    _currentPage = _centerPage; // 🔧 NEW: Initialize
    _lastNotifiedPage = _centerPage; // Optional: for consistency
    // ✅ Initialize stable base
    _baseTotalMonths = _toTotalMonths(widget.initialKy, widget.initialKm);
    _publishTodayAction();
  }

  @override
  void dispose() {
    final visibleMonth = _currentVisibleMonth();
    widget.onVisibleMonthCommitted?.call(
      visibleMonth.kYear,
      visibleMonth.kMonth,
    );
    widget.onTodayActionChanged?.call(null);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LandscapeMonthPager oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.onTodayActionChanged != widget.onTodayActionChanged) {
      oldWidget.onTodayActionChanged?.call(null);
      _publishTodayAction();
    }

    final newBase = _toTotalMonths(widget.initialKy, widget.initialKm);
    if (newBase == _baseTotalMonths) return;

    final oldBase = _baseTotalMonths;
    _baseTotalMonths = newBase; // ✅ Update base immediately

    if (_suppressRemap || _isAnimating) {
      // ✅ Keep header consistent while suppressed
      if (_pageController.hasClients) {
        final pageNow = _pageController.page?.round() ?? _currentPage;
        final total = _baseTotalMonths + (pageNow - _centerPage);
        _actualMonth = _fromTotalMonths(total);
      }
      if (kDebugMode && _suppressRemap) {
        _logLandscape(
          '✓ [PAGER] Updated base during suppression: $oldBase → $newBase',
        );
      }
      return;
    }

    // ✅ Preserve same absolute month on screen
    final delta = _currentPage - _centerPage;
    final curTotal = oldBase + delta;
    final newDelta = curTotal - newBase;
    final newPage = _centerPage + newDelta;

    if (kDebugMode) {
      _logLandscape('🔄 [PAGER] Base changed: $oldBase → $newBase');
      _logLandscape('   Preserving absolute month: $curTotal');
      _logLandscape('   New page: $newPage');
    }

    if (_pageController.hasClients && newPage != _currentPage) {
      _pageController.jumpToPage(newPage);
      _currentPage = newPage;
      _lastNotifiedPage = newPage;
      _actualMonth = _monthForPage(newPage);

      if (kDebugMode) {
        _logLandscape('✓ [PAGER] Remap complete');
      }
    }

    // When callback becomes available, force PageView to rebuild current page
    if (oldWidget.onAddNote == null && widget.onAddNote != null) {
      if (kDebugMode) {
        _logLandscape('⚡ [PAGER] Callback just arrived! Forcing rebuild...');
      }
      setState(() {
        // This will cause PageView.builder to call itemBuilder again
        // with the now-available callback
      });
    }
  }

  // ✅ FIX 3: Old _monthForPage removed - now using helper method from Fix 1

  Future<void> _jumpToToday() async {
    if (!_pageController.hasClients) return;

    final t = KemeticMath.fromGregorian(DateTime.now());

    // ✅ NEW: refresh base first so header math is correct on first press
    _baseTotalMonths = _toTotalMonths(t.kYear, t.kMonth);

    final targetPage = _pageForAbsolute(t.kYear, t.kMonth);

    _isJumpingToToday = true;
    _isAnimating = true;
    _suppressRemap = true;

    await _pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );

    setState(() {
      _currentPage = targetPage;
      _actualMonth = (kYear: t.kYear, kMonth: t.kMonth);
    });

    widget.onMonthChanged?.call(t.kYear, t.kMonth);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isJumpingToToday = false;
      _isAnimating = false;
      _suppressRemap = false;
    });
  }

  // 🔧 NEW: Get days in month (needed for year label calculation)
  int _getDaysInMonth(int kYear, int kMonth) {
    if (kMonth == 13) {
      return KemeticMath.isLeapKemeticYear(kYear) ? 6 : 5;
    }
    return 30;
  }

  // 🔧 NEW: Get year label - always Gregorian (matching current behavior)
  String _getYearLabel(int kYear, int kMonth) {
    final firstDayG = KemeticMath.toGregorian(kYear, kMonth, 1);
    final lastDay = _getDaysInMonth(kYear, kMonth);
    final lastDayG = KemeticMath.toGregorian(kYear, kMonth, lastDay);

    if (firstDayG.year == lastDayG.year) {
      return '${firstDayG.year}';
    } else {
      return '${firstDayG.year}/${lastDayG.year}';
    }
  }

  Widget _buildMonthInfo(String monthName, String yearLabel) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (Rect bounds) =>
              _monthTitleGradient.createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: MonthNameText(
            monthName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            softWrap: false,
            maxLines: 1,
            overflow: TextOverflow.fade,
          ),
        ),
        GlossyText(
          text: yearLabel,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
          gradient: _monthTitleGradient,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embeddedInCalendarScaffold) {
      return ColoredBox(
        color: _landscapeBg,
        child: _buildBodyWithSwipeGate(context),
      );
    }

    return Scaffold(
      backgroundColor: _landscapeBg,
      body: Column(
        children: [
          _buildCustomHeader(context),
          Expanded(child: _buildBodyWithSwipeGate(context)),
        ],
      ),
    );
  }

  // 🔧 FIXED: Custom header with month swipe gesture - GestureDetector only wraps title area
  Widget _buildCustomHeader(BuildContext context) {
    // ✅ FIX 1: Prefer _actualMonth to avoid stale widget.initialKy/Km
    final currentMonth = _actualMonth ?? _monthForPage(_currentPage);
    final monthName = widget.getMonthName(currentMonth.kMonth);
    final yearLabel = _getYearLabel(currentMonth.kYear, currentMonth.kMonth);

    return Container(
      color: _landscapeSurface,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: kToolbarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _landscapeSurface,
            border: Border(
              bottom: BorderSide(
                color: _landscapeGold.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Month/Year title - REMOVED GestureDetector, PageView handles swipes
              Expanded(child: _buildMonthInfo(monthName, yearLabel)),
              // Flow Studio button - OUTSIDE GestureDetector (no gesture interference)
              IconButton(
                tooltip: 'Flow Studio',
                icon: KemeticGold.glyph(MeduNeterGlyphs.flowStudio, size: 22),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                onPressed: widget.onManageFlows != null
                    ? () {
                        if (kDebugMode) {
                          _logLandscape('🔘 [LANDSCAPE] Flow Studio tapped');
                        }
                        widget.onManageFlows!(null);
                      }
                    : null,
              ),
              // Add Note button - OUTSIDE GestureDetector (no gesture interference)
              IconButton(
                tooltip: 'New note',
                icon: KemeticGold.icon(Icons.add),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                onPressed: widget.onAddNote != null
                    ? () {
                        if (kDebugMode) {
                          _logLandscape('🔘 [LANDSCAPE] Add Note tapped');
                        }
                        final now = DateTime.now();
                        final today = KemeticMath.fromGregorian(now);
                        final currentMonth = _monthForPage(_currentPage);
                        final kd =
                            (currentMonth.kYear == today.kYear &&
                                currentMonth.kMonth == today.kMonth)
                            ? today.kDay
                            : 1;

                        if (currentMonth.kMonth == 13 && kDebugMode) {
                          _logLandscape(
                            '⚠️ [LANDSCAPE] Creating note in sacred Month 13 (Heriu Renpet)',
                          );
                          _logLandscape('   Day: $kd');
                        }

                        widget.onAddNote!(
                          currentMonth.kYear,
                          currentMonth.kMonth,
                          kd,
                        );
                      }
                    : null,
              ),
              // Today button - OUTSIDE GestureDetector (no gesture interference)
              TextButton(
                onPressed: _jumpToToday,
                child: const Text(
                  'Today',
                  style: TextStyle(
                    color: _landscapeGold,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  // 🔧 NEW: Body with PageView (no gesture handling - grid handles its own)
  Widget _buildBodyWithSwipeGate(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.horizontal,
      physics:
          const PageScrollPhysics(), // ✅ Allows gesture AND animateToPage()
      pageSnapping: true,
      onPageChanged: (page) {
        // ✅ HARDENING 3: Debounce to prevent redundant callbacks
        if (_lastNotifiedPage == page) return;

        final m = _monthForPage(page);

        // ✅ Always keep local truth in sync for UI
        setState(() {
          _currentPage = page;
          _actualMonth = m;
        });
        _lastNotifiedPage = page;

        // ✅ If in middle of Today jump, don't ping parent again
        if (_isJumpingToToday) {
          if (kDebugMode) {
            _logLandscape(
              '📄 [PAGER] Page changed to $page during Today jump - state updated, parent notification blocked',
            );
          }
          return;
        }

        // ✅ Normal swipe → notify parent so it sends correct data
        if (kDebugMode) {
          _logLandscape('📄 [PAGER] Page changed to: $page');
          _logLandscape('   Month: ${m.kYear}-${m.kMonth}');
        }
        widget.onMonthChanged?.call(m.kYear, m.kMonth);
      },
      itemBuilder: (context, index) {
        final m = _monthForPage(index);
        final pageInitialDay =
            (widget.initialDay != null &&
                m.kYear == widget.initialKy &&
                m.kMonth == widget.initialKm)
            ? widget.initialDay
            : null;

        if (kDebugMode) {
          _logLandscape(
            '🔧 [PAGER] Creating LandscapeMonthGridBody for page $index',
          );
          _logLandscape('   Month: ${m.kYear}-${m.kMonth}');
        }

        return LandscapeMonthGridBody(
          key: ValueKey('grid-body-${m.kYear}-${m.kMonth}'),
          kYear: m.kYear,
          kMonth: m.kMonth,
          initialDay: pageInitialDay, // ✅ use 'initialDay'
          showGregorian: widget.showGregorian,
          dataVersion: widget.dataVersion,
          notesForDay: widget.notesForDay,
          flowIndex: widget.flowIndex,
          activeLedgerFlowIds: widget.activeLedgerFlowIds,
          getMonthName: widget.getMonthName,
          onManageFlows: widget.onManageFlows,
          onAddNote: widget.onAddNote,
          onEndFlow: widget.onEndFlow,
          onDeleteNote: widget.onDeleteNote,
          onEditNote: widget.onEditNote,
          onEditReminder: widget.onEditReminder,
          onEndReminder: widget.onEndReminder,
          onShareReminder: widget.onShareReminder,
          onMoveEventTime: widget.onMoveEventTime,
          onShareNote: widget.onShareNote,
          onAppendToJournal: widget.onAppendToJournal,
          onWriteJournalResponse: widget.onWriteJournalResponse,
          onSaveFlow: widget.onSaveFlow,
          onRecordCompletion: widget.onRecordCompletion,
          onUnrecordCompletion: widget.onUnrecordCompletion,
          onRemoveCompletionBadge: widget.onRemoveCompletionBadge,
          initialEventDetailRestorationState:
              widget.initialEventDetailRestorationState,
          onEventDetailRestorationChanged:
              widget.onEventDetailRestorationChanged,
          shouldPreserveEventDetailRestorationOnClose:
              widget.shouldPreserveEventDetailRestorationOnClose,
        );
      },
    );
  }
}

// ========================================
// LANDSCAPE MONTH GRID BODY
// The actual scrollable month grid (single month) - no Scaffold/AppBar
// ========================================

class LandscapeMonthGridBody extends StatefulWidget {
  final int kYear;
  final int kMonth;
  final int? initialDay;
  final bool showGregorian;
  final ValueListenable<int>? dataVersion;
  final List<NoteData> Function(int ky, int km, int kd) notesForDay;
  final Map<int, FlowData> flowIndex;
  final Set<int> activeLedgerFlowIds;
  final String Function(int km) getMonthName;
  final void Function(int? flowId)? onManageFlows;
  final void Function(int ky, int km, int kd)? onAddNote;
  final void Function(int flowId)? onEndFlow;
  final Future<void> Function(int ky, int km, int kd, EventItem evt)?
  onDeleteNote;
  final Future<void> Function(int ky, int km, int kd, EventItem evt)?
  onEditNote;
  final Future<void> Function(String reminderId)? onEditReminder;
  final Future<void> Function(String reminderId)? onEndReminder;
  final Future<void> Function(EventItem evt)? onShareReminder;
  final Future<void> Function(
    int ky,
    int km,
    int kd,
    EventItem evt,
    int newStartMin,
  )?
  onMoveEventTime;
  final Future<void> Function(EventItem evt)? onShareNote;
  final Future<void> Function(String text)? onAppendToJournal;
  final MaatJournalResponseBlockWriter? onWriteJournalResponse;
  final Future<void> Function(int flowId)? onSaveFlow;
  final Future<void> Function({
    required String clientEventId,
    required int flowId,
    required DateTime completedOnDate,
    Map<String, dynamic>? metadata,
  })?
  onRecordCompletion;
  final Future<void> Function(String clientEventId)? onUnrecordCompletion;
  final Future<void> Function(String badgeId)? onRemoveCompletionBadge;
  final EventDetailRestorationState? initialEventDetailRestorationState;
  final ValueChanged<EventDetailRestorationState?>?
  onEventDetailRestorationChanged;
  final bool Function()? shouldPreserveEventDetailRestorationOnClose;

  const LandscapeMonthGridBody({
    super.key,
    required this.kYear,
    required this.kMonth,
    this.initialDay,
    required this.showGregorian,
    this.dataVersion,
    required this.notesForDay,
    required this.flowIndex,
    this.activeLedgerFlowIds = const <int>{},
    required this.getMonthName,
    this.onManageFlows,
    this.onAddNote,
    this.onEndFlow,
    this.onDeleteNote,
    this.onEditNote,
    this.onEditReminder,
    this.onEndReminder,
    this.onShareReminder,
    this.onMoveEventTime,
    this.onShareNote,
    this.onAppendToJournal,
    this.onWriteJournalResponse,
    this.onSaveFlow,
    this.onRecordCompletion,
    this.onUnrecordCompletion,
    this.onRemoveCompletionBadge,
    this.initialEventDetailRestorationState,
    this.onEventDetailRestorationChanged,
    this.shouldPreserveEventDetailRestorationOnClose,
  });

  @override
  State<LandscapeMonthGridBody> createState() => _LandscapeMonthGridBodyState();
}

class _LandscapeMonthGridBodyState extends State<LandscapeMonthGridBody> {
  // Layout constants (matching existing landscape)
  static const double _rowH = 64.0; // hour row height
  static const double _gutterW = 56.0; // time gutter width
  static const double _headerH =
      kLandscapeHeaderHeight; // day number header (shared constant)
  static const double _daySepW = 1.0; // day separator
  static const double _hourSepH = 1.0; // hour separator
  static const double _kLandscapeEventMinHeight = 64.0;
  static const int _visibleEventDayBuffer = 1;

  // 🔧 UPDATED: Use shared color constants
  static const Color _gold = _landscapeGold;
  static const Color _bg = _landscapeBg;
  static const Color _surface = _landscapeSurface;
  static const Color _divider = _landscapeDivider;

  // 4 synchronized scroll controllers
  late ScrollController _hHeader;
  late ScrollController _hGrid;
  late ScrollController _vGutter;
  late ScrollController _vGrid;
  final GlobalKey _gridKey = GlobalKey();
  bool _syncingH = false;
  bool _syncingV = false;
  bool _visibleEventRangeUpdateScheduled = false;
  int _visibleEventStartDay = 1;
  int _visibleEventEndDay = 30;

  // 🔍 NEW: Debug tracking
  final int _buttonTapCount = 0;
  bool _isDisposed = false;
  String? _initialEventDetailRestoreKey;
  bool _initialEventDetailRestoreInFlight = false;

  @override
  void initState() {
    super.initState();

    if (kDebugMode) {
      _logLandscape('🟢 [LANDSCAPE] LandscapeMonthGridBody initState()');
      _logLandscape('   kYear: ${widget.kYear}, kMonth: ${widget.kMonth}');
      _logLandscape(
        '   onAddNote callback: ${widget.onAddNote != null ? "PROVIDED" : "NULL"}',
      );
    }

    _hHeader = ScrollController();
    _hGrid = ScrollController();
    _vGutter = ScrollController();
    _vGrid = ScrollController();

    // Sync horizontal scrolling (grid → header only, since header is non-scrollable)
    // REMOVED: _hHeader.addListener - header can't scroll, so no need to sync header→grid

    _hGrid.addListener(() {
      if (_syncingH) return;
      _syncingH = true;
      if (_hHeader.hasClients) {
        _hHeader.jumpTo(
          _hGrid.offset.clamp(0.0, _hHeader.position.maxScrollExtent),
        );
      }
      _syncingH = false;
      _scheduleVisibleEventRangeUpdate();
    });

    // Sync vertical scrolling
    _vGutter.addListener(() {
      if (_syncingV) return;
      _syncingV = true;
      if (_vGrid.hasClients) {
        _vGrid.jumpTo(
          _vGutter.offset.clamp(0.0, _vGrid.position.maxScrollExtent),
        );
      }
      _syncingV = false;
    });

    _vGrid.addListener(() {
      if (_syncingV) return;
      _syncingV = true;
      if (_vGutter.hasClients) {
        _vGutter.jumpTo(
          _vGrid.offset.clamp(0.0, _vGutter.position.maxScrollExtent),
        );
      }
      _syncingV = false;
    });

    // Scroll to initial day if provided (from day view)
    _initializeVisibleEventRange();
    if (widget.initialDay != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToDay(widget.initialDay!);
      });
    }
    _scheduleInitialEventDetailRestore();
  }

  @override
  void didUpdateWidget(covariant LandscapeMonthGridBody old) {
    super.didUpdateWidget(old);
    if (old.initialDay != widget.initialDay && widget.initialDay != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToDay(widget.initialDay!),
      );
    }
    if (_eventDetailRestoreKey(old.initialEventDetailRestorationState) !=
        _eventDetailRestoreKey(widget.initialEventDetailRestorationState)) {
      _scheduleInitialEventDetailRestore();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _visibleEventRangeUpdateScheduled = false;
    if (kDebugMode) {
      _logLandscape('🔴 [LANDSCAPE] LandscapeMonthGridBody dispose()');
      _logLandscape(
        '   Button was tapped $_buttonTapCount times before disposal',
      );
    }
    _hHeader.dispose();
    _hGrid.dispose();
    _vGutter.dispose();
    _vGrid.dispose();
    super.dispose();
  }

  void _scrollToDay(int day) {
    if (!_hGrid.hasClients) return;

    final width = MediaQuery.of(context).size.width;
    final colW = (width - _gutterW) / 5.0; // ~5 visible days
    final targetOffset = (day - 3) * (colW + _daySepW); // Center on day

    _hGrid.animateTo(
      targetOffset.clamp(0.0, _hGrid.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    _scheduleVisibleEventRangeUpdate();
  }

  void _initializeVisibleEventRange() {
    final maxDay = _getDaysInMonth();
    final initialDay = widget.initialDay?.clamp(1, maxDay).toInt() ?? 1;
    _visibleEventStartDay = math.max(1, initialDay - 2);
    _visibleEventEndDay = math.min(maxDay, initialDay + 4);
  }

  void _scheduleVisibleEventRangeUpdate() {
    if (_visibleEventRangeUpdateScheduled || _isDisposed) return;
    _visibleEventRangeUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibleEventRangeUpdateScheduled = false;
      _updateVisibleEventRange();
    });
  }

  void _updateVisibleEventRange() {
    if (!mounted || !_hGrid.hasClients) return;
    final width = MediaQuery.sizeOf(context).width;
    final colW = (width - _gutterW) / 5.0;
    final dayStride = colW + _daySepW;
    if (dayStride <= 0) return;

    final firstVisibleDay = (_hGrid.offset / dayStride).floor() + 1;
    final visibleDayCount = ((width - _gutterW) / dayStride).ceil();
    final maxDay = _getDaysInMonth();
    final nextStart = math.max(1, firstVisibleDay - _visibleEventDayBuffer);
    final nextEnd = math.min(
      maxDay,
      firstVisibleDay + visibleDayCount + _visibleEventDayBuffer,
    );

    if (nextStart == _visibleEventStartDay && nextEnd == _visibleEventEndDay) {
      return;
    }
    setState(() {
      _visibleEventStartDay = nextStart;
      _visibleEventEndDay = nextEnd;
    });
  }

  String? _eventDetailRestoreKey(EventDetailRestorationState? state) {
    if (state == null) return null;
    return '${state.kYear}:${state.kMonth}:${state.kDay}:'
        '${state.identityType}:${state.identityValue}';
  }

  bool _eventDetailStateTargetsThisMonth(EventDetailRestorationState state) {
    return state.kYear == widget.kYear && state.kMonth == widget.kMonth;
  }

  EventDetailRestorationState? _detailRestorationStateForTarget(
    DayViewSheetEventTarget target,
  ) {
    return eventDetailRestorationStateForTarget(target);
  }

  void _publishEventDetailRestorationTarget(DayViewSheetEventTarget target) {
    final state = _detailRestorationStateForTarget(target);
    final key = _eventDetailRestoreKey(state);
    if (key != null) {
      _initialEventDetailRestoreKey = key;
      _initialEventDetailRestoreInFlight = false;
    }
    widget.onEventDetailRestorationChanged?.call(state);
  }

  void _clearEventDetailRestorationIfAllowed() {
    if (widget.shouldPreserveEventDetailRestorationOnClose?.call() ?? false) {
      return;
    }
    widget.onEventDetailRestorationChanged?.call(null);
  }

  void _scheduleInitialEventDetailRestore() {
    final state = widget.initialEventDetailRestorationState;
    final key = _eventDetailRestoreKey(state);
    if (state == null ||
        key == null ||
        key == _initialEventDetailRestoreKey ||
        !_eventDetailStateTargetsThisMonth(state) ||
        _initialEventDetailRestoreInFlight) {
      return;
    }
    _initialEventDetailRestoreInFlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restoreInitialEventDetailIfNeeded(state, key));
    });
  }

  Future<void> _restoreInitialEventDetailIfNeeded(
    EventDetailRestorationState state,
    String key, [
    int attempt = 0,
  ]) async {
    if (!mounted) return;
    if (_eventDetailRestoreKey(widget.initialEventDetailRestorationState) !=
        key) {
      _initialEventDetailRestoreInFlight = false;
      _scheduleInitialEventDetailRestore();
      return;
    }
    if (_initialEventDetailRestoreKey == key) {
      _initialEventDetailRestoreInFlight = false;
      return;
    }
    if (!_eventDetailStateTargetsThisMonth(state)) {
      _initialEventDetailRestoreInFlight = false;
      return;
    }

    final target = eventDetailTargetFromRestorationState(
      state: state,
      events: _eventsForKemeticDay(state.kYear, state.kMonth, state.kDay),
    );
    if (target == null) {
      if (attempt < 20) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        return _restoreInitialEventDetailIfNeeded(state, key, attempt + 1);
      }
      _initialEventDetailRestoreKey = key;
      _initialEventDetailRestoreInFlight = false;
      widget.onEventDetailRestorationChanged?.call(null);
      return;
    }

    _initialEventDetailRestoreKey = key;
    _initialEventDetailRestoreInFlight = false;
    _scrollToDay(state.kDay);
    _showEventDetail(target.event, state.kDay, initialTarget: target);
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode && _buttonTapCount == 0) {
      _logLandscape('🏗️  [LANDSCAPE] build() - FIRST TIME');
      _logLandscape('   Context: $context');
      _logLandscape('   Mounted: $mounted');
      _logLandscape('   Disposed: $_isDisposed');
    }

    final width = MediaQuery.of(context).size.width;

    final dayCount = _getDaysInMonth();
    final colW = (width - _gutterW) / 5.0; // ~5 visible days
    final gridW = colW * dayCount + (_daySepW * (dayCount - 1));
    final gridH = _rowH * 24 + (_hourSepH * 23);

    // 🔧 CHANGED: Return Container with Stack directly (no Scaffold/AppBar)
    return Container(
      color: _bg, // True black background
      child: Stack(
        children: [
          // Top-left corner (empty space above gutter)
          Positioned(
            left: 0,
            top: 0,
            width: _gutterW,
            height: _headerH,
            child: Container(color: _surface),
          ),

          // Day headers (scrollable horizontally)
          Positioned(
            left: _gutterW,
            top: 0,
            right: 0,
            height: _headerH,
            child: IgnorePointer(
              ignoring:
                  true, // Prevent any gesture recognizers from header subtree
              child: SingleChildScrollView(
                controller: _hHeader,
                scrollDirection: Axis.horizontal,
                physics:
                    const NeverScrollableScrollPhysics(), // 🔧 REMOVES FROM GESTURE ARENA
                child: Row(
                  children: [
                    for (int day = 1; day <= dayCount; day++)
                      _buildDayHeader(day, colW),
                  ],
                ),
              ),
            ),
          ),

          // Hour labels (scrollable vertically)
          Positioned(
            left: 0,
            top: _headerH,
            width: _gutterW,
            bottom: 0,
            child: Container(
              color: _surface,
              child: SingleChildScrollView(
                controller: _vGutter,
                physics:
                    const ClampingScrollPhysics(), // 🔧 Prevent gesture conflicts
                child: Column(
                  children: [
                    for (int hour = 0; hour < 24; hour++)
                      Container(
                        height: _rowH,
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.only(right: 8, top: 4),
                        child: Text(
                          _formatHour(hour),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF808080),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Main grid (scrollable in both directions)
          Positioned(
            left: _gutterW,
            top: _headerH,
            right: 0,
            bottom: 0,
            child: SingleChildScrollView(
              controller: _vGrid,
              physics:
                  const ClampingScrollPhysics(), // 🔧 Prevent gesture conflicts
              child: SingleChildScrollView(
                controller: _hGrid,
                scrollDirection: Axis.horizontal,
                physics:
                    const ClampingScrollPhysics(), // ✅ Re-enabled for horizontal scrolling
                child: DragTarget<_LandscapeDragPayload>(
                  key: _gridKey,
                  builder: (context, candidateData, rejectedData) {
                    return SizedBox(
                      width: gridW,
                      height: gridH,
                      child: Stack(
                        fit: StackFit.expand,
                        clipBehavior: Clip.none,
                        children: [
                          // Grid lines
                          _buildGridLines(dayCount, colW),

                          // Event blocks
                          for (
                            int day = _visibleEventStartDay;
                            day <= _visibleEventEndDay;
                            day++
                          )
                            ..._buildEventsForDay(day, colW),
                        ],
                      ),
                    );
                  },
                  onWillAcceptWithDetails: (_) => true,
                  onAcceptWithDetails: (details) {
                    if (kDebugMode) {
                      debugPrint(
                        '[Landscape] DragTarget onAcceptWithDetails day=${details.data.day}',
                      );
                    }
                    final box =
                        _gridKey.currentContext?.findRenderObject()
                            as RenderBox?;
                    if (box == null) {
                      if (kDebugMode) {
                        debugPrint(
                          '[Landscape] DragTarget: box is null, skipping move',
                        );
                      }
                      return;
                    }
                    final local = box.globalToLocal(details.offset);
                    final double x =
                        local.dx + (_hGrid.hasClients ? _hGrid.offset : 0.0);
                    final double y =
                        local.dy + (_vGrid.hasClients ? _vGrid.offset : 0.0);
                    int day = (x / (colW + _daySepW)).floor() + 1;
                    final maxDay = _getDaysInMonth();
                    day = day.clamp(1, maxDay).toInt();
                    if (day != details.data.day) {
                      if (kDebugMode) {
                        debugPrint(
                          '[Landscape] drop rejected (cross-day) dropDay=$day eventDay=${details.data.day}',
                        );
                      }
                      return;
                    }
                    int totalMin = ((y / _rowH) * 60).round();
                    totalMin = totalMin.clamp(0, 24 * 60 - 1).toInt();
                    int snapped = ((totalMin / 15).round() * 15)
                        .clamp(0, 24 * 60 - 1)
                        .toInt();
                    widget.onMoveEventTime?.call(
                      widget.kYear,
                      widget.kMonth,
                      day,
                      details.data.event,
                      snapped,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeader(int day, double colW) {
    // Check if this is today
    final now = DateTime.now();
    final today = KemeticMath.fromGregorian(now);
    final isToday =
        today.kYear == widget.kYear &&
        today.kMonth == widget.kMonth &&
        today.kDay == day;

    // Get Gregorian date
    // FIXED: Convert UTC result to local at noon to avoid DST issues
    final gregorianDate = safeLocalDisplay(
      KemeticMath.toGregorian(widget.kYear, widget.kMonth, day),
    );
    final primaryLabel = widget.showGregorian ? '${gregorianDate.day}' : '$day';
    final primaryColor = isToday
        ? _gold
        : (widget.showGregorian ? blueLight : Colors.white);

    return Container(
      width: colW,
      height: _headerH,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: isToday ? _gold.withValues(alpha: 0.1) : null,
        border: Border(
          right: const BorderSide(color: _divider, width: _daySepW),
          bottom: BorderSide(
            color: isToday ? _gold : _divider,
            width: isToday ? 2 : 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            primaryLabel,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
              color: primaryColor,
            ),
          ),
          if (widget.showGregorian)
            Text(
              '${gregorianDate.month}/${gregorianDate.day}',
              style: TextStyle(
                fontSize: 9,
                color: isToday
                    ? _gold.withValues(alpha: 0.7)
                    : blueLight.withValues(alpha: 0.8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGridLines(int dayCount, double colW) {
    return Stack(
      children: [
        // Horizontal hour lines
        for (int hour = 0; hour < 24; hour++)
          Positioned(
            left: 0,
            right: 0,
            top: hour * _rowH,
            child: Container(height: _hourSepH, color: _divider),
          ),

        // Vertical day lines
        for (int day = 0; day < dayCount; day++)
          Positioned(
            left: day * (colW + _daySepW) + colW,
            top: 0,
            bottom: 0,
            child: Container(width: _daySepW, color: _divider),
          ),
      ],
    );
  }

  /// Dedupe notes before rendering to handle legacy duplicates
  /// Two notes are duplicates if they have:
  /// - Same flow ID
  /// - Same start time (to the minute, or both all-day)
  /// - Same end time (to the minute, or both all-day)
  /// - Same title (normalized)
  List<NoteData> _dedupeNotesForUI(List<NoteData> notes) {
    if (notes.isEmpty) return notes;

    final seen = <String, NoteData>{};

    for (final note in notes) {
      // Build unique key from note properties
      final flowKey = note.flowId?.toString() ?? 'NO_FLOW';

      // Normalize timestamps (handle both all-day and timed events)
      String startKey;
      String endKey;

      if (note.allDay) {
        startKey = 'ALLDAY';
        endKey = 'ALLDAY';
      } else {
        // For timed events, normalize to minutes since midnight for comparison
        if (note.start != null && note.end != null) {
          final startMin = note.start!.hour * 60 + note.start!.minute;
          final endMin = note.end!.hour * 60 + note.end!.minute;
          startKey = startMin.toString();
          endKey = endMin.toString();
        } else {
          startKey = 'NO_START';
          endKey = 'NO_END';
        }
      }

      // Title normalized (trim + lowercase for consistency)
      final titleKey = note.title.trim().toLowerCase();

      // Build composite key
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

  EventItem _eventItemFromNote(NoteData note) {
    final startMin = note.allDay
        ? 9 * 60
        : (note.start?.hour ?? 9) * 60 + (note.start?.minute ?? 0);
    final endMin = note.allDay
        ? 17 * 60
        : (note.end?.hour ?? 17) * 60 + (note.end?.minute ?? 0);

    Color eventColor = Colors.blue;
    // Product rule: explicit per-event colors win; otherwise we fall back to
    // the owning flow's chrome color so historical/saved flow notes stay
    // visually attached to their source flow.
    if (note.manualColor != null) {
      eventColor = note.manualColor!;
    } else if (note.flowId != null) {
      final flow = _chromeFlowForId(note.flowId);
      if (flow != null) {
        eventColor = flow.color;
      }
    }

    return EventItem(
      id: note.id,
      clientEventId: note.clientEventId,
      calendarId: note.calendarId,
      calendarName: note.calendarName,
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

  FlowData? _chromeFlowForId(int? flowId) => widget.flowIndex[flowId];

  String _sheetEventIdentityKey(EventItem event) {
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

    return _sheetEventIdentityKey(a) == _sheetEventIdentityKey(b);
  }

  int _compareEventItemsBySchedule(EventItem a, EventItem b) {
    final startCmp = a.startMin.compareTo(b.startMin);
    if (startCmp != 0) return startCmp;

    final endCmp = a.endMin.compareTo(b.endMin);
    if (endCmp != 0) return endCmp;

    return _sheetEventIdentityKey(a).compareTo(_sheetEventIdentityKey(b));
  }

  List<EventItem> _eventsForKemeticDay(int ky, int km, int kd) {
    final notes = _dedupeNotesForUI(widget.notesForDay(ky, km, kd));
    final events = [for (final note in notes) _eventItemFromNote(note)];
    events.sort(_compareEventItemsBySchedule);
    return events;
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

  DayViewSheetEventTarget? _resolveAdjacentEventTarget({
    required int ky,
    required int km,
    required int kd,
    required EventItem event,
    required bool forward,
  }) {
    if (ky != widget.kYear || km != widget.kMonth) return null;

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

    final dayRange = forward
        ? Iterable<int>.generate(
            _getDaysInMonth() - kd,
            (index) => kd + index + 1,
          )
        : Iterable<int>.generate(kd - 1, (index) => kd - index - 1);

    for (final nextDay in dayRange) {
      final nextDayEvents = _eventsForKemeticDay(ky, km, nextDay);
      if (nextDayEvents.isEmpty) continue;
      return DayViewSheetEventTarget(
        ky: ky,
        km: km,
        kd: nextDay,
        event: forward ? nextDayEvents.first : nextDayEvents.last,
      );
    }

    return null;
  }

  List<Widget> _buildEventsForDay(int day, double colW) {
    final rawNotes = widget.notesForDay(widget.kYear, widget.kMonth, day);

    if (kDebugMode && rawNotes.isNotEmpty) {
      final flowIds =
          rawNotes.map((note) => note.flowId).whereType<int>().toSet().toList()
            ..sort();
      _logLandscape('📅 [LANDSCAPE] Building events for day $day');
      _logLandscape('   Year: ${widget.kYear}, Month: ${widget.kMonth}');
      _logLandscape('   Raw notes: ${rawNotes.length}');
      _logLandscape('   FlowIndex keys: ${widget.flowIndex.keys.toList()}');
      _logLandscape('   Flow ids: $flowIds');
    }

    // ✅ NEW: Dedupe notes before rendering to handle legacy duplicates
    final notes = _dedupeNotesForUI(rawNotes);

    if (kDebugMode && rawNotes.isNotEmpty && notes.isEmpty) {
      _logLandscape('⚠️ [LANDSCAPE] All notes deduped for day $day!');
    }
    if (notes.isEmpty) return [];

    if (kDebugMode) {
      final originalCount = rawNotes.length;
      final dedupedCount = notes.length;
      if (originalCount != dedupedCount) {
        _logLandscape(
          '[LandscapeMonthView] Deduplicated events for day $day: $originalCount → $dedupedCount (removed ${originalCount - dedupedCount} duplicates)',
        );
      }
    }

    final events = [for (final note in notes) _eventItemFromNote(note)];

    if (events.isEmpty) return [];

    events.sort(_compareEventItemsBySchedule);

    const columnGap = 4.0;
    final widgets = <Widget>[];

    // Cluster events by overlap so width is only reduced when events overlap in time
    int idx = 0;
    while (idx < events.length) {
      final cluster = <EventItem>[];
      int clusterEnd = events[idx].endMin;
      cluster.add(events[idx]);
      int j = idx + 1;
      while (j < events.length && events[j].startMin < clusterEnd) {
        cluster.add(events[j]);
        clusterEnd = math.max(clusterEnd, events[j].endMin);
        j++;
      }

      final columnAssignments = _assignColumns(cluster);
      final maxCols = columnAssignments.values.isEmpty
          ? 1
          : (columnAssignments.values.reduce((a, b) => a > b ? a : b) + 1);
      final availableWidth = colW - (columnGap * (maxCols - 1));
      final columnWidth = availableWidth / maxCols;

      for (final event in cluster) {
        final col = columnAssignments[event] ?? 0;
        final left =
            (day - 1) * (colW + _daySepW) + (col * (columnWidth + columnGap));
        final top = (event.startMin / 60.0) * _rowH;

        int durationMinutes = event.endMin - event.startMin;
        if (durationMinutes <= 0) {
          durationMinutes = 15;
        }
        if (durationMinutes > 180) {
          durationMinutes = 180;
        }
        final double rawHeight = (durationMinutes / 60.0) * _rowH;
        final double height = rawHeight < _kLandscapeEventMinHeight
            ? _kLandscapeEventMinHeight
            : rawHeight;

        widgets.add(
          Positioned(
            left: left,
            top: top,
            width: columnWidth,
            height: height,
            child: _buildInteractiveEventBlock(
              event: event,
              day: day,
              width: columnWidth,
              height: height,
              durationMinutes: durationMinutes,
            ),
          ),
        );
      }

      idx = j;
    }

    return widgets;
  }

  bool _isEventDraggable(EventItem event) {
    final flowId = event.flowId ?? -1;
    return (event.flowId == null || flowId == -1) &&
        !event.isReminder &&
        !event.allDay;
  }

  Widget _buildEventCard(EventItem event, int durationMinutes) {
    final flow = _chromeFlowForId(event.flowId);
    final isTrackSky = _isLandscapeTrackSkyFlowName(flow?.name);
    final trackSkySpec = isTrackSky
        ? _landscapeTrackSkySpecForEvent(event)
        : null;

    if (trackSkySpec != null) {
      final compact = durationMinutes < 90;
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 7,
          vertical: compact ? 5 : 6,
        ),
        decoration: BoxDecoration(
          gradient: trackSkySpec.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: trackSkySpec.borderColor.withValues(alpha: 0.92),
            width: 0.95,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.26),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: trackSkySpec.glowColor,
              blurRadius: compact ? 12 : 16,
              spreadRadius: -4,
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xB004060C),
                      const Color(0x7804060C),
                      const Color(0x1804060C),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.34, 0.62, 1.0],
                  ),
                ),
              ),
            ),
            ..._buildLandscapeTrackSkyStars(
              seed: event.title,
              tint: trackSkySpec.accentColor,
              compact: compact,
            ),
            Positioned(
              right: compact ? 6 : 8,
              top: compact ? 5 : 6,
              child: IgnorePointer(
                child: _buildLandscapeTrackSkyAccent(
                  trackSkySpec,
                  event.title,
                  compact: compact,
                ),
              ),
            ),
            Positioned.fill(
              child: _buildEventBlockContent(
                event,
                durationMinutes,
                trackSkySpec: trackSkySpec,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 4,
        vertical: event.isReminder ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: event.color.withValues(alpha: 0.20),
        border: Border(left: BorderSide(color: event.color, width: 3)),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.hardEdge,
      child: _buildEventBlockContent(event, durationMinutes),
    );
  }

  Widget _buildInteractiveEventBlock({
    required EventItem event,
    required int day,
    required double width,
    required double height,
    required int durationMinutes,
  }) {
    final card = _buildEventCard(event, durationMinutes);
    final tappable = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showEventDetail(event, day),
      child: SizedBox(width: width, height: height, child: card),
    );

    if (!_isEventDraggable(event)) {
      return tappable;
    }

    return LongPressDraggable<_LandscapeDragPayload>(
      data: _LandscapeDragPayload(event, day),
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.8,
          child: SizedBox(
            width: width,
            height: height,
            child: _buildEventCard(event, durationMinutes),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: SizedBox(
          width: width,
          height: height,
          child: _buildEventCard(event, durationMinutes),
        ),
      ),
      onDragStarted: () {
        unawaited(AppHaptics.selection());
      },
      onDraggableCanceled: (_, _) {},
      onDragEnd: (_) {},
      child: tappable,
    );
  }

  Widget _buildEventBlockContent(
    EventItem event,
    int durationMinutes, {
    _LandscapeTrackSkySpec? trackSkySpec,
  }) {
    final flow = _chromeFlowForId(event.flowId);
    final hasFlow = flow != null;
    final isTrackSky = trackSkySpec != null;

    final showTitle = event.title.trim().isNotEmpty;
    final showLocation =
        event.location != null && event.location!.trim().isNotEmpty;
    final titleColor = trackSkySpec?.titleColor ?? Colors.white;
    final flowColor = isTrackSky ? _landscapeGold : event.color;
    final secondaryTextColor = isTrackSky
        ? Colors.white.withValues(alpha: 0.82)
        : Colors.white.withValues(alpha: 0.7);
    final textShadows = isTrackSky
        ? <Shadow>[
            Shadow(
              color: Colors.black.withValues(alpha: 0.78),
              offset: const Offset(0, 1.0),
              blurRadius: 2.2,
            ),
            Shadow(
              color: trackSkySpec.glowColor.withValues(alpha: 0.46),
              offset: Offset.zero,
              blurRadius: 4.2,
            ),
          ]
        : null;

    Widget buildTrackSkyFlowNameText(String text) {
      const baseStyle = TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: Color(0xFFF1CF7A),
      );
      return GlossyText(
        text: text,
        style: baseStyle,
        gradient: _trackSkyFlowGoldGloss,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
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
              ? buildTrackSkyFlowNameText(flow.name)
              : Text(
                  flow.name,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: flowColor,
                    shadows: textShadows,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          const SizedBox(height: 2),
        ],

        // Note title - only render if meaningful
        if (showTitle)
          Text(
            event.title.trim(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500, // ✅ w500 not w600
              color: titleColor,
              shadows: textShadows,
            ),
            maxLines: (event.isReminder || hasFlow || durationMinutes < 90)
                ? 1
                : 2, // ✅ Conditional line limit
            overflow: TextOverflow.ellipsis,
          )
        else
          Text(
            // ✅ No const - text is conditional
            hasFlow ? '(flow block)' : '(scheduled)', // ✅ Match day view logic
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: titleColor.withValues(alpha: 0.82),
              fontStyle: FontStyle.italic,
              shadows: textShadows,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

        // Location (clickable)
        if (showLocation)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: InkWell(
              onTap: () => _launchLocation(event.location!.trim()),
              child: Text(
                event.location!.trim(),
                style: TextStyle(
                  fontSize: 10,
                  color: secondaryTextColor,
                  decoration: TextDecoration.underline,
                  shadows: textShadows,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
  }

  void _showEventDetail(
    EventItem event,
    int day, {
    DayViewSheetEventTarget? initialTarget,
  }) {
    if (!CalendarEventDetailSheetCoordinator.tryMarkOpenOrOpening()) {
      return;
    }
    final rootContext = context;
    final sheetTarget =
        initialTarget ??
        DayViewSheetEventTarget(
          ky: widget.kYear,
          km: widget.kMonth,
          kd: day,
          event: event,
        );
    _publishEventDetailRestorationTarget(sheetTarget);
    var sheetReleased = false;
    var activeTarget = sheetTarget;

    void moveToTarget(DayViewSheetEventTarget nextTarget) {
      if (!mounted) return;
      final previousTarget = activeTarget;
      activeTarget = nextTarget;
      _publishEventDetailRestorationTarget(nextTarget);
      if (nextTarget.kd != previousTarget.kd) {
        _scrollToDay(nextTarget.kd);
      }
    }

    void releaseSheet() {
      if (sheetReleased) return;
      sheetReleased = true;
      _clearEventDetailRestorationIfAllowed();
      CalendarEventDetailSheetCoordinator.markClosed();
    }

    try {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (sheetContext) => CalendarEventDetailSheet(
          hostContext: rootContext,
          initialTarget: sheetTarget,
          flowResolver: _chromeFlowForId,
          activeLedgerFlowIds: widget.activeLedgerFlowIds,
          resolveCurrentEventTarget: _resolveCurrentEventTarget,
          resolveAdjacentEventTarget: _resolveAdjacentEventTarget,
          onTargetChanged: moveToTarget,
          onManageFlows: widget.onManageFlows,
          onEditNote: widget.onEditNote,
          onDeleteNote: widget.onDeleteNote,
          onShareNote: widget.onShareNote,
          onEditReminder: widget.onEditReminder,
          onEndReminder: widget.onEndReminder,
          onShareReminder: widget.onShareReminder,
          onEndFlow: widget.onEndFlow,
          onAppendToJournal: widget.onAppendToJournal,
          onWriteJournalResponse: widget.onWriteJournalResponse,
          onSaveFlow: widget.onSaveFlow,
          dataVersion: widget.dataVersion,
          onRecordCompletion: widget.onRecordCompletion,
          onUnrecordCompletion: widget.onUnrecordCompletion,
          onRemoveCompletionBadge: widget.onRemoveCompletionBadge,
        ),
      ).whenComplete(releaseSheet);
    } catch (_) {
      releaseSheet();
      rethrow;
    }
  }

  Map<EventItem, int> _assignColumns(List<EventItem> events) {
    final assignments = <EventItem, int>{};
    final columnEndTimes = <int, int>{};

    for (final event in events) {
      int column = 0;
      while (columnEndTimes.containsKey(column) &&
          columnEndTimes[column]! > event.startMin) {
        column++;
      }

      assignments[event] = column;
      columnEndTimes[column] = event.endMin;
    }

    return assignments;
  }

  int _getDaysInMonth() {
    if (widget.kMonth == 13) {
      return KemeticMath.isLeapKemeticYear(widget.kYear) ? 6 : 5;
    }
    return 30;
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }

  /// Detect whether a string looks like a URL, email, or phone number.
  bool _isLikelyUrl(String text) {
    final lower = text.toLowerCase().trim();

    // Already has protocol
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return true;
    }

    // Email pattern (check early - most specific)
    if (RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(lower)) {
      return true;
    }

    // Phone number pattern (check for phone-like formatting)
    final phonePattern = RegExp(
      r'^[\+]?[(]?[0-9]{3}[)]?[-\s\.]?[0-9]{3}[-\s\.]?[0-9]{4,6}$',
    );
    final digitsOnly = lower.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    if (phonePattern.hasMatch(lower) ||
        (digitsOnly.length >= 10 &&
            digitsOnly.length <= 15 &&
            RegExp(r'^\+?[0-9]+$').hasMatch(digitsOnly))) {
      return true;
    }

    // Known service domains (most reliable)
    final knownServices = [
      r'zoom\.us',
      r'meet\.google\.com',
      r'youtube\.com',
      r'youtu\.be',
      r'facebook\.com',
      r'instagram\.com',
      r'twitter\.com',
      r'linkedin\.com',
      r'tiktok\.com',
      r'discord\.gg',
      r'slack\.com',
      r'teams\.microsoft\.com',
    ];

    for (final service in knownServices) {
      if (RegExp(service).hasMatch(lower)) {
        return true;
      }
    }

    // Generic domain pattern (but require at least one dot and TLD, no spaces)
    if (RegExp(
          r'^[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,}(/.*)?$',
        ).hasMatch(lower) &&
        lower.contains('.') &&
        !lower.contains(' ')) {
      // No spaces = likely URL, not address
      return true;
    }

    // www. prefix
    if (lower.startsWith('www.')) {
      return true;
    }

    return false;
  }

  /// Launch URL/email/phone, or treat as address and open in Maps.
  Future<void> _launchLocation(String raw) async {
    final loc = raw.trim();
    if (loc.isEmpty) return;

    Uri uri;

    if (_isLikelyUrl(loc)) {
      final lower = loc.toLowerCase();

      // Already a full URL
      if (lower.startsWith('http://') || lower.startsWith('https://')) {
        uri = Uri.parse(loc);
      }
      // Email
      else if (RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(lower)) {
        uri = Uri.parse('mailto:$loc');
      }
      // Phone
      else {
        final digitsOnly = lower.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
        final phonePattern = RegExp(r'^\+?[0-9]{7,15}$');
        if (phonePattern.hasMatch(digitsOnly)) {
          uri = Uri.parse('tel:$loc');
        } else {
          // Bare domain or known service → assume https
          uri = Uri.parse('https://$loc');
        }
      }
    } else {
      // Not URL/email/phone → treat as address (Maps)
      final q = Uri.encodeComponent(loc);
      uri = Uri.parse('https://maps.google.com/?q=$q');
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
