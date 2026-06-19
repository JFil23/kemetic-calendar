// lib/features/calendar/day_view.dart
//
// Day View - 24-hour timeline with pixel-perfect event layout
// Uses EventLayoutEngine for consistent positioning
//

import 'dart:async';
import 'dart:math' as math;
import 'package:mobile/core/navigation_fallback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/shared/glossy_text.dart';
import 'package:mobile/core/app_bottom_insets.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/core/touch_targets.dart';
import 'package:mobile/features/onboarding/daily_orientation_repo.dart';
import 'calendar_page.dart';
import 'calendar_completion.dart';
import 'calendar_reflection_context.dart';
import 'day_view_chrome.dart';
import 'landscape_month_view.dart';
import 'maat_flow_identity.dart';
import 'track_sky_flow.dart';
import 'dawn_house_rite_flow.dart';
import 'evening_threshold_flow.dart';
import 'evening_threshold_rite_flow.dart';
import 'the_weighing_flow.dart';
import 'the_offering_table_flow.dart';
import 'the_tending_flow.dart';
import 'the_tending_local_store.dart';
import 'the_kept_word_flow.dart';
import 'the_kept_word_local_store.dart';
import 'the_course_flow.dart';
import 'the_course_context.dart';
import 'moon_return_flow.dart';
import 'the_wag_flow.dart';
import 'the_wag_local_store.dart';
import 'the_decan_watch_flow.dart';
import 'the_decan_watch_local_store.dart';
import 'the_days_outside_year_flow.dart';
import 'the_days_outside_year_local_store.dart';
import 'the_open_hand_flow.dart';
import 'the_open_hand_local_store.dart';
import 'the_djed_flow.dart';
import 'the_djed_local_store.dart';
import 'maat_decan_flow.dart';
import 'living_text_day_one_node_store.dart';
import 'decan_id.dart';
import '../nodes/kemetic_node_search_delegate.dart';
import '../onboarding/day_view_date_coachmark.dart';
import 'package:mobile/features/onboarding/guided_onboarding_overlay.dart';
import '../../widgets/kemetic_day_info.dart';
import 'package:mobile/core/day_key.dart';
import 'package:mobile/telemetry/telemetry.dart';
import '../../data/user_events_repo.dart';
import '../../services/app_haptics.dart';
import '../../services/app_restoration_service.dart';
import '../../utils/external_link_utils.dart';
import '../../utils/flow_filter_engine.dart';

const double _kMinEventBlockHeight = 56.0;
const double _kTimelineLabelWidth = 60.0;
const double _kTimelineRightPadding = 16.0;
const double _kEventColumnGap = 4.0;
const double _kSingleEventWidthFactor = 0.8;
const double _kDayViewHourHeight = 60.0;
const double _kDayViewPixelsPerMinute = _kDayViewHourHeight / 60.0;
const Color _dayGold = KemeticGold.base;
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
const String _kNewEventPreviewClientEventId = '__day_view_new_event_preview__';
const ValueKey<String> _ritualCompletionFeedbackCardKey = ValueKey<String>(
  'day-view-ritual-completion-feedback-card',
);
const ValueKey<String> _ritualCompletionFeedbackRimKey = ValueKey<String>(
  'day-view-ritual-completion-feedback-rim',
);
typedef DayViewRestorationCallback =
    void Function({
      required int kYear,
      required int kMonth,
      required int kDay,
      required bool showGregorian,
      int? firstVisibleMinute,
      double? scrollOffset,
      EventDetailRestorationState? eventDetail,
    });

const TextStyle _goldHeaderStyle = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w600,
  fontFamily: 'GentiumPlus',
  fontFamilyFallback: ['NotoSans', 'Roboto', 'Arial', 'sans-serif'],
);

const String _dayViewSerifFamily = 'CormorantGaramond';
const List<String> _dayViewSerifFallback = [
  'GentiumPlus',
  'NotoSerif',
  'Georgia',
  'serif',
];
const List<String> _dayViewSansFallback = [
  'NotoSans',
  'Roboto',
  'Arial',
  'sans-serif',
];
const Color _dayViewInk = Color(0xFFF2E4C6);
const Color _dayViewSilver = Color(0xFF9B9182);
const Color _dayViewSilverDim = Color(0xFF776B58);
const Color _dayViewBase = Color(0xFF060504);
const Color _dayViewCopperAccent = Color(0xFFC06E4D);
const Color _dayViewWarmStone = Color(0xFFB8AA9A);
const Color _dayViewBronzeLabel = Color(0xFFAA894F);

Color _dayViewMix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

Color _dayViewReadableFlowColor(Color color) {
  final luminance = color.computeLuminance();
  if (luminance < 0.18) {
    return _dayViewMix(color, Colors.white, 0.42);
  }
  if (luminance > 0.68) {
    return _dayViewMix(color, _dayGold, 0.22);
  }
  return color;
}

bool _dayViewIsRedOrangeMaterialColor(Color color) {
  final hue = HSLColor.fromColor(color).hue;
  return hue <= 32 || hue >= 342;
}

bool _dayViewIsBlueMaterialColor(Color color) {
  final hue = HSLColor.fromColor(color).hue;
  return hue >= 175 && hue <= 265;
}

bool _dayViewIsGreenMaterialColor(Color color) {
  final hue = HSLColor.fromColor(color).hue;
  return hue > 72 && hue <= 165;
}

Color _dayViewSoftenedAccent(Color color) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withSaturation((hsl.saturation * 0.52).clamp(0.0, 0.50).toDouble())
      .withLightness(0.49)
      .toColor();
}

Color _dayViewMaterialFlowColor(Color color) {
  final readable = _dayViewReadableFlowColor(color);
  final hue = HSLColor.fromColor(readable).hue;
  if (hue <= 28 || hue >= 342) return _dayViewCopperAccent;
  if (hue > 28 && hue <= 72) {
    return _dayViewMix(readable, const Color(0xFFC98A5B), 0.5);
  }
  return readable;
}

String _dayViewCategoryLabel(String text, {bool sparkle = false}) {
  final compact = text.trim().isEmpty ? 'Scheduled' : text.trim();
  final label = compact.toUpperCase();
  return sparkle ? '✦ $label' : label;
}

class _DayViewEventVisual {
  const _DayViewEventVisual({
    required this.source,
    required this.base,
    required this.wash,
    required this.washLeft,
    required this.washMid,
    required this.washEnd,
    required this.stripe,
    required this.border,
    required this.category,
    required this.title,
    required this.metaText,
    required this.supportText,
    required this.sectionLabelText,
    required this.bodyText,
    required this.metaFill,
    required this.metaBorder,
    required this.actionButtonFill,
    required this.actionButtonBorder,
    required this.actionButtonText,
    required this.actionIconFill,
    required this.actionIconGlyph,
    required this.completionPanelFill,
    required this.completionPanelBorder,
    required this.completionButtonFill,
    required this.completionButtonBorder,
    required this.completionButtonText,
    required this.completionButtonSelectedFill,
    required this.completionButtonSelectedBorder,
    required this.completionButtonSelectedText,
  });

  final Color source;
  final Color base;
  final Color wash;
  final Color washLeft;
  final Color washMid;
  final Color washEnd;
  final Color stripe;
  final Color border;
  final Color category;
  final Color title;
  final Color metaText;
  final Color supportText;
  final Color sectionLabelText;
  final Color bodyText;
  final Color metaFill;
  final Color metaBorder;
  final Color actionButtonFill;
  final Color actionButtonBorder;
  final Color actionButtonText;
  final Color actionIconFill;
  final Color actionIconGlyph;
  final Color completionPanelFill;
  final Color completionPanelBorder;
  final Color completionButtonFill;
  final Color completionButtonBorder;
  final Color completionButtonText;
  final Color completionButtonSelectedFill;
  final Color completionButtonSelectedBorder;
  final Color completionButtonSelectedText;
}

class _DayViewExternalAction {
  const _DayViewExternalAction({
    required this.label,
    required this.target,
    required this.icon,
    required this.fallbackToMaps,
  });

  final String label;
  final String target;
  final IconData icon;
  final bool fallbackToMaps;
}

_DayViewEventVisual _dayViewVisualForEvent(
  EventItem event,
  FlowData? flow, {
  bool isReminder = false,
  bool isNutrition = false,
}) {
  final rawSource = _dayViewReadableFlowColor(
    isReminder
        ? const Color(0xFF5CAA5F)
        : isNutrition
        ? const Color(0xFF57A9D6)
        : event.color,
  );
  final source = isReminder || isNutrition
      ? rawSource
      : _dayViewMaterialFlowColor(rawSource);
  final redOrange = _dayViewIsRedOrangeMaterialColor(source);

  if (redOrange && !isReminder && !isNutrition) {
    const accent = Color(0xFFC2673F);
    return _DayViewEventVisual(
      source: accent,
      base: const Color(0xFF190C08),
      wash: const Color(0xFF542516),
      washLeft: const Color(0xFF542516),
      washMid: const Color(0xFF2F150D),
      washEnd: const Color(0xFF150A07),
      stripe: accent.withValues(alpha: 0.65),
      border: const Color(0xFFC4754C).withValues(alpha: 0.24),
      category: const Color(0xFFC0774B),
      title: const Color(0xFFDCA66E),
      metaText: const Color(0xFFB47A4D),
      supportText: const Color(0xFFA97855),
      sectionLabelText: const Color(0xFFA88749),
      bodyText: const Color(0xFFBDAEA2),
      metaFill: accent.withValues(alpha: 0.10),
      metaBorder: accent.withValues(alpha: 0.22),
      actionButtonFill: const Color(0xFF2B150E),
      actionButtonBorder: const Color(0xFFC06E4D).withValues(alpha: 0.32),
      actionButtonText: const Color(0xFFDCA66E),
      actionIconFill: const Color(0xFFC06E4D).withValues(alpha: 0.28),
      actionIconGlyph: const Color(0xFFE2AE78),
      completionPanelFill: const Color(0xFF130907),
      completionPanelBorder: const Color(0xFFC06E4D).withValues(alpha: 0.20),
      completionButtonFill: const Color(0xFF090604),
      completionButtonBorder: const Color(0xFF5A3A23).withValues(alpha: 0.54),
      completionButtonText: const Color(0xFFA98E66),
      completionButtonSelectedFill: const Color(0xFF311911),
      completionButtonSelectedBorder: const Color(
        0xFFC98A5B,
      ).withValues(alpha: 0.34),
      completionButtonSelectedText: const Color(0xFFDDAE76),
    );
  }

  final softened = _dayViewSoftenedAccent(source);
  final hue = HSLColor.fromColor(softened).hue;
  final isBlue = _dayViewIsBlueMaterialColor(softened);
  final isGreen = _dayViewIsGreenMaterialColor(softened);
  final isGold = hue > 32 && hue <= 72;
  final base = isBlue
      ? const Color(0xFF0F1723)
      : isGreen
      ? const Color(0xFF09170D)
      : isGold
      ? const Color(0xFF171108)
      : Color.alphaBlend(
          softened.withValues(alpha: 0.13),
          const Color(0xFF090604),
        );
  final title = isBlue
      ? _dayViewMix(softened, const Color(0xFF87C0EA), 0.58)
      : isGreen
      ? _dayViewMix(softened, const Color(0xFF9BD9A8), 0.46)
      : isGold
      ? _dayViewMix(softened, const Color(0xFFD7B45E), 0.47)
      : _dayViewMix(softened, const Color(0xFFE2C58C), 0.22);
  final category = _dayViewMix(softened, _dayViewInk, 0.14);
  final metaText = _dayViewMix(softened, _dayViewSilver, 0.28);
  final supportText = _dayViewMix(softened, const Color(0xFF9A7E64), 0.38);

  return _DayViewEventVisual(
    source: softened,
    base: base,
    wash: softened,
    washLeft: softened,
    washMid: _dayViewMix(softened, base, 0.42),
    washEnd: base,
    stripe: softened.withValues(alpha: isReminder ? 0.62 : 0.66),
    border: softened.withValues(alpha: 0.24),
    category: category.withValues(alpha: 0.88),
    title: title,
    metaText: metaText.withValues(alpha: 0.88),
    supportText: supportText.withValues(alpha: 0.88),
    sectionLabelText: const Color(0xFFA88749),
    bodyText: const Color(0xFFBDAEA2),
    metaFill: softened.withValues(alpha: 0.10),
    metaBorder: softened.withValues(alpha: 0.22),
    actionButtonFill: Color.alphaBlend(
      softened.withValues(alpha: 0.11),
      const Color(0xFF090604),
    ),
    actionButtonBorder: softened.withValues(alpha: 0.29),
    actionButtonText: title.withValues(alpha: 0.96),
    actionIconFill: softened.withValues(alpha: 0.24),
    actionIconGlyph: title.withValues(alpha: 0.94),
    completionPanelFill: Color.alphaBlend(
      softened.withValues(alpha: 0.05),
      const Color(0xFF080604),
    ),
    completionPanelBorder: softened.withValues(alpha: 0.18),
    completionButtonFill: const Color(0xFF090604),
    completionButtonBorder: const Color(0xFF5A3A23).withValues(alpha: 0.54),
    completionButtonText: const Color(0xFFA98E66),
    completionButtonSelectedFill: Color.alphaBlend(
      softened.withValues(alpha: 0.17),
      const Color(0xFF060504),
    ),
    completionButtonSelectedBorder: softened.withValues(alpha: 0.34),
    completionButtonSelectedText: title.withValues(alpha: 0.93),
  );
}

Color _dayViewMatteDetailColor(
  Color color, {
  double saturationScale = 0.90,
  double liftAmount = 0.07,
}) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withSaturation(
        (hsl.saturation * saturationScale).clamp(0.0, 1.0).toDouble(),
      )
      .withLightness(
        (hsl.lightness + ((1.0 - hsl.lightness) * liftAmount))
            .clamp(0.0, 1.0)
            .toDouble(),
      )
      .toColor();
}

_DayViewEventVisual _dayViewMatteDetailVisual(_DayViewEventVisual visual) {
  Color matte(
    Color color, {
    double saturationScale = 0.90,
    double liftAmount = 0.07,
  }) {
    return _dayViewMatteDetailColor(
      color,
      saturationScale: saturationScale,
      liftAmount: liftAmount,
    );
  }

  return _DayViewEventVisual(
    source: matte(visual.source),
    base: matte(visual.base, liftAmount: 0.045),
    wash: matte(visual.wash),
    washLeft: matte(visual.washLeft),
    washMid: matte(visual.washMid, liftAmount: 0.060),
    washEnd: matte(visual.washEnd, liftAmount: 0.045),
    stripe: matte(visual.stripe),
    border: matte(visual.border),
    category: matte(visual.category),
    title: matte(visual.title),
    metaText: matte(visual.metaText),
    supportText: matte(visual.supportText),
    sectionLabelText: matte(visual.sectionLabelText),
    bodyText: matte(visual.bodyText, saturationScale: 0.86, liftAmount: 0.080),
    metaFill: matte(visual.metaFill, liftAmount: 0.060),
    metaBorder: matte(visual.metaBorder),
    actionButtonFill: matte(visual.actionButtonFill, liftAmount: 0.060),
    actionButtonBorder: matte(visual.actionButtonBorder),
    actionButtonText: matte(visual.actionButtonText),
    actionIconFill: matte(visual.actionIconFill),
    actionIconGlyph: matte(visual.actionIconGlyph),
    completionPanelFill: matte(visual.completionPanelFill, liftAmount: 0.050),
    completionPanelBorder: matte(visual.completionPanelBorder),
    completionButtonFill: matte(visual.completionButtonFill, liftAmount: 0.045),
    completionButtonBorder: matte(visual.completionButtonBorder),
    completionButtonText: matte(visual.completionButtonText),
    completionButtonSelectedFill: matte(
      visual.completionButtonSelectedFill,
      liftAmount: 0.060,
    ),
    completionButtonSelectedBorder: matte(
      visual.completionButtonSelectedBorder,
    ),
    completionButtonSelectedText: matte(visual.completionButtonSelectedText),
  );
}

String _dayViewFlowLabel(
  EventItem event,
  FlowData? flow, {
  required bool isMaatFlow,
  bool isReminder = false,
  bool isNutrition = false,
}) {
  if (flow != null) {
    return _dayViewCategoryLabel(flow.name, sparkle: isMaatFlow);
  }
  if (isReminder) return _dayViewCategoryLabel('Reminder');
  if (isNutrition) return _dayViewCategoryLabel('Nutrition');
  final category = event.category?.trim();
  if (category != null && category.isNotEmpty) {
    return _dayViewCategoryLabel(category);
  }
  return _dayViewCategoryLabel('Scheduled');
}

String _dayViewTimelineFlowLabel(
  EventItem event,
  FlowData? flow, {
  required bool isMaatFlow,
  bool isReminder = false,
  bool isNutrition = false,
}) {
  if (isReminder) {
    return _dayViewFlowLabel(
      event,
      flow,
      isMaatFlow: isMaatFlow,
      isReminder: true,
      isNutrition: isNutrition,
    );
  }
  final category = event.category?.trim();
  if (category != null && category.isNotEmpty) {
    return _dayViewCategoryLabel(category, sparkle: isMaatFlow);
  }
  return _dayViewFlowLabel(
    event,
    flow,
    isMaatFlow: isMaatFlow,
    isReminder: isReminder,
    isNutrition: isNutrition,
  );
}

const Set<String> _dayViewExternalPayloadKeys = {
  'url',
  'uri',
  'href',
  'link',
  'external_url',
  'externalurl',
  'external_link',
  'externallink',
  'action_url',
  'actionurl',
  'meeting_url',
  'meetingurl',
  'video_url',
  'videourl',
  'watch_url',
  'watchurl',
  'document_url',
  'documenturl',
  'map_url',
  'mapurl',
};

void _dayViewCollectPayloadTargets(
  Object? node,
  List<String> targets, [
  int depth = 0,
]) {
  if (node == null || depth > 4) return;
  if (node is Map) {
    for (final entry in node.entries) {
      final key = entry.key.toString().trim().toLowerCase();
      final normalizedKey = key.replaceAll(RegExp(r'[\s-]'), '_');
      final compactKey = normalizedKey.replaceAll('_', '');
      final value = entry.value;
      final isTargetKey =
          _dayViewExternalPayloadKeys.contains(normalizedKey) ||
          _dayViewExternalPayloadKeys.contains(compactKey);
      if (isTargetKey) {
        if (value is String) {
          targets.add(value);
        } else if (value is Iterable) {
          for (final item in value) {
            if (item is String) targets.add(item);
          }
        }
      }
      if (value is Map || value is Iterable) {
        _dayViewCollectPayloadTargets(value, targets, depth + 1);
      }
    }
  } else if (node is Iterable) {
    for (final item in node) {
      _dayViewCollectPayloadTargets(item, targets, depth + 1);
    }
  }
}

String _dayViewExternalActionLabel(Uri uri, {required bool fallbackToMaps}) {
  final scheme = uri.scheme.toLowerCase();
  final host = uri.host.toLowerCase();
  if (scheme == 'mailto') return 'Email';
  if (scheme == 'tel') return 'Call';
  if (host.contains('youtube.com') || host.contains('youtu.be')) {
    return 'Watch on YouTube';
  }
  if (host.contains('zoom.us') ||
      host.contains('meet.google') ||
      host.contains('teams.microsoft')) {
    return 'Join meeting';
  }
  if (fallbackToMaps ||
      host.contains('maps.google') ||
      host.contains('apple.com/maps')) {
    return 'Open map';
  }
  if (host.contains('docs.google') ||
      host.contains('notion.') ||
      uri.path.toLowerCase().endsWith('.pdf')) {
    return 'Open document';
  }
  return 'Open link';
}

IconData _dayViewExternalActionIcon(Uri uri, {required bool fallbackToMaps}) {
  final scheme = uri.scheme.toLowerCase();
  final host = uri.host.toLowerCase();
  if (scheme == 'mailto') return Icons.mail_outline_rounded;
  if (scheme == 'tel') return Icons.call_outlined;
  if (host.contains('youtube.com') || host.contains('youtu.be')) {
    return Icons.play_arrow_rounded;
  }
  if (host.contains('zoom.us') ||
      host.contains('meet.google') ||
      host.contains('teams.microsoft')) {
    return Icons.videocam_outlined;
  }
  if (fallbackToMaps ||
      host.contains('maps.google') ||
      host.contains('apple.com/maps')) {
    return Icons.map_outlined;
  }
  if (host.contains('docs.google') ||
      host.contains('notion.') ||
      uri.path.toLowerCase().endsWith('.pdf')) {
    return Icons.description_outlined;
  }
  return Icons.open_in_new_rounded;
}

_DayViewExternalAction? _dayViewExternalActionForRaw(
  String raw, {
  bool fallbackToMaps = false,
}) {
  final target = normalizeExternalLinkToken(raw);
  if (target.isEmpty) return null;
  final uri = buildExternalLaunchUri(target, fallbackToMaps: fallbackToMaps);
  if (uri == null) return null;
  return _DayViewExternalAction(
    label: _dayViewExternalActionLabel(uri, fallbackToMaps: fallbackToMaps),
    target: target,
    icon: _dayViewExternalActionIcon(uri, fallbackToMaps: fallbackToMaps),
    fallbackToMaps: fallbackToMaps,
  );
}

_DayViewExternalAction? _dayViewExternalActionForEvent(EventItem event) {
  final structuredTargets = <String>[];
  _dayViewCollectPayloadTargets(event.behaviorPayload, structuredTargets);
  for (final raw in structuredTargets) {
    final action = _dayViewExternalActionForRaw(raw);
    if (action != null) return action;
  }

  final detail = event.detail;
  if (detail != null && detail.trim().isNotEmpty) {
    for (final match in externalLinkPattern.allMatches(detail)) {
      final raw = match.group(0);
      if (raw == null || !looksLikeLaunchTarget(raw)) continue;
      final action = _dayViewExternalActionForRaw(raw);
      if (action != null) return action;
    }
  }

  final location = event.location?.trim();
  if (location != null && location.isNotEmpty) {
    return _dayViewExternalActionForRaw(location, fallbackToMaps: true);
  }

  return null;
}

bool _dayViewShouldShowDetailLocation(
  EventItem event,
  _DayViewExternalAction? action,
) {
  final location = event.location?.trim();
  if (location == null || location.isEmpty) return false;
  if (action == null) return true;
  final normalized = normalizeExternalLinkToken(location);
  if (normalized.isNotEmpty && normalized == action.target) return false;
  return !looksLikeLaunchTarget(location);
}

bool _dayViewIsStandaloneExternalTargetLine(
  String line,
  _DayViewExternalAction action,
) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return false;
  final matches = externalLinkPattern.allMatches(trimmed).toList();
  if (matches.length != 1) return false;
  final raw = matches.single.group(0);
  if (raw == null || !looksLikeLaunchTarget(raw)) return false;
  final normalized = normalizeExternalLinkToken(raw);
  if (normalized.isEmpty || normalized != action.target) return false;
  final remainder = trimmed.replaceFirst(raw, '').trim();
  return remainder.isEmpty || RegExp(r'^[\)\]\}\.,;:!?]+$').hasMatch(remainder);
}

String _dayViewStripStandaloneExternalTargetLines(
  String text,
  _DayViewExternalAction? action,
) {
  if (action == null || text.trim().isEmpty) return text;
  final kept = text
      .split('\n')
      .where((line) => !_dayViewIsStandaloneExternalTargetLine(line, action))
      .toList();
  return kept.join('\n').trim();
}

CalendarCompletionPickerStyle _dayViewCompletionPickerStyle(
  _DayViewEventVisual visual,
) {
  return CalendarCompletionPickerStyle(
    containerPadding: const EdgeInsets.all(10),
    containerColor: visual.completionPanelFill,
    containerBorderColor: visual.completionPanelBorder,
    containerBorderWidth: 0.5,
    containerRadius: 8,
    label: 'COMPLETION',
    labelColor: visual.category.withValues(alpha: 0.82),
    labelFontSize: 9,
    labelFontWeight: FontWeight.w600,
    labelLetterSpacing: 2.0,
    labelGap: 8,
    buttonGap: 8,
    selectedForegroundColor: visual.completionButtonSelectedText,
    selectedBackgroundColor: visual.completionButtonSelectedFill,
    selectedBorderColor: visual.completionButtonSelectedBorder,
    unselectedForegroundColor: visual.completionButtonText,
    unselectedBackgroundColor: visual.completionButtonFill,
    unselectedBorderColor: visual.completionButtonBorder,
    buttonPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    buttonRadius: 8,
    buttonBorderWidth: 0.5,
    buttonFontSize: 14,
    buttonFontWeight: FontWeight.w500,
    buttonFontFamily: _dayViewSerifFamily,
    buttonFontFamilyFallback: _dayViewSerifFallback,
    buttonMinimumSize: const Size(0, 40),
    buttonTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    buttonVisualDensity: const VisualDensity(horizontal: -1, vertical: -1),
  );
}

enum _RitualCompletionFeedbackLevel { observed, partial }

_RitualCompletionFeedbackLevel? _ritualFeedbackLevelForStatus(
  CompletionStatus status,
) {
  return switch (status) {
    CompletionStatus.observed => _RitualCompletionFeedbackLevel.observed,
    CompletionStatus.partial => _RitualCompletionFeedbackLevel.partial,
    CompletionStatus.none || CompletionStatus.skipped => null,
  };
}

Future<void> _triggerRitualCompletionHaptic(
  _RitualCompletionFeedbackLevel level,
) async {
  switch (level) {
    case _RitualCompletionFeedbackLevel.observed:
      await AppHaptics.mediumImpact(reason: 'flow_completion_observed');
      return;
    case _RitualCompletionFeedbackLevel.partial:
      await AppHaptics.lightImpact(reason: 'flow_completion_partial');
      return;
  }
}

void _playRitualCompletionFeedback(
  BuildContext context,
  CompletionStatus status,
) {
  final level = _ritualFeedbackLevelForStatus(status);
  if (level == null) return;
  _RitualCompletionFeedbackScope.maybeControllerOf(context)?.play(level);
}

void playDayViewRitualCompletionFeedback(
  BuildContext context,
  CompletionStatus status,
) {
  _playRitualCompletionFeedback(context, status);
}

class _RitualCompletionFeedbackController extends ChangeNotifier {
  _RitualCompletionFeedbackController({required this.triggerHaptic});

  final Future<void> Function(_RitualCompletionFeedbackLevel level)
  triggerHaptic;

  _RitualCompletionFeedbackLevel? _latestLevel;

  _RitualCompletionFeedbackLevel? get latestLevel => _latestLevel;

  void play(_RitualCompletionFeedbackLevel level) {
    _latestLevel = level;
    unawaited(triggerHaptic(level));
    notifyListeners();
  }
}

class _RitualCompletionFeedbackScope extends InheritedWidget {
  const _RitualCompletionFeedbackScope({
    required this.controller,
    required super.child,
  });

  final _RitualCompletionFeedbackController controller;

  static _RitualCompletionFeedbackController? maybeControllerOf(
    BuildContext context,
  ) {
    return context
        .getInheritedWidgetOfExactType<_RitualCompletionFeedbackScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(_RitualCompletionFeedbackScope oldWidget) {
    return controller != oldWidget.controller;
  }
}

class _RitualCompletionRimPainter extends CustomPainter {
  const _RitualCompletionRimPainter({
    required this.level,
    required this.intensity,
    required this.progress,
  });

  final _RitualCompletionFeedbackLevel level;
  final double intensity;
  final double progress;

  bool get _observed => level == _RitualCompletionFeedbackLevel.observed;

  double get rimIntensity =>
      (intensity.clamp(0.0, 1.0) * (_observed ? 1 : 0.5)).toDouble();

  double get fillAlpha => 0;

  double get gleamOpacity =>
      ((_observed ? 0.34 : 0.14) * intensity.clamp(0.0, 1.0)).toDouble();

  @override
  void paint(Canvas canvas, Size size) {
    final pulse = intensity.clamp(0.0, 1.0).toDouble();
    if (pulse <= 0.001 || size.isEmpty) return;

    final observed = _observed;
    final strength = observed ? 1.0 : 0.5;
    final rim = pulse * strength;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.75),
      const Radius.circular(12.5),
    );
    final glowColor = _dayGold.withValues(
      alpha: (observed ? 0.20 : 0.08) * pulse,
    );
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = observed ? 3.8 : 2.4
      ..strokeJoin = StrokeJoin.round
      ..color = glowColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, observed ? 5.5 : 3.0);
    canvas.drawRRect(rrect, glowPaint);

    final rimColor =
        Color.lerp(
          _dayGold,
          const Color(0xFFFFF1BF),
          observed ? rim * 0.55 : rim * 0.32,
        ) ??
        _dayGold;
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 + (observed ? 0.75 : 0.32) * pulse
      ..strokeJoin = StrokeJoin.round
      ..color = rimColor.withValues(
        alpha: (0.42 + (observed ? 0.34 : 0.15) * pulse).clamp(0.0, 0.82),
      );
    canvas.drawRRect(rrect, rimPaint);

    final gleamAlpha = gleamOpacity;
    if (gleamAlpha <= 0.001) return;

    final gleamPath = Path();
    final rimPath = Path()..addRRect(rrect.deflate(0.25));
    final pathProgress = progress.clamp(0.0, 1.0).toDouble();
    final span = observed ? 0.14 : 0.08;
    final startFraction = 0.02 + pathProgress * (observed ? 0.58 : 0.42);
    var hasGleam = false;
    for (final metric in rimPath.computeMetrics()) {
      final start = metric.length * startFraction;
      final end = math.min(metric.length, start + metric.length * span);
      if (end > start) {
        gleamPath.addPath(metric.extractPath(start, end), Offset.zero);
        hasGleam = true;
      }
    }

    if (!hasGleam) return;
    final gleamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = observed ? 2.2 : 1.35
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFFFF7D8).withValues(alpha: gleamAlpha);
    canvas.drawPath(gleamPath, gleamPaint);
  }

  @override
  bool shouldRepaint(covariant _RitualCompletionRimPainter oldDelegate) {
    return oldDelegate.level != level ||
        oldDelegate.intensity != intensity ||
        oldDelegate.progress != progress;
  }

  @override
  String toString() {
    final mode = switch (level) {
      _RitualCompletionFeedbackLevel.observed => 'observed',
      _RitualCompletionFeedbackLevel.partial => 'partial',
    };
    return 'RitualCompletionRimPainter('
        'mode: $mode, '
        'rimIntensity: ${rimIntensity.toStringAsFixed(3)}, '
        'gleamOpacity: ${gleamOpacity.toStringAsFixed(3)}, '
        'fillAlpha: ${fillAlpha.toStringAsFixed(3)}, '
        'paintsFill: false'
        ')';
  }
}

class _RitualCompletionFeedbackCard extends StatefulWidget {
  const _RitualCompletionFeedbackCard({
    required this.enabled,
    required this.child,
    this.visual,
  });

  final bool enabled;
  final Widget child;
  final _DayViewEventVisual? visual;

  @override
  State<_RitualCompletionFeedbackCard> createState() =>
      _RitualCompletionFeedbackCardState();
}

class _RitualCompletionFeedbackCardState
    extends State<_RitualCompletionFeedbackCard>
    with SingleTickerProviderStateMixin {
  late final _RitualCompletionFeedbackController _feedbackController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;
  _RitualCompletionFeedbackLevel _activeLevel =
      _RitualCompletionFeedbackLevel.observed;

  @override
  void initState() {
    super.initState();
    _feedbackController = _RitualCompletionFeedbackController(
      triggerHaptic: _triggerRitualCompletionHaptic,
    )..addListener(_handleFeedback);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 640),
    );
    _pulse = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 38,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 62,
      ),
    ]).animate(_pulseController);
  }

  @override
  void dispose() {
    _feedbackController.removeListener(_handleFeedback);
    _feedbackController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleFeedback() {
    final level = _feedbackController.latestLevel;
    if (level == null) return;
    setState(() => _activeLevel = level);
    _pulseController.forward(from: 0);
  }

  BoxDecoration _baseDecoration() {
    final visual = widget.visual;
    if (visual != null) {
      return BoxDecoration(
        color: visual.base,
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            visual.washLeft.withValues(alpha: 0.40),
            visual.washMid.withValues(alpha: 0.34),
            visual.washMid.withValues(alpha: 0.29),
            visual.washMid.withValues(alpha: 0.25),
          ],
          stops: const [0.0, 0.48, 0.82, 1.0],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: visual.border, width: 0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.46),
            blurRadius: 22,
            spreadRadius: -2,
            offset: const Offset(0, 12),
          ),
        ],
      );
    }
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _dayGold.withValues(alpha: 0.4)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 18,
          spreadRadius: 1,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final visual = widget.visual;
    final baseCard = Container(
      key: _ritualCompletionFeedbackCardKey,
      width: double.infinity,
      padding: visual == null
          ? const EdgeInsets.fromLTRB(18, 18, 18, 20)
          : const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: _baseDecoration(),
      clipBehavior: Clip.hardEdge,
      child: widget.child,
    );
    final card = AnimatedBuilder(
      animation: _pulseController,
      child: baseCard,
      builder: (context, child) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child ?? const SizedBox.shrink(),
            if (visual != null)
              Positioned(
                left: 4,
                top: 3,
                bottom: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: visual.stripe,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(9),
                    ),
                  ),
                  child: const SizedBox(width: 2.5),
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  key: _ritualCompletionFeedbackRimKey,
                  painter: _RitualCompletionRimPainter(
                    level: _activeLevel,
                    intensity: widget.enabled ? _pulse.value : 0,
                    progress: _pulseController.value,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (!widget.enabled) return card;
    return _RitualCompletionFeedbackScope(
      controller: _feedbackController,
      child: card,
    );
  }
}

class DayViewRitualCompletionFeedbackCard extends StatelessWidget {
  const DayViewRitualCompletionFeedbackCard({
    super.key,
    required this.enabled,
    required this.child,
  }) : _visual = null;

  const DayViewRitualCompletionFeedbackCard._withVisual({
    required this.enabled,
    required this.child,
    required _DayViewEventVisual visual,
  }) : _visual = visual;

  final bool enabled;
  final Widget child;
  final _DayViewEventVisual? _visual;

  @override
  Widget build(BuildContext context) {
    return _RitualCompletionFeedbackCard(
      enabled: enabled,
      visual: _visual,
      child: child,
    );
  }
}

bool _isTrackSkyFlowName(String? name) {
  final normalized = name?.trim().toLowerCase();
  return normalized == 'follow the sky' || normalized == 'track the sky';
}

bool _isDawnHouseRiteFlowName(String? name) {
  return name?.trim().toLowerCase() == kDawnHouseRiteTitle.toLowerCase();
}

bool _isEveningThresholdFlowName(String? name) {
  return name?.trim().toLowerCase() == kEveningThresholdTitle.toLowerCase();
}

bool _isEveningThresholdRiteFlowName(String? name) {
  return name?.trim().toLowerCase() == kEveningThresholdRiteTitle.toLowerCase();
}

bool _isTheWeighingFlowName(String? name) {
  return name?.trim().toLowerCase() == kTheWeighingTitle.toLowerCase();
}

bool _isOfferingTableFlowName(String? name) {
  return name?.trim().toLowerCase() == kOfferingTableTitle.toLowerCase();
}

bool _isTheTendingFlowName(String? name) {
  return name?.trim().toLowerCase() == kTheTendingTitle.toLowerCase();
}

bool _isKeptWordFlowName(String? name) {
  return name?.trim().toLowerCase() == kKeptWordTitle.toLowerCase();
}

bool _isTheCourseFlowName(String? name) {
  return name?.trim().toLowerCase() == kTheCourseTitle.toLowerCase();
}

bool _isMoonReturnFlowName(String? name) {
  return name?.trim().toLowerCase() == kMoonReturnTitle.toLowerCase();
}

bool _isTheWagFlowName(String? name) {
  return name?.trim().toLowerCase() == kTheWagTitle.toLowerCase();
}

bool _isDecanWatchFlowName(String? name) {
  return name?.trim().toLowerCase() == kDecanWatchTitle.toLowerCase();
}

bool _isDaysOutsideYearFlowName(String? name) {
  return name?.trim().toLowerCase() == kDaysOutsideTheYearTitle.toLowerCase();
}

bool _isOpenHandFlowName(String? name) {
  return name?.trim().toLowerCase() == kTheOpenHandTitle.toLowerCase();
}

bool _isDjedFlowName(String? name) {
  return name?.trim().toLowerCase() == kTheDjedTitle.toLowerCase();
}

class _MaatFlowCompletionContext {
  const _MaatFlowCompletionContext({
    required this.flowKey,
    required this.flowTitle,
    required this.eventTitle,
    required this.graphNodeSlugs,
    this.eventCategory,
    this.eventNumber,
    this.dayNumber,
    this.flowDay,
    this.sharePromptOnComplete = false,
    this.shareButtonLabel = 'Share what went well',
    this.extraStatusLabels = const <String, String>{},
    this.customStatusLabels = const <String, String>{},
    this.customStatusesOnly = false,
    this.showPartly = true,
  });

  final String flowKey;
  final String flowTitle;
  final String eventTitle;
  final String? eventCategory;
  final int? eventNumber;
  final int? dayNumber;
  final int? flowDay;
  final List<String> graphNodeSlugs;
  final bool sharePromptOnComplete;
  final String shareButtonLabel;
  final Map<String, String> extraStatusLabels;
  final Map<String, String> customStatusLabels;
  final bool customStatusesOnly;
  final bool showPartly;

  Map<String, dynamic> metadataFor({
    required String status,
    required DateTime completedOnDate,
  }) {
    final graphEventType = status == 'skipped'
        ? 'flow_skipped'
        : status == 'conversation_pending'
        ? 'flow_pending'
        : 'flow_completed';
    final signalStrength = switch (status) {
      'observed' => 1.0,
      'observed_partly' => 0.55,
      'observed_from_inside' => 0.65,
      'names_spoken' => 0.75,
      'held' => 1.0,
      'carry_forward' => 1.0,
      'release' => 1.0,
      'working' => 0.55,
      'slipped' => 0.4,
      'raised' => 1.0,
      'decision_pronounced' => 1.0,
      'transmitted' => 1.0,
      'stones_placed' => 1.0,
      'cooled' => 1.0,
      'spoken' => 1.0,
      'record_complete' => 1.0,
      'beer_poured' => 1.0,
      'golden_one_present' => 1.0,
      'conversation_pending' => 0.3,
      'skipped' => 0.2,
      _ => 0.0,
    };

    return <String, dynamic>{
      'status': status,
      'flow_key': flowKey,
      'flow_title': flowTitle,
      'event_title': eventTitle,
      'completed_on': _formatCompletionDate(completedOnDate),
      if (eventCategory != null && eventCategory!.trim().isNotEmpty)
        'event_category': eventCategory!.trim(),
      if (eventNumber != null) 'event_number': eventNumber,
      if (dayNumber != null) 'day_number': dayNumber,
      if (flowDay != null) 'flow_day': flowDay,
      if (flowKey == kEveningThresholdFlowKey)
        'daily_orientation': <String, dynamic>{
          'linked_to': kEveningThresholdLinkedTo,
          'carryover_field': kEveningThresholdCarryoverField,
          'landing_field': kEveningThresholdLandingField,
          'decision_table': kEveningThresholdDecisionTable,
          if (eventNumber == 1)
            'landing_status': status == 'working' ? 'working_on_it' : status,
          if (eventNumber == 2)
            'carryover_choice': status == 'carry_forward'
                ? 'carry_it_forward'
                : status == 'release'
                ? 'release_it'
                : status,
          if (eventNumber == 2)
            'decision': status == 'carry_forward'
                ? 'carried'
                : status == 'release'
                ? 'released'
                : status,
          'evening_reflection_status': 'completed',
        },
      'knowledge_graph': <String, dynamic>{
        'version': 'maat_flow_completion_v1',
        'event_type': graphEventType,
        'node_slugs': graphNodeSlugs,
        'signal_strength': signalStrength,
      },
    };
  }
}

class _MaatLibraryCtaPayload {
  const _MaatLibraryCtaPayload({
    required this.type,
    required this.label,
    required this.flowKey,
    this.nodeSlug,
  });

  final String type;
  final String label;
  final String? flowKey;
  final String? nodeSlug;
}

_MaatLibraryCtaPayload? _maatLibraryCtaPayloadForEvent(EventItem event) {
  final rawPayload = event.behaviorPayload;
  final rawCta = rawPayload?['library_cta'];
  if (rawCta is! Map) return null;
  final cta = Map<String, dynamic>.from(rawCta);
  final type = cta['type']?.toString().trim();
  if (type == null || type.isEmpty) return null;
  final rawNodeSlug = cta['node_slug']?.toString().trim();
  final rawLabel = cta['label']?.toString().trim();
  return _MaatLibraryCtaPayload(
    type: type,
    label: rawLabel == null || rawLabel.isEmpty ? 'Add your insight' : rawLabel,
    flowKey: rawPayload?['flow_key']?.toString().trim(),
    nodeSlug: rawNodeSlug == null || rawNodeSlug.isEmpty ? null : rawNodeSlug,
  );
}

String _formatCompletionDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

List<String> _dedupeMaatNodeSlugs(Iterable<String> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final raw in values) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty || seen.contains(value)) continue;
    seen.add(value);
    result.add(value);
  }
  return result;
}

List<String> _maatGraphNodeSlugsForFlow({
  required String flowKey,
  String? eventCategory,
}) {
  switch (flowKey) {
    case kDawnHouseRiteFlowKey:
      return const <String>['maat', 'ra'];
    case kEveningThresholdFlowKey:
      return const <String>['maat', 'duat', 'ra'];
    case kEveningThresholdRiteFlowKey:
      return const <String>['maat', 'ra', 'ausar'];
    case kTheWeighingFlowKey:
      return const <String>['maat', 'djehuty'];
    case kOfferingTableFlowKey:
      return const <String>['maat', 'nile', 'ka'];
    case kTheTendingFlowKey:
      return const <String>['maat', 'heru', 'aset'];
    case kKeptWordFlowKey:
      return const <String>['maat', 'ptah', 'djehuty'];
    case kTheCourseFlowKey:
      return const <String>['maat', 'ra', 'khepri', 'decans'];
    case kMoonReturnFlowKey:
      return const <String>['maat', 'heru', 'djehuty'];
    case kTheWagFlowKey:
      return const <String>['maat', 'ausar', 'anpu', 'ren'];
    case kDecanWatchFlowKey:
      return const <String>['maat', 'nut', 'ra', 'decans'];
    case kDaysOutsideTheYearFlowKey:
      return const <String>[
        'maat',
        'epagomenal_days',
        'ausar',
        'heru',
        'set',
        'aset',
        'nebet_het',
      ];
    case kTheOpenHandFlowKey:
      return const <String>['maat', 'hapy', 'nile'];
    case kTheDjedFlowKey:
      return const <String>['maat', 'djed', 'ausar', 'ptah'];
    case kFairHearingFlowKey:
      return const <String>['maat', 'djehuty', 'anpu', 'heru'];
    case kHouseOfLifeFlowKey:
      return const <String>['maat', 'djehuty', 'ptah', 'ren'];
    case kBoundaryStoneFlowKey:
      return const <String>['maat', 'isfet', 'set', 'djehuty'];
    case kHotepFlowKey:
      return const <String>['maat', 'hapy', 'anpu', 'heru'];
    case kOpenMouthFlowKey:
      return const <String>['maat', 'ptah', 'djehuty', 'aset'];
    case kLivingRecordFlowKey:
      return const <String>['maat', 'djehuty', 'house_of_life', 'ren'];
    case kHetHeruFlowKey:
      return const <String>['maat', 'hathor', 'sekhmet', 'eye_of_ra', 'ra'];
    case kTheShoreFlowKey:
      return const <String>['maat', 'djehuty', 'hapy', 'renenutet'];
    case kTheAutobiographyFlowKey:
      return const <String>['maat', 'ren', 'ka', 'djehuty'];
    case kFirstArrangementFlowKey:
      return const <String>['maat', 'ptah', 'anpu', 'hapy'];
    case kLivingPatternFlowKey:
      return const <String>['maat', 'ra', 'hapy', 'anpu', 'khepri'];
    case kTrueNameFlowKey:
      return const <String>['maat', 'ren', 'aset', 'anpu'];
    case kLivingTextFlowKey:
      return const <String>['maat', 'djehuty', 'ptah', 'ren'];
    case 'track-the-sky':
      final category = eventCategory?.trim().toLowerCase() ?? '';
      return _dedupeMaatNodeSlugs(<String>[
        'maat',
        'nut',
        if (category.contains('solar') ||
            category.contains('sun') ||
            category.contains('equinox') ||
            category.contains('solstice'))
          'ra',
      ]);
  }
  return const <String>['maat'];
}

EveningThresholdRiteDay? _eveningThresholdRiteDayForTitle(String? title) {
  final match = RegExp(
    r'^\s*Day\s+(\d{1,2})\s*:',
    caseSensitive: false,
  ).firstMatch(title?.trim() ?? '');
  final dayNumber = int.tryParse(match?.group(1) ?? '');
  if (dayNumber == null ||
      dayNumber < 1 ||
      dayNumber > kEveningThresholdRiteDays.length) {
    return null;
  }
  return kEveningThresholdRiteDays[dayNumber - 1];
}

_MaatFlowCompletionContext? _maatFlowCompletionContextForEvent(
  EventItem event,
  FlowData? flow,
) {
  final flowName = flow?.name;
  if (_isDawnHouseRiteFlowName(flowName)) {
    final day = dawnHouseRiteDayForEvent(title: event.title);
    return _MaatFlowCompletionContext(
      flowKey: kDawnHouseRiteFlowKey,
      flowTitle: kDawnHouseRiteTitle,
      eventTitle: event.title,
      eventCategory: event.category,
      dayNumber: day?.dayNumber,
      graphNodeSlugs: _maatGraphNodeSlugsForFlow(
        flowKey: kDawnHouseRiteFlowKey,
        eventCategory: event.category,
      ),
    );
  }

  if (_isEveningThresholdFlowName(flowName)) {
    final thresholdEvent = eveningThresholdEventForEvent(
      title: event.title,
      behaviorPayload: event.behaviorPayload,
    );
    if (thresholdEvent == null) return null;
    return _MaatFlowCompletionContext(
      flowKey: kEveningThresholdFlowKey,
      flowTitle: kEveningThresholdTitle,
      eventTitle: event.title,
      eventCategory: event.category,
      eventNumber: thresholdEvent.eventNumber,
      customStatusLabels: thresholdEvent.completionStatusLabels,
      customStatusesOnly: true,
      showPartly: false,
      graphNodeSlugs: _maatGraphNodeSlugsForFlow(
        flowKey: kEveningThresholdFlowKey,
        eventCategory: event.category,
      ),
    );
  }

  if (_isEveningThresholdRiteFlowName(flowName)) {
    final day = _eveningThresholdRiteDayForTitle(event.title);
    return _MaatFlowCompletionContext(
      flowKey: kEveningThresholdRiteFlowKey,
      flowTitle: kEveningThresholdRiteTitle,
      eventTitle: event.title,
      eventCategory: event.category,
      dayNumber: day?.dayNumber,
      graphNodeSlugs: _maatGraphNodeSlugsForFlow(
        flowKey: kEveningThresholdRiteFlowKey,
        eventCategory: event.category,
      ),
    );
  }

  if (_isTrackSkyFlowName(flowName)) {
    return _MaatFlowCompletionContext(
      flowKey: 'track-the-sky',
      flowTitle: flowName ?? 'Track the Sky',
      eventTitle: event.title,
      eventCategory: event.category,
      graphNodeSlugs: _maatGraphNodeSlugsForFlow(
        flowKey: 'track-the-sky',
        eventCategory: event.category,
      ),
    );
  }

  if (_isMoonReturnFlowName(flowName)) {
    final kind = moonReturnKindForEvent(title: event.title);
    return _MaatFlowCompletionContext(
      flowKey: kMoonReturnFlowKey,
      flowTitle: kMoonReturnTitle,
      eventTitle: event.title,
      eventCategory: event.category,
      sharePromptOnComplete: kind == MoonReturnEventKind.wholeEye,
      shareButtonLabel: 'Share what filled',
      showPartly: false,
      graphNodeSlugs: _maatGraphNodeSlugsForFlow(
        flowKey: kMoonReturnFlowKey,
        eventCategory: event.category,
      ),
    );
  }

  if (_isTheWagFlowName(flowName)) {
    final wagEvent = wagEventForEvent(title: event.title);
    if (wagEvent == null) return null;
    return _MaatFlowCompletionContext(
      flowKey: kTheWagFlowKey,
      flowTitle: kTheWagTitle,
      eventTitle: event.title,
      eventCategory: event.category,
      eventNumber: wagEvent.eventNumber,
      dayNumber: wagEvent.kemeticDay,
      sharePromptOnComplete: wagEvent.sharePromptOnComplete,
      shareButtonLabel: 'Share what was confirmed',
      extraStatusLabels: wagEvent.kind == WagEventKind.feast
          ? const <String, String>{'names_spoken': 'Names spoken'}
          : const <String, String>{},
      graphNodeSlugs: _maatGraphNodeSlugsForFlow(
        flowKey: kTheWagFlowKey,
        eventCategory: event.category,
      ),
    );
  }

  if (_isDecanWatchFlowName(flowName)) {
    return _MaatFlowCompletionContext(
      flowKey: kDecanWatchFlowKey,
      flowTitle: kDecanWatchTitle,
      eventTitle: event.title,
      eventCategory: event.category,
      sharePromptOnComplete: false,
      showPartly: false,
      extraStatusLabels: const <String, String>{
        'observed_from_inside': 'Inside',
      },
      graphNodeSlugs: _maatGraphNodeSlugsForFlow(
        flowKey: kDecanWatchFlowKey,
        eventCategory: event.category,
      ),
    );
  }

  if (_isDaysOutsideYearFlowName(flowName)) {
    final daysEvent = daysOutsideEventForEvent(title: event.title);
    if (daysEvent == null) return null;
    return _MaatFlowCompletionContext(
      flowKey: kDaysOutsideTheYearFlowKey,
      flowTitle: kDaysOutsideTheYearTitle,
      eventTitle: event.title,
      eventCategory: event.category,
      eventNumber: daysEvent.eventNumber,
      dayNumber: daysEvent.kDay,
      sharePromptOnComplete: daysEvent.optionalShareOnComplete,
      shareButtonLabel: 'Share one word',
      graphNodeSlugs: _maatGraphNodeSlugsForFlow(
        flowKey: kDaysOutsideTheYearFlowKey,
        eventCategory: event.category,
      ),
    );
  }

  if (_isOpenHandFlowName(flowName)) {
    final openHandEvent = openHandEventForEvent(title: event.title);
    if (openHandEvent == null) return null;
    return _MaatFlowCompletionContext(
      flowKey: kTheOpenHandFlowKey,
      flowTitle: kTheOpenHandTitle,
      eventTitle: event.title,
      eventCategory: event.category,
      eventNumber: openHandEvent.eventNumber,
      flowDay: openHandEvent.flowDay,
      sharePromptOnComplete: openHandEvent.sharePromptOnComplete,
      shareButtonLabel: 'Share continuing practice',
      graphNodeSlugs: _maatGraphNodeSlugsForFlow(
        flowKey: kTheOpenHandFlowKey,
        eventCategory: event.category,
      ),
    );
  }

  if (_isDjedFlowName(flowName)) {
    final djedEvent = djedEventForEvent(title: event.title);
    if (djedEvent == null) return null;
    return _MaatFlowCompletionContext(
      flowKey: kTheDjedFlowKey,
      flowTitle: kTheDjedTitle,
      eventTitle: event.title,
      eventCategory: event.category,
      eventNumber: djedEvent.eventNumber,
      flowDay: djedEvent.flowDay,
      sharePromptOnComplete: djedEvent.sharePromptOnComplete,
      shareButtonLabel: 'Share what holds',
      extraStatusLabels: djedEvent.physicalRaising
          ? const <String, String>{'raised': 'Raised'}
          : const <String, String>{},
      graphNodeSlugs: _maatGraphNodeSlugsForFlow(
        flowKey: kTheDjedFlowKey,
        eventCategory: event.category,
      ),
    );
  }

  final maatDecanDefinition =
      maatDecanFlowDefinitionFromNotes(flow?.notes) ??
      maatDecanFlowDefinitionForTitle(flowName);
  if (maatDecanDefinition != null) {
    final maatDecanEvent = maatDecanFlowEventForEvent(
      definition: maatDecanDefinition,
      title: event.title,
    );
    if (maatDecanEvent == null) return null;
    return _MaatFlowCompletionContext(
      flowKey: maatDecanDefinition.key,
      flowTitle: maatDecanDefinition.title,
      eventTitle: event.title,
      eventCategory: event.category,
      eventNumber: maatDecanEvent.eventNumber,
      flowDay: maatDecanEvent.flowDay,
      sharePromptOnComplete: maatDecanEvent.sharePromptOnComplete,
      shareButtonLabel: 'Share the practice',
      extraStatusLabels: maatDecanEvent.extraCompletionStatusLabels,
      graphNodeSlugs: _maatGraphNodeSlugsForFlow(
        flowKey: maatDecanDefinition.key,
        eventCategory: event.category,
      ),
    );
  }

  if (_isTheWeighingFlowName(flowName)) {
    final weighingEvent = theWeighingEventForEvent(title: event.title);
    if (weighingEvent == null) return null;
    return _MaatFlowCompletionContext(
      flowKey: kTheWeighingFlowKey,
      flowTitle: kTheWeighingTitle,
      eventTitle: event.title,
      eventCategory: event.category,
      eventNumber: weighingEvent.eventNumber,
      flowDay: weighingEvent.flowDay,
      sharePromptOnComplete: weighingEvent.sharePromptOnComplete,
      graphNodeSlugs: _maatGraphNodeSlugsForFlow(
        flowKey: kTheWeighingFlowKey,
        eventCategory: event.category,
      ),
    );
  }

  if (_isOfferingTableFlowName(flowName)) {
    final offeringDay = offeringTableDayForEvent(title: event.title);
    if (offeringDay == null) return null;
    return _MaatFlowCompletionContext(
      flowKey: kOfferingTableFlowKey,
      flowTitle: kOfferingTableTitle,
      eventTitle: event.title,
      eventCategory: event.category,
      dayNumber: offeringDay.dayNumber,
      sharePromptOnComplete: offeringDay.sharePromptOnComplete,
      shareButtonLabel: 'Share what the table held',
      graphNodeSlugs: _maatGraphNodeSlugsForFlow(
        flowKey: kOfferingTableFlowKey,
        eventCategory: event.category,
      ),
    );
  }

  if (_isTheTendingFlowName(flowName)) {
    final tendingEvent = theTendingEventForEvent(title: event.title);
    if (tendingEvent == null) return null;
    return _MaatFlowCompletionContext(
      flowKey: kTheTendingFlowKey,
      flowTitle: kTheTendingTitle,
      eventTitle: event.title,
      eventCategory: event.category,
      eventNumber: tendingEvent.eventNumber,
      flowDay: tendingEvent.flowDay,
      sharePromptOnComplete: tendingEvent.sharePromptOnComplete,
      shareButtonLabel: 'Share what was restored',
      graphNodeSlugs: _maatGraphNodeSlugsForFlow(
        flowKey: kTheTendingFlowKey,
        eventCategory: event.category,
      ),
    );
  }

  if (_isKeptWordFlowName(flowName)) {
    final keptWordEvent = keptWordEventForEvent(title: event.title);
    if (keptWordEvent == null) return null;
    return _MaatFlowCompletionContext(
      flowKey: kKeptWordFlowKey,
      flowTitle: kKeptWordTitle,
      eventTitle: event.title,
      eventCategory: event.category,
      eventNumber: keptWordEvent.eventNumber,
      flowDay: keptWordEvent.flowDay,
      sharePromptOnComplete: keptWordEvent.sharePromptOnComplete,
      shareButtonLabel: 'Share the kept word',
      extraStatusLabels: keptWordEvent.eventNumber == 5
          ? const <String, String>{
              'conversation_pending': 'Conversation pending',
            }
          : const <String, String>{},
      graphNodeSlugs: _maatGraphNodeSlugsForFlow(
        flowKey: kKeptWordFlowKey,
        eventCategory: event.category,
      ),
    );
  }

  if (_isTheCourseFlowName(flowName)) {
    final courseEvent = courseEventForEvent(title: event.title);
    if (courseEvent == null) return null;
    return _MaatFlowCompletionContext(
      flowKey: kTheCourseFlowKey,
      flowTitle: kTheCourseTitle,
      eventTitle: event.title,
      eventCategory: event.category,
      eventNumber: courseEvent.eventNumber,
      flowDay: courseEvent.flowDay,
      sharePromptOnComplete: courseEvent.sharePromptOnComplete,
      shareButtonLabel: 'Share the practice',
      graphNodeSlugs: _maatGraphNodeSlugsForFlow(
        flowKey: kTheCourseFlowKey,
        eventCategory: event.category,
      ),
    );
  }

  return null;
}

bool hasDayViewMaatFlowCompletionContext(EventItem event, FlowData? flow) {
  return _maatFlowCompletionContextForEvent(event, flow) != null;
}

Widget? buildDayViewMaatFlowCompletionPanel({
  required EventItem event,
  required FlowData? flow,
  required String identity,
  required int ky,
  required int km,
  required int kd,
  Future<void> Function({
    required String clientEventId,
    required int flowId,
    required DateTime completedOnDate,
    Map<String, dynamic>? metadata,
  })?
  onRecordCompletion,
  Future<void> Function(String clientEventId)? onUnrecordCompletion,
  Future<void> Function(String badgeId)? onRemoveCompletionBadge,
  Future<void> Function(CompletionStatus status)? onCompletionContinuity,
  ValueChanged<CompletionStatus>? onUserCompletionFeedback,
  VoidCallback? onAddReflection,
  Key? observedButtonKey,
  Object? reloadSignal,
}) {
  final completion = _maatFlowCompletionContextForEvent(event, flow);
  if (completion == null ||
      event.clientEventId?.trim().isNotEmpty != true ||
      event.flowId == null) {
    return null;
  }
  return _MaatFlowCompletionPanel(
    event: event,
    identity: identity,
    completion: completion,
    ky: ky,
    km: km,
    kd: kd,
    onRecordCompletion: onRecordCompletion,
    onUnrecordCompletion: onUnrecordCompletion,
    onRemoveCompletionBadge: onRemoveCompletionBadge,
    onCompletionContinuity: onCompletionContinuity,
    onUserCompletionFeedback: onUserCompletionFeedback,
    onAddReflection: onAddReflection,
    observedButtonKey: observedButtonKey,
    reloadSignal: reloadSignal,
  );
}

const Gradient _dawnHouseRiteFlowGloss = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [
    Color(0xFFFFE8B8),
    Color(0xFFF3A55E),
    Color(0xFFFFF3D6),
    Color(0xFFE98E52),
  ],
  stops: [0.0, 0.34, 0.66, 1.0],
);

const LinearGradient _dawnHouseRiteCardGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFF12152C),
    Color(0xFF3A315D),
    Color(0xFFB56A6E),
    Color(0xFFF2B45F),
  ],
  stops: [0.0, 0.38, 0.76, 1.0],
);

const Gradient _theWeighingFlowGloss = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [
    Color(0xFFF5E8CB),
    Color(0xFFB8A88A),
    Color(0xFFFFF8E8),
    Color(0xFF8D7C5F),
  ],
  stops: [0.0, 0.34, 0.66, 1.0],
);

const LinearGradient _theWeighingCardGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF111213),
    Color(0xFF2C2A25),
    Color(0xFF5D5241),
    Color(0xFFB8A88A),
  ],
  stops: [0.0, 0.42, 0.78, 1.0],
);

Widget _buildDawnHouseRiteAccent({required bool compact, double size = 24}) {
  final sunSize = compact ? size * 0.46 : size * 0.56;
  return SizedBox(
    width: size + 10,
    height: size,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 1,
          right: 1,
          bottom: 7,
          child: Container(
            height: 1.5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Color(0xFFFFE7B5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: 4,
          bottom: 7,
          child: Container(
            width: sunSize,
            height: sunSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFD27A),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFC166).withValues(alpha: 0.5),
                  blurRadius: compact ? 7 : 11,
                  spreadRadius: compact ? 0 : 1,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 1,
          bottom: 0,
          child: Container(
            width: size + 7,
            height: size * 0.36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF331E32).withValues(alpha: 0.72),
                  const Color(0xFF130E1C).withValues(alpha: 0.92),
                ],
              ),
              borderRadius: BorderRadius.vertical(
                top: Radius.elliptical(size, size * 0.34),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

const Gradient _eveningThresholdRiteFlowGloss = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [
    Color(0xFFF4EEFF),
    Color(0xFFB9C7FF),
    Color(0xFFFFE7A8),
    Color(0xFF7FE0D4),
  ],
  stops: [0.0, 0.38, 0.62, 1.0],
);

const LinearGradient _eveningThresholdRiteCardGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF030611),
    Color(0xFF111634),
    Color(0xFF193248),
    Color(0xFF2B254E),
  ],
  stops: [0.0, 0.36, 0.7, 1.0],
);

Widget _buildEveningThresholdRiteAccent({
  required bool compact,
  double size = 24,
}) {
  final moonSize = compact ? size * 0.32 : size * 0.4;
  return SizedBox(
    width: size + 10,
    height: size,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 4,
          top: 4,
          child: Container(
            width: moonSize,
            height: moonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF4EEFF).withValues(alpha: 0.94),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFAFC6FF).withValues(alpha: 0.45),
                  blurRadius: compact ? 6 : 9,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: moonSize * 0.52 + 4,
          top: 3,
          child: Container(
            width: moonSize,
            height: moonSize,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF111634),
            ),
          ),
        ),
        Positioned(
          right: size * 0.16,
          top: size * 0.18,
          child: Container(
            width: compact ? 2.2 : 3,
            height: compact ? 2.2 : 3,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF7F0FF).withValues(alpha: 0.86),
            ),
          ),
        ),
      ],
    ),
  );
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
    double singleEventWidthFactor = _kSingleEventWidthFactor,
  }) {
    if (kDebugMode) {
      debugPrint(
        '[EventLayoutEngine] Layout for day $day: ${notes.length} notes',
      );
    }

    final events = _sortedEventsForDay(notes: notes, flowIndex: flowIndex);

    return layoutEventItems(
      events: events,
      availableWidth: availableWidth,
      columnGap: columnGap,
      textScale: textScale,
      day: day,
      singleEventWidthFactor: singleEventWidthFactor,
    );
  }

  static List<PositionedEventBlock> layoutEventItems({
    required List<EventItem> events,
    required double availableWidth,
    required double columnGap,
    required double textScale,
    required int day,
    double singleEventWidthFactor = _kSingleEventWidthFactor,
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
        singleEventWidthFactor: singleEventWidthFactor,
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
      debugPrint(
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
    required double singleEventWidthFactor,
  }) {
    if (totalColumns <= 1) {
      return availableWidth * singleEventWidthFactor.clamp(0.0, 1.0);
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
  final String? calendarId;
  final String? calendarName;
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
  final Map<String, dynamic>? behaviorPayload;

  const NoteData({
    this.id,
    this.clientEventId,
    this.calendarId,
    this.calendarName,
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
    this.behaviorPayload,
  });
}

class FlowData {
  final int id;
  final String name;
  final Color color;
  final bool active;
  final String? notes;
  final bool isHidden;
  final bool isReminder;

  const FlowData({
    required this.id,
    required this.name,
    required this.color,
    required this.active,
    this.notes,
    this.isHidden = false,
    this.isReminder = false,
  });
}

class EventItem {
  final String? id;
  final String? clientEventId;
  final String? calendarId;
  final String? calendarName;
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
  final Map<String, dynamic>? behaviorPayload;

  const EventItem({
    this.id,
    this.clientEventId,
    this.calendarId,
    this.calendarName,
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
    this.behaviorPayload,
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

class CalendarEventDetailSheetCoordinator {
  CalendarEventDetailSheetCoordinator._();

  static bool _openOrOpening = false;

  static bool get isOpenOrOpening => _openOrOpening;

  static bool tryMarkOpenOrOpening() {
    if (_openOrOpening) return false;
    _openOrOpening = true;
    return true;
  }

  static void markClosed() {
    _openOrOpening = false;
  }

  @visibleForTesting
  static void debugResetForTests() {
    _openOrOpening = false;
  }
}

EventDetailRestorationState? eventDetailRestorationStateForTarget(
  DayViewSheetEventTarget target, {
  String? parentSurface,
}) {
  final event = target.event;
  final clientEventId = event.clientEventId?.trim();
  if (clientEventId != null &&
      clientEventId.isNotEmpty &&
      clientEventId != _kNewEventPreviewClientEventId) {
    return EventDetailRestorationState(
      kYear: target.ky,
      kMonth: target.km,
      kDay: target.kd,
      identityType: eventDetailIdentityClientEventId,
      identityValue: clientEventId,
      parentSurface: parentSurface,
    );
  }

  final eventId = event.id?.trim();
  if (eventId != null && eventId.isNotEmpty) {
    return EventDetailRestorationState(
      kYear: target.ky,
      kMonth: target.km,
      kDay: target.kd,
      identityType: eventDetailIdentityEventId,
      identityValue: eventId,
      parentSurface: parentSurface,
    );
  }

  final reminderId = event.reminderId?.trim();
  if (reminderId != null && reminderId.isNotEmpty) {
    return EventDetailRestorationState(
      kYear: target.ky,
      kMonth: target.km,
      kDay: target.kd,
      identityType: eventDetailIdentityReminderId,
      identityValue: reminderId,
      parentSurface: parentSurface,
    );
  }

  return null;
}

bool eventMatchesDetailRestorationState(
  EventItem event,
  EventDetailRestorationState state,
) {
  switch (state.identityType) {
    case eventDetailIdentityClientEventId:
      return event.clientEventId?.trim() == state.identityValue;
    case eventDetailIdentityEventId:
      return event.id?.trim() == state.identityValue;
    case eventDetailIdentityReminderId:
      return event.reminderId?.trim() == state.identityValue;
  }
  return false;
}

DayViewSheetEventTarget? eventDetailTargetFromRestorationState({
  required EventDetailRestorationState state,
  required Iterable<EventItem> events,
}) {
  for (final event in events) {
    if (!eventMatchesDetailRestorationState(event, state)) continue;
    return DayViewSheetEventTarget(
      ky: state.kYear,
      km: state.kMonth,
      kd: state.kDay,
      event: event,
    );
  }
  return null;
}

List<NoteData> _dedupeDayNotesForUi(List<NoteData> notes) {
  if (notes.isEmpty) return notes;

  final exactIndexByKey = <String, int>{};
  final flowLogicalIndexByKey = <String, int>{};
  final output = <NoteData>[];

  bool hasIdentity(NoteData n) =>
      (n.id != null && n.id!.trim().isNotEmpty) ||
      (n.clientEventId != null && n.clientEventId!.trim().isNotEmpty);

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

    final exactExistingIndex = exactIndexByKey[key];
    if (exactExistingIndex != null) {
      final exactExisting = output[exactExistingIndex];
      if (!hasIdentity(exactExisting) && hasIdentity(note)) {
        output[exactExistingIndex] = note;
      }
      continue;
    }

    final flowId = note.flowId;
    final flowLogicalKey =
        flowId != null && flowId > 0 && !note.isReminder && titleKey.isNotEmpty
        ? 'flow-logical|$flowId|$titleKey'
        : null;

    final flowLogicalExistingIndex = flowLogicalKey == null
        ? null
        : flowLogicalIndexByKey[flowLogicalKey];
    if (flowLogicalExistingIndex != null) {
      output[flowLogicalExistingIndex] = note;
      exactIndexByKey[key] = flowLogicalExistingIndex;
      continue;
    }

    final index = output.length;
    exactIndexByKey[key] = index;
    if (flowLogicalKey != null) {
      flowLogicalIndexByKey[flowLogicalKey] = index;
    }
    output.add(note);
  }

  return output;
}

EventItem _eventItemFromNote(NoteData note, Map<int, FlowData> flowIndex) {
  final startMin = note.allDay
      ? 9 * 60
      : (note.start?.hour ?? 9) * 60 + (note.start?.minute ?? 0);
  final endMin = note.allDay
      ? 17 * 60
      : (note.end?.hour ?? 17) * 60 + (note.end?.minute ?? 0);

  Color eventColor = Colors.blue;
  // Product rule: explicit per-event colors win; otherwise we fall back to the
  // owning flow's chrome color so historical/saved flow notes stay unified.
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
    behaviorPayload: note.behaviorPayload,
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
    event.calendarId ?? '',
    event.location?.trim().toLowerCase() ?? '',
    event.detail?.trim().toLowerCase() ?? '',
    event.allDay,
    event.isReminder,
  ].join('|');
}

@visibleForTesting
Key dayViewOverflowVisualKey(String eventIdentity, int hour) =>
    ValueKey<String>('day_view_overflow_visual:$eventIdentity:$hour');

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
  int durationMinutes = event.endMin - event.startMin;
  if (durationMinutes <= 0) {
    durationMinutes = 15;
  }
  if (durationMinutes > 180) {
    durationMinutes = 180;
  }

  if (event.isReminder) {
    final effectiveTextScale = textScale.clamp(1.0, 1.25).toDouble();
    final compactPreviewHeight = 54.0 * effectiveTextScale;
    final durationHeight = durationMinutes
        .toDouble()
        .clamp(42.0, 90.0)
        .toDouble();
    return math.max(compactPreviewHeight, durationHeight);
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

  int get durationMin => (event.endMin - event.startMin).clamp(15, 12 * 60);
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
  final Set<int> activeLedgerFlowIds;
  final Set<int> Function()? activeLedgerFlowIdsBuilder;
  final ValueListenable<int>? dataVersion;
  final String Function(int km) getMonthName;
  final int? initialFirstVisibleMinute;
  final double? initialScrollOffset; // optional: jump to a target time on open
  final int? focusStartMin; // minutes since midnight to auto-scroll/highlight
  final int? focusFlowId; // highlight a flow's events
  final String? focusTitle; // highlight by title when flow id missing
  final EventDetailRestorationState? initialEventDetailRestorationState;
  final void Function(int?)? onManageFlows; // NEW: Callback to open My Flows
  final Future<void> Function(BuildContext context)? onOpenQuickAdd;
  final Future<void> Function(BuildContext context)? onOpenSearch;
  final Future<void> Function(BuildContext context)? onOpenProfile;
  final Future<void> Function(BuildContext context)? onOpenMenu;
  final VoidCallback? onClose;
  final Future<void> Function()? onUserClose;
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
    Map<String, dynamic>? metadata,
  })?
  onRecordCompletion;
  final Future<void> Function(String clientEventId)? onUnrecordCompletion;
  final Future<void> Function(String badgeId)? onRemoveCompletionBadge;
  final String? onboardingEventClientEventId;
  final GlobalKey? onboardingEventTargetKey;
  final GlobalKey? onboardingObservedKey;
  final GlobalKey? onboardingJournalKey;
  final VoidCallback? onOnboardingEventOpened;
  final VoidCallback? onOnboardingObservedJournalNext;
  final WidgetBuilder? onboardingClosingBannerBuilder;
  final bool showDayCardRevealCoachmarkForOnboarding;
  final VoidCallback? onDayCardRevealCoachmarkCompleted;
  final DayViewRestorationCallback? onRestorationStateChanged;
  final bool Function()? shouldPreserveEventDetailRestorationOnClose;

  const DayViewPage({
    super.key,
    required this.initialKy,
    required this.initialKm,
    required this.initialKd,
    required this.showGregorian,
    required this.notesForDay,
    required this.flowIndex,
    this.flowIndexBuilder,
    this.activeLedgerFlowIds = const <int>{},
    this.activeLedgerFlowIdsBuilder,
    this.dataVersion,
    required this.getMonthName,
    this.initialFirstVisibleMinute,
    this.initialScrollOffset,
    this.focusStartMin,
    this.focusFlowId,
    this.focusTitle,
    this.initialEventDetailRestorationState,
    this.onManageFlows, // NEW
    this.onOpenQuickAdd,
    this.onOpenSearch,
    this.onOpenProfile,
    this.onOpenMenu,
    this.onClose,
    this.onUserClose,
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
    this.onRemoveCompletionBadge,
    this.onboardingEventClientEventId,
    this.onboardingEventTargetKey,
    this.onboardingObservedKey,
    this.onboardingJournalKey,
    this.onOnboardingEventOpened,
    this.onOnboardingObservedJournalNext,
    this.onboardingClosingBannerBuilder,
    this.showDayCardRevealCoachmarkForOnboarding = false,
    this.onDayCardRevealCoachmarkCompleted,
    this.onRestorationStateChanged,
    this.shouldPreserveEventDetailRestorationOnClose,
  });

  @override
  State<DayViewPage> createState() => _DayViewPageState();
}

class _DayViewPageState extends State<DayViewPage> {
  static const double _miniCalendarHorizontalPadding = 8.0;
  static const double _miniCalendarChipMargin = 2.0;
  late PageController _pageController;
  late int _currentKy;
  late int _currentKm;
  late int _currentKd;
  late bool _showGregorian;
  late DateTime _initialGregorian; // Added for stable date arithmetic
  static const int _centerPage = 5000;
  int _gridInstance = 0; // Forces grid rebuilds when jumping
  double? _savedScrollOffset; // Added for scroll persistence

  int? _firstVisibleMinuteForOffset(double? offset) {
    if (offset == null || !offset.isFinite) {
      return null;
    }
    final minute = (offset / _kDayViewPixelsPerMinute).floor();
    return minute.clamp(0, 24 * 60 - 1).toInt();
  }

  // ✅ Today button guard to prevent duplicate state updates
  bool _isJumpingToToday = false;
  bool _userCloseReported = false;

  // 🔧 ADD THIS: Persistent scroll controller for mini calendar
  late ScrollController _miniCalendarScrollController;
  bool _autoCenterMiniCalendar = true;

  // 🔧 NEW: Orientation tracking for bidirectional lock
  Orientation? _lastOrientation;
  bool _showDayCardRevealCoachmark = false;
  bool _hasResolvedDayCardRevealCoachmarkOnboarding = false;
  EventDetailRestorationState? _activeEventDetailRestoration;
  final GlobalKey _dayCardRevealTargetKey = GlobalKey(
    debugLabel: 'day_view_date_reveal_target',
  );
  Timer? _restorationDebounce;

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
    _activeEventDetailRestoration = widget.initialEventDetailRestorationState;
    _pageController = PageController(initialPage: _centerPage);
    _miniCalendarScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerMiniCalendarOnDay(_currentKd, animated: false, force: true);
    });
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
    if (old.initialEventDetailRestorationState !=
        widget.initialEventDetailRestorationState) {
      _activeEventDetailRestoration = widget.initialEventDetailRestorationState;
    }
    if (old.initialKy != widget.initialKy ||
        old.initialKm != widget.initialKm ||
        old.initialKd != widget.initialKd) {
      final g = KemeticMath.toGregorian(
        widget.initialKy,
        widget.initialKm,
        widget.initialKd,
      );
      setState(() {
        _initialGregorian = g;
        _currentKy = widget.initialKy;
        _currentKm = widget.initialKm;
        _currentKd = widget.initialKd;
        _autoCenterMiniCalendar = true;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_centerPage); // reset paging anchor
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerMiniCalendarOnDay(_currentKd, animated: false, force: true);
      });
    }
  }

  @override
  void dispose() {
    _reportRestorationState(immediate: true);
    _restorationDebounce?.cancel();
    _pageController.dispose();
    _miniCalendarScrollController.dispose(); // 🔧 Don't forget to dispose
    super.dispose();
  }

  void _toggleDateDisplay() {
    if (!mounted) return;
    setState(() {
      _showGregorian = !_showGregorian;
    });
    _reportRestorationState(immediate: true);
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
    _scheduleMiniCalendarCentering(_currentKd);
    _reportRestorationState(immediate: true);
  }

  void _onScrollChanged(double offset) {
    _savedScrollOffset = offset;
    _reportRestorationState();
  }

  void _reportRestorationState({bool immediate = false}) {
    if (_userCloseReported) {
      _restorationDebounce?.cancel();
      return;
    }
    final callback = widget.onRestorationStateChanged;
    if (callback == null) {
      return;
    }

    void emit() {
      if (_userCloseReported) return;
      callback(
        kYear: _currentKy,
        kMonth: _currentKm,
        kDay: _currentKd,
        showGregorian: _showGregorian,
        firstVisibleMinute: _firstVisibleMinuteForOffset(_savedScrollOffset),
        scrollOffset: _savedScrollOffset,
        eventDetail: _activeEventDetailRestoration,
      );
    }

    if (immediate) {
      _restorationDebounce?.cancel();
      emit();
      return;
    }

    _restorationDebounce?.cancel();
    _restorationDebounce = Timer(const Duration(milliseconds: 400), emit);
  }

  void _handleEventDetailRestorationChanged(
    EventDetailRestorationState? state,
  ) {
    _activeEventDetailRestoration = state;
    _reportRestorationState(immediate: true);
  }

  bool _shouldPreserveEventDetailRestorationOnClose() {
    return widget.shouldPreserveEventDetailRestorationOnClose?.call() ?? false;
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
    _autoCenterMiniCalendar = true;

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
      _centerMiniCalendarOnDay(_currentKd, force: true);
      _reportRestorationState(immediate: true);
    } finally {
      _isJumpingToToday = false;
    }
  }

  void _handleMiniCalendarManualScrollStart() {
    _autoCenterMiniCalendar = false;
  }

  double _miniCalendarChipExtent() {
    final daySize = expandedTouchTargetMinDimension(
      context,
      fallback: 30,
      minSize: 44,
    );
    return daySize + (_miniCalendarChipMargin * 2);
  }

  double _miniCalendarTargetOffsetForDay(int day) {
    final position = _miniCalendarScrollController.position;
    final daySize = expandedTouchTargetMinDimension(
      context,
      fallback: 30,
      minSize: 44,
    );
    final itemExtent = _miniCalendarChipExtent();
    final dayIndex = day - 1;
    final selectedCenter =
        _miniCalendarHorizontalPadding +
        _miniCalendarChipMargin +
        (daySize / 2) +
        (dayIndex * itemExtent);
    final rawOffset = selectedCenter - (position.viewportDimension / 2);
    return rawOffset.clamp(0.0, position.maxScrollExtent).toDouble();
  }

  void _scheduleMiniCalendarCentering(int day, {bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerMiniCalendarOnDay(day, force: force);
    });
  }

  void _centerMiniCalendarOnDay(
    int day, {
    bool animated = true,
    bool force = false,
  }) {
    if (!mounted || !_miniCalendarScrollController.hasClients) return;
    if (!_autoCenterMiniCalendar && !force) return;

    final target = _miniCalendarTargetOffsetForDay(day);
    final current = _miniCalendarScrollController.offset;
    if ((current - target).abs() < 0.5) return;

    if (!animated) {
      _miniCalendarScrollController.jumpTo(target);
      return;
    }

    _miniCalendarScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Map<int, FlowData> _currentFlowChromeIndex() =>
      widget.flowIndexBuilder?.call() ?? widget.flowIndex;

  Set<int> _currentActiveLedgerFlowIds() =>
      widget.activeLedgerFlowIdsBuilder?.call() ?? widget.activeLedgerFlowIds;

  Future<void> _reportUserClose() async {
    if (_userCloseReported) return;
    _userCloseReported = true;
    _restorationDebounce?.cancel();
    await widget.onUserClose?.call();
  }

  void _closeDayView() {
    unawaited(_closeDayViewAfterUserIntent());
  }

  Future<void> _closeDayViewAfterUserIntent() async {
    await _reportUserClose();
    if (!mounted) return;
    final close = widget.onClose;
    if (close != null) {
      close();
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    popOrGo(context, '/');
  }

  List<EventItem> _eventsForKemeticDay(int ky, int km, int kd) {
    final notes = _dedupeDayNotesForUi(widget.notesForDay(ky, km, kd));
    return _sortedEventsForDay(
      notes: notes,
      flowIndex: _currentFlowChromeIndex(),
    );
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
    _scheduleMiniCalendarCentering(kd, force: true);
  }

  @override
  Widget build(BuildContext context) {
    final dataListenable = widget.dataVersion ?? _kZeroListenable;
    final size = MediaQuery.sizeOf(context);
    final isTablet = size.shortestSide >= 600;

    return ValueListenableBuilder<int>(
      valueListenable: dataListenable,
      builder: (context, _, _) {
        final reportedOrientation = MediaQuery.of(context).orientation;
        // Tablets should stay on the portrait day view regardless of rotation.
        final effectiveOrientation = isTablet
            ? Orientation.portrait
            : reportedOrientation;

        // Track orientation changes for debugging
        if (_lastOrientation != null &&
            _lastOrientation != effectiveOrientation) {
          if (kDebugMode) {
            debugPrint(
              '\n📱 [DAY VIEW] Orientation changed: $_lastOrientation → $effectiveOrientation',
            );
          }
        }
        _lastOrientation = effectiveOrientation;
        final flowIndex = _currentFlowChromeIndex();
        final activeLedgerFlowIds = _currentActiveLedgerFlowIds();

        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) {
              unawaited(_reportUserClose());
            }
          },
          child: Scaffold(
            backgroundColor: _dayViewBase,
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
                    activeLedgerFlowIds: activeLedgerFlowIds,
                    getMonthName: widget.getMonthName,
                    onManageFlows: widget.onManageFlows,
                    onAddNote: widget.onAddNote,
                    onDeleteNote: widget.onDeleteNote,
                    onEditNote: widget.onEditNote,
                    onMoveEventTime: widget.onMoveEventTime,
                    onMonthChanged: (ky, km) {
                      // ✅ HANDLE MONTH CHANGE IN DAY VIEW
                      if (kDebugMode) {
                        debugPrint(
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
                      _reportRestorationState(immediate: true);
                    },
                    onShareNote: widget.onShareNote,
                    onEditReminder: widget.onEditReminder,
                    onEndReminder: widget.onEndReminder,
                    onShareReminder: widget.onShareReminder,
                    onEndFlow: widget.onEndFlow,
                    onAppendToJournal: widget.onAppendToJournal,
                    onSaveFlow: widget.onSaveFlow,
                    initialEventDetailRestorationState:
                        _activeEventDetailRestoration,
                    onEventDetailRestorationChanged:
                        _handleEventDetailRestorationChanged,
                    shouldPreserveEventDetailRestorationOnClose:
                        _shouldPreserveEventDetailRestorationOnClose,
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
                      miniCalendarScrollController:
                          _miniCalendarScrollController,
                      onMiniCalendarManualScrollStart:
                          _handleMiniCalendarManualScrollStart,
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
                      onClose: _closeDayView,
                      onJumpToToday: _jumpToToday,
                      onOpenQuickAdd:
                          widget.onOpenQuickAdd ??
                          (btnCtx) async {
                            await CalendarPage.openQuickAddFromAnyContext(
                              btnCtx,
                            );
                          },
                      onOpenSearch:
                          widget.onOpenSearch ??
                          (btnCtx) async {
                            await CalendarPage.openSearchFromAnyContext(btnCtx);
                          },
                      onOpenProfile:
                          widget.onOpenProfile ??
                          (ctx) async {
                            await CalendarPage.openProfileFromAnyContext(ctx);
                          },
                      onOpenMenu:
                          widget.onOpenMenu ??
                          (ctx) async {
                            await CalendarPage.showActionsMenuFromAnyContext(
                              ctx,
                              includeNewNote: false,
                            );
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FontStyle.italic,
                                    fontFamily: _dayViewSerifFamily,
                                    fontFamilyFallback: _dayViewSerifFallback,
                                  ),
                                  gradient: blueGloss,
                                  maxLines: 1,
                                  softWrap: false,
                                  textAlign: TextAlign.center,
                                )
                              : Text(
                                  headerDateLabel,
                                  style: const TextStyle(
                                    color: Color(0xFFC7AA52),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FontStyle.italic,
                                    fontFamily: _dayViewSerifFamily,
                                    fontFamilyFallback: _dayViewSerifFallback,
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
                            activeLedgerFlowIds: activeLedgerFlowIds,
                            initialScrollOffset: _savedScrollOffset, // 🔧 NEW
                            initialFirstVisibleMinute:
                                widget.initialFirstVisibleMinute,
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
                            onRemoveCompletionBadge:
                                widget.onRemoveCompletionBadge,
                            onboardingEventClientEventId:
                                widget.onboardingEventClientEventId,
                            onboardingEventTargetKey:
                                widget.onboardingEventTargetKey,
                            onboardingObservedKey: widget.onboardingObservedKey,
                            onboardingJournalKey: widget.onboardingJournalKey,
                            onOnboardingEventOpened:
                                widget.onOnboardingEventOpened,
                            onOnboardingObservedJournalNext:
                                widget.onOnboardingObservedJournalNext,
                            onboardingClosingBannerBuilder:
                                widget.onboardingClosingBannerBuilder,
                            initialEventDetailRestorationState:
                                _activeEventDetailRestoration,
                            onEventDetailRestorationChanged:
                                _handleEventDetailRestorationChanged,
                            shouldPreserveEventDetailRestorationOnClose:
                                _shouldPreserveEventDetailRestorationOnClose,
                            resolveCurrentEventTarget:
                                _resolveCurrentEventTarget,
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
          ),
        );
      },
    );
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
  final Set<int> activeLedgerFlowIds;
  final int? initialFirstVisibleMinute;
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
    Map<String, dynamic>? metadata,
  })?
  onRecordCompletion;
  final Future<void> Function(String clientEventId)? onUnrecordCompletion;
  final Future<void> Function(String badgeId)? onRemoveCompletionBadge;
  final String? onboardingEventClientEventId;
  final GlobalKey? onboardingEventTargetKey;
  final GlobalKey? onboardingObservedKey;
  final GlobalKey? onboardingJournalKey;
  final VoidCallback? onOnboardingEventOpened;
  final VoidCallback? onOnboardingObservedJournalNext;
  final WidgetBuilder? onboardingClosingBannerBuilder;
  final EventDetailRestorationState? initialEventDetailRestorationState;
  final ValueChanged<EventDetailRestorationState?>?
  onEventDetailRestorationChanged;
  final bool Function()? shouldPreserveEventDetailRestorationOnClose;
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
    this.activeLedgerFlowIds = const <int>{},
    this.initialFirstVisibleMinute,
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
    this.onRemoveCompletionBadge,
    this.onboardingEventClientEventId,
    this.onboardingEventTargetKey,
    this.onboardingObservedKey,
    this.onboardingJournalKey,
    this.onOnboardingEventOpened,
    this.onOnboardingObservedJournalNext,
    this.onboardingClosingBannerBuilder,
    this.initialEventDetailRestorationState,
    this.onEventDetailRestorationChanged,
    this.shouldPreserveEventDetailRestorationOnClose,
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
  double? _cachedAvailableWidth;
  double? _cachedTextScale;
  double? _cachedSingleEventWidthFactor;
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
  String? _initialEventDetailRestoreKey;
  bool _initialEventDetailRestoreInFlight = false;
  final Set<int> _endingFlowIds = <int>{};
  int? get _focusStartMin => widget.focusStartMin;

  bool _beginEndFlowAction(int flowId) {
    if (_endingFlowIds.contains(flowId)) return false;
    setState(() {
      _endingFlowIds.add(flowId);
    });
    return true;
  }

  void _finishEndFlowAction(int flowId) {
    if (!_endingFlowIds.contains(flowId)) return;
    if (!mounted) {
      _endingFlowIds.remove(flowId);
      return;
    }
    setState(() {
      _endingFlowIds.remove(flowId);
    });
  }

  bool _isOnboardingTargetEvent(EventItem event) {
    final targetClientEventId = widget.onboardingEventClientEventId?.trim();
    if (targetClientEventId != null && targetClientEventId.isNotEmpty) {
      return event.clientEventId == targetClientEventId;
    }
    return false;
  }

  ButtonStyle _endButtonStyle(BuildContext context) {
    return withExpandedTouchTargets(
      context,
      OutlinedButton.styleFrom(
        side: BorderSide(color: _dayGold.withValues(alpha: 0.42), width: 0.7),
        backgroundColor: _dayGold.withValues(alpha: 0.06),
        foregroundColor: _dayGold,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
        shape: const StadiumBorder(),
      ),
    );
  }

  FlowData? _chromeFlowForId(int? flowId) => widget.flowIndex[flowId];

  bool _isRepeatingNoteFlowId(int? flowId) {
    final flow = _chromeFlowForId(flowId);
    return flow != null &&
        (hasRepeatingNoteFlowMetadata(flow.notes) ||
            (flow.isHidden && !flow.isReminder));
  }

  bool _isActionableFlowId(int? flowId) {
    if (flowId == null) return false;
    if (widget.activeLedgerFlowIds.contains(flowId)) return true;
    final flow = _chromeFlowForId(flowId);
    if (flow == null) return false;
    return flow.active && !hasRepeatingNoteFlowMetadata(flow.notes);
  }

  Widget _buildAddReflectionButton({
    required BuildContext routeContext,
    required BuildContext sheetContext,
    required DayViewSheetEventTarget target,
    required CompletionSourceType sourceType,
  }) {
    return OutlinedButton.icon(
      style: _endButtonStyle(sheetContext),
      onPressed: () => unawaited(
        _openReflectionForTarget(
          routeContext: routeContext,
          sheetContext: sheetContext,
          target: target,
          sourceType: sourceType,
        ),
      ),
      icon: KemeticGold.icon(Icons.edit_note_rounded),
      label: const Text('Add reflection'),
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
    _scheduleInitialEventDetailRestore();
  }

  @override
  void didUpdateWidget(covariant DayViewGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_computeFlowIndexHash(oldWidget.flowIndex) !=
        _computeFlowIndexHash(widget.flowIndex)) {
      _primeTrackSkyFlowData();
    }
    if (_eventDetailRestoreKey(oldWidget.initialEventDetailRestorationState) !=
        _eventDetailRestoreKey(widget.initialEventDetailRestorationState)) {
      _scheduleInitialEventDetailRestore();
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

  String? _eventDetailRestoreKey(EventDetailRestorationState? state) {
    if (state == null) return null;
    return '${state.kYear}:${state.kMonth}:${state.kDay}:'
        '${state.identityType}:${state.identityValue}';
  }

  bool _eventDetailStateTargetsThisGrid(EventDetailRestorationState state) {
    return state.kYear == widget.ky &&
        state.kMonth == widget.km &&
        state.kDay == widget.kd;
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
        !_eventDetailStateTargetsThisGrid(state) ||
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
    if (!_eventDetailStateTargetsThisGrid(state)) {
      _initialEventDetailRestoreInFlight = false;
      return;
    }

    final events = _sortedEventsForDay(
      notes: _dedupeNotesForUI(widget.notes),
      flowIndex: widget.flowIndex,
    );
    final target = eventDetailTargetFromRestorationState(
      state: state,
      events: events,
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
    if (kDebugMode) {
      debugPrint(
        '[DayView] detail sheet requested from initial restoration '
        'key=$key title="${target.event.title}"',
      );
    }
    _showEventDetail(target.event, initialTarget: target);
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
      unawaited(AppHaptics.selection());
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
        unawaited(AppHaptics.selection());
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

  List<({String heading, String body})> _dawnHouseRiteDetailSections(
    String detail,
  ) {
    final cleaned = _stripCidLines(detail).trim();
    if (cleaned.isEmpty) return const <({String heading, String body})>[];

    final sections = <({String heading, String body})>[];
    final headingPattern = RegExp(
      r"^(Purpose|Action|Water|Words|Quiet line|Ma'at act|Order act|Evening act|Steps|Provision|Optional|Drink|Privacy|Source|Lens|Cycle|Completion|Current ḥꜣw Context|Day Card|Season Instruction|Confidence|Variant|Outdoor)\s*:?\s*(.*)$",
      caseSensitive: false,
    );
    final buffer = <String>[];
    String? activeHeading;

    void flush() {
      final heading = activeHeading?.trim() ?? '';
      final body = buffer.join('\n').trim();
      final lowerHeading = heading.toLowerCase();
      buffer.clear();
      activeHeading = null;
      if (body.isEmpty ||
          lowerHeading == 'cycle' ||
          lowerHeading == 'completion') {
        return;
      }
      sections.add((heading: heading, body: body));
    }

    for (final rawLine in cleaned.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final match = headingPattern.firstMatch(line);
      if (match != null) {
        flush();
        final heading = match.group(1)!.trim();
        final lowerHeading = heading.toLowerCase();
        if (lowerHeading == 'cycle' || lowerHeading == 'completion') {
          activeHeading = null;
          continue;
        }
        activeHeading = heading;
        final inlineBody = match.group(2)?.trim();
        if (inlineBody != null && inlineBody.isNotEmpty) {
          buffer.add(inlineBody);
        }
        continue;
      }

      if (activeHeading == null) {
        sections.add((heading: '', body: line));
      } else {
        buffer.add(line);
      }
    }
    flush();

    return sections;
  }

  Widget _buildDawnHouseRiteDetailText(
    String detail, {
    _DayViewEventVisual? visual,
  }) {
    final sections = _dawnHouseRiteDetailSections(detail);
    if (sections.isEmpty) return const SizedBox.shrink();

    final headingStyle = TextStyle(
      color: visual?.sectionLabelText ?? const Color(0xFFFFD486),
      fontSize: 9,
      fontWeight: FontWeight.w600,
      letterSpacing: 2.0,
      height: 1.15,
      fontFamilyFallback: _dayViewSansFallback,
    );
    final bodyStyle = _detailBodyStyle(visual: visual);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in sections) ...[
          if (section.heading.isNotEmpty)
            Text(section.heading, style: headingStyle),
          if (section.heading.isNotEmpty) const SizedBox(height: 3),
          if (section.heading.toLowerCase() == 'words' ||
              section.heading.toLowerCase() == 'quiet line')
            Text(
              section.body,
              style: bodyStyle.copyWith(
                color: _dayViewSilver.withValues(alpha: 0.94),
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Text(section.body, style: bodyStyle),
          if (section != sections.last) const SizedBox(height: 12),
        ],
      ],
    );
  }

  void _scrollToSavedOrCurrentTime() {
    if (!_scrollController.hasClients || _hasScrolledToInitial) return;

    // 1) Focused event wins
    if (_focusStartMin != null) {
      final targetOffset = (_focusStartMin! * _kDayViewPixelsPerMinute) - 120;
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      _hasScrolledToInitial = true;
      return;
    }

    // 2) Saved scroll offset next
    if (widget.initialFirstVisibleMinute != null) {
      final targetOffset =
          (widget.initialFirstVisibleMinute! * _kDayViewPixelsPerMinute)
              .clamp(0.0, _scrollController.position.maxScrollExtent)
              .toDouble();
      _scrollController.jumpTo(targetOffset);
      _hasScrolledToInitial = true;
      return;
    }

    // 3) Saved scroll offset fallback
    if (widget.initialScrollOffset != null) {
      final clampedOffset = widget.initialScrollOffset!.clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(clampedOffset.toDouble());
      _hasScrolledToInitial = true;
      return;
    }

    // 4) Fallback: scroll to current time
    final now = DateTime.now().toLocal();
    final minutesSinceMidnight = now.hour * 60 + now.minute;
    final targetOffset =
        (minutesSinceMidnight * _kDayViewPixelsPerMinute) -
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
    List<PositionedEventBlock> base, {
    required double availableWidth,
    required double singleEventWidthFactor,
  }) {
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
          behaviorPayload: dragPreview.behaviorPayload,
        ),
      );
    }

    if (preview != null) {
      displayEvents.add(preview);
    }

    return EventLayoutEngine.layoutEventItems(
      events: displayEvents,
      availableWidth: availableWidth,
      columnGap: _kEventColumnGap,
      textScale: _layoutTextScale(context),
      day: widget.kd,
      singleEventWidthFactor: singleEventWidthFactor,
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
            color: Colors.black.withValues(alpha: 0.8),
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
          n.manualColor?.toARGB32(),
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
          e.value.color.toARGB32(),
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
    final flow = _chromeFlowForId(event.flowId);
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
    displayDetail = buildTrackSkyNarrativeSummary(
      title: event.title,
      category: event.category,
      fallbackGuidance: displayDetail,
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

  bool _usesTabletLandscapeLayout(BuildContext context) {
    final media = MediaQuery.of(context);
    return media.orientation == Orientation.landscape &&
        media.size.shortestSide >= 600;
  }

  double _timelineAvailableWidthFor(double width) {
    return math.max(width - _kTimelineLabelWidth - _kTimelineRightPadding, 0.0);
  }

  double _singleEventWidthFactor(BuildContext context) {
    return _usesTabletLandscapeLayout(context) ? 1.0 : _kSingleEventWidthFactor;
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final availableWidth = _timelineAvailableWidthFor(layoutWidth);
        final textScale = _layoutTextScale(context);
        final singleEventWidthFactor = _singleEventWidthFactor(context);

        // ✅ NEW: Dedupe notes before rendering to handle legacy duplicates
        final dedupedNotes = _dedupeNotesForUI(widget.notes);

        // 🔧 OPTIMIZATION: Only recalculate layout if inputs or constraints changed
        final notesHash = _computeNotesHash(dedupedNotes);
        final flowHash = _computeFlowIndexHash(widget.flowIndex);
        if (_cachedBlocks == null ||
            _cachedNotesHash != notesHash ||
            _cachedFlowHash != flowHash ||
            _cachedAvailableWidth != availableWidth ||
            _cachedTextScale != textScale ||
            _cachedSingleEventWidthFactor != singleEventWidthFactor) {
          if (kDebugMode) {
            final originalCount = widget.notes.length;
            final dedupedCount = dedupedNotes.length;
            if (originalCount != dedupedCount) {
              debugPrint(
                '[DayView] Deduplicated events: $originalCount → $dedupedCount (removed ${originalCount - dedupedCount} duplicates)',
              );
            }
          }

          _cachedBlocks = EventLayoutEngine.layoutEventsForDay(
            notes: dedupedNotes, // ✅ Use deduped notes
            flowIndex: widget.flowIndex,
            availableWidth: availableWidth,
            columnGap: _kEventColumnGap,
            textScale: textScale,
            day: widget.kd,
            singleEventWidthFactor: singleEventWidthFactor,
          );
          _cachedNotesHash = notesHash;
          _cachedFlowHash = flowHash;
          _cachedAvailableWidth = availableWidth;
          _cachedTextScale = textScale;
          _cachedSingleEventWidthFactor = singleEventWidthFactor;
        }

        _displayBlocks = _buildDisplayBlocks(
          _cachedBlocks ?? [],
          availableWidth: availableWidth,
          singleEventWidthFactor: singleEventWidthFactor,
        );

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
                    padding: EdgeInsets.only(
                      bottom: bottomPaddingAboveGlobalChrome(context, 24),
                    ),
                    cacheExtent: 600, // 🔧 OPTIMIZATION: Cache more items
                    itemCount: 24,
                    itemBuilder: (context, hour) {
                      return _buildHourRow(hour);
                    },
                  );
                },
                onWillAcceptWithDetails: (_) => true,
                onMove: (details) {
                  final snapped = _snappedMinuteFromGlobalOffset(
                    details.offset,
                  );
                  if (snapped == null) return;
                  _dragPreviewEvent ??= details.data.event;
                  if (snapped == _dragPreviewStartMin) return;
                  _dragPreviewStartMin = snapped;
                  _lastDragSnappedMinute = snapped;
                  unawaited(AppHaptics.selection());
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

                  if (committedMinute == null &&
                      _lastDragSnappedMinute != null) {
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
      },
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
        color: hour.isEven ? const Color(0xFF070604) : const Color(0xFF080705),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF8A743C).withValues(alpha: 0.18),
            width: 0.6,
          ),
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
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.2,
                color: _dayViewSilverDim.withValues(alpha: 0.96),
                fontFamilyFallback: _dayViewSansFallback,
              ),
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
                            color: _dayGold.withValues(alpha: 0.08),
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
                          color: _dayGold.withValues(alpha: 0.85),
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

          // Rows paint in order, so a later hour's background covers any
          // previous-row overflow. Repaint the visible continuation above the
          // current row background; tap/drag handling stays in the proxy layer.
          ..._buildOverflowVisualsForHour(hour),

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

  List<Widget> _buildOverflowVisualsForHour(int hour) {
    final rowStart = hour * 60.0;
    final rowEnd = rowStart + 60.0;
    final spillBlocks =
        _displayBlocks.where((block) {
          if (_isPreviewBlock(block)) return false;
          final visualStart = block.event.startMin.toDouble();
          final visualEnd = visualStart + _eventVisualHeight(block.event);
          return visualStart < rowStart && visualEnd > rowStart;
        }).toList()..sort((a, b) {
          final leftCmp = a.leftOffset.compareTo(b.leftOffset);
          if (leftCmp != 0) return leftCmp;
          return _compareEventItemsBySchedule(a.event, b.event);
        });

    if (spillBlocks.isEmpty) return const [];

    return [
      for (final block in spillBlocks)
        Builder(
          builder: (_) {
            final visualStart = block.event.startMin.toDouble();
            final visualEnd = visualStart + _eventVisualHeight(block.event);
            final visibleHeight =
                math.min(visualEnd, rowEnd) - math.max(visualStart, rowStart);
            if (visibleHeight <= 0) return const SizedBox.shrink();
            final visualHeight = visualEnd - visualStart;
            final yOffset = rowStart - visualStart;
            final visualWidth = block.width + 4;

            return Positioned(
              key: dayViewOverflowVisualKey(
                _eventIdentityKey(block.event),
                hour,
              ),
              left: _kTimelineLabelWidth + block.leftOffset,
              top: 0,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: SizedBox(
                    width: visualWidth,
                    height: visibleHeight,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        minWidth: visualWidth,
                        maxWidth: visualWidth,
                        minHeight: visualHeight,
                        maxHeight: visualHeight,
                        child: Transform.translate(
                          offset: Offset(0, -yOffset),
                          child: _buildEventBlock(block, isPreview: false),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
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
          unawaited(AppHaptics.mediumImpact());
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
        unawaited(AppHaptics.selection());
        if (kDebugMode) {
          debugPrint('[DayView] overflow proxy drag title="${event.title}"');
        }
        setState(() {});
      },
      onDraggableCanceled: (_, _) {
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
    unawaited(AppHaptics.mediumImpact());
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
      unawaited(AppHaptics.selection());
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
        unawaited(AppHaptics.selection());
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

    final isOnboardingTarget = _isOnboardingTargetEvent(event);
    Widget wrapOnboardingTarget(Widget child) {
      final key = widget.onboardingEventTargetKey;
      if (!isOnboardingTarget || key == null) return child;
      return KeyedSubtree(
        key: key,
        child: _DayViewOnboardingPulse(child: child),
      );
    }

    void openEventDetail() {
      if (isOnboardingTarget) {
        widget.onOnboardingEventOpened?.call();
      }
      _showEventDetail(event);
    }

    if (!_isEventDraggable(event)) {
      final visual = _buildEventBlock(block, isPreview: false);
      return wrapOnboardingTarget(
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: openEventDetail,
          onLongPress: () {
            unawaited(AppHaptics.mediumImpact());
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("This event can't be moved"),
                duration: Duration(milliseconds: 1200),
              ),
            );
          },
          child: buildHitTarget(visual),
        ),
      );
    }

    Widget buildVisual({double? opacity}) {
      final visual = _buildEventBlock(block, isPreview: false);
      if (opacity == null) return visual;
      return Opacity(opacity: opacity, child: visual);
    }

    final draggable = LongPressDraggable<_DragPayload>(
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
        unawaited(AppHaptics.selection());
        if (kDebugMode) {
          debugPrint('[DayView] onDragStarted title="${event.title}"');
        }
        setState(() {});
      },
      onDraggableCanceled: (_, _) {
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
        onTap: openEventDetail,
        child: buildHitTarget(buildVisual()),
      ),
    );
    return wrapOnboardingTarget(draggable);
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
    final flow = _chromeFlowForId(event.flowId);
    final isTrackSky = _isTrackSkyFlowName(flow?.name);
    final isDawnHouseRite = _isDawnHouseRiteFlowName(flow?.name);
    final isEveningThresholdRite = _isEveningThresholdRiteFlowName(flow?.name);
    final isTheWeighing = _isTheWeighingFlowName(flow?.name);
    final trackSkySpec = isTrackSky ? _trackSkyCardSpecForEvent(event) : null;

    final int durationMinutes = (event.endMin - event.startMin).clamp(15, 180);
    final double height = _eventVisualHeight(event);

    final borderRadius = BorderRadius.circular(
      isTrackSky || isDawnHouseRite || isEveningThresholdRite || isTheWeighing
          ? 7
          : 6,
    );

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

    if (isDawnHouseRite) {
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
              color: const Color(
                0xFFFFB765,
              ).withValues(alpha: isPreview ? 0.08 : 0.16),
              blurRadius: kIsWeb ? 10 : 14,
              spreadRadius: -3,
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _dawnHouseRiteCardGradient,
                  borderRadius: borderRadius,
                  border: Border.all(
                    color: const Color(
                      0xFFFFD08A,
                    ).withValues(alpha: isPreview ? 0.68 : 0.9),
                    width: 0.9,
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            const Color(0x9C090914),
                            const Color(0x63090914),
                            const Color(0x16090914),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.38, 0.68, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 6,
                    child: Opacity(
                      opacity: isPreview ? 0.78 : 1.0,
                      child: _buildDawnHouseRiteAccent(
                        compact: durationMinutes < 80,
                        size: math.min(height - 16, 25),
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

    if (isEveningThresholdRite) {
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
              color: const Color(
                0xFF66D7CF,
              ).withValues(alpha: isPreview ? 0.07 : 0.15),
              blurRadius: kIsWeb ? 10 : 14,
              spreadRadius: -3,
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _eveningThresholdRiteCardGradient,
                  borderRadius: borderRadius,
                  border: Border.all(
                    color: const Color(
                      0xFF7FE0D4,
                    ).withValues(alpha: isPreview ? 0.58 : 0.82),
                    width: 0.9,
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            const Color(0xB0030611),
                            const Color(0x74030611),
                            const Color(0x24030611),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.38, 0.68, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: durationMinutes < 80 ? 2 : 2.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF8CDAD1).withValues(alpha: 0.08),
                            const Color(0xFF8CDAD1).withValues(alpha: 0.42),
                            const Color(0xFFFFE4A3).withValues(alpha: 0.22),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 6,
                    child: Opacity(
                      opacity: isPreview ? 0.78 : 1.0,
                      child: _buildEveningThresholdRiteAccent(
                        compact: durationMinutes < 80,
                        size: math.min(height - 16, 25),
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

    if (isTheWeighing) {
      return Container(
        width: block.width,
        height: height,
        margin: const EdgeInsets.only(right: 4, bottom: 2),
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: _theWeighingCardGradient,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isPreview ? 0.16 : 0.28),
              blurRadius: kIsWeb ? 8 : 12,
              spreadRadius: 0.5,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(
            color: const Color(
              0xFFF5E8CB,
            ).withValues(alpha: isPreview ? 0.28 : 0.52),
          ),
        ),
        clipBehavior: Clip.hardEdge,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        child: _buildEventTextContents(
          event,
          durationMinutes,
          isPreview: isPreview,
        ),
      );
    }

    final visual = _dayViewVisualForEvent(
      event,
      flow,
      isReminder: event.isReminder,
      isNutrition: event.detail != null && event.detail!.contains('Source:'),
    );
    return Container(
      width: block.width,
      height: height,
      margin: const EdgeInsets.only(right: 4, bottom: 2),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isPreview ? 0.12 : 0.26),
            blurRadius: 10,
            spreadRadius: -5,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge, // ✅ Prevent overflow
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color.alphaBlend(
                      visual.wash.withValues(alpha: isPreview ? 0.066 : 0.10),
                      visual.base,
                    ),
                    Color.alphaBlend(
                      visual.wash.withValues(alpha: isPreview ? 0.030 : 0.05),
                      visual.base,
                    ),
                    visual.base,
                    _dayViewBase,
                  ],
                  stops: const [0.0, 0.42, 0.73, 1.0],
                ),
                border: Border.all(
                  color: visual.source.withValues(
                    alpha: isPreview ? 0.14 : 0.22,
                  ),
                  width: isPreview ? 0.65 : 0.55,
                ),
                borderRadius: borderRadius,
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: visual.source.withValues(alpha: isPreview ? 0.46 : 0.64),
              ),
              child: const SizedBox(width: 2.5),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              event.isReminder ? 9 : 10,
              event.isReminder ? 4 : 4,
              6,
              4,
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

  /// ✅ FIX #2B: Separate method for text content with empty title handling
  Widget _buildEventTextContents(
    EventItem event,
    int durationMinutes, {
    bool isPreview = false,
  }) {
    final flow = _chromeFlowForId(event.flowId);
    final bool hasFlow = flow != null;
    final bool isTrackSky = _isTrackSkyFlowName(flow?.name);
    final bool isDawnHouseRite = _isDawnHouseRiteFlowName(flow?.name);
    final bool isEveningThresholdRite = _isEveningThresholdRiteFlowName(
      flow?.name,
    );
    final bool isTheWeighing = _isTheWeighingFlowName(flow?.name);
    final bool isGraphicFlow =
        isTrackSky ||
        isDawnHouseRite ||
        isEveningThresholdRite ||
        isTheWeighing;
    final trackSkySpec = isTrackSky ? _trackSkyCardSpecForEvent(event) : null;
    final isNutrition =
        event.detail != null && event.detail!.contains('Source:');
    final visual = _dayViewVisualForEvent(
      event,
      flow,
      isReminder: event.isReminder,
      isNutrition: isNutrition,
    );
    final isMaatFlow = _maatFlowCompletionContextForEvent(event, flow) != null;
    final flowLabel = _dayViewTimelineFlowLabel(
      event,
      flow,
      isMaatFlow: isMaatFlow,
      isReminder: event.isReminder,
      isNutrition: isNutrition,
    );

    final showTitle = event.title.trim().isNotEmpty;
    final showPreviewLabel = !isGraphicFlow || (hasFlow && !event.isReminder);
    final trackSkyFlowNameColor = _dayGold.withValues(
      alpha: isPreview ? 0.92 : 1.0,
    );
    final titleColor = isTrackSky
        ? trackSkySpec!.titleColor.withValues(alpha: isPreview ? 0.94 : 1.0)
        : isDawnHouseRite
        ? const Color(0xFFFFF6E3).withValues(alpha: isPreview ? 0.92 : 1.0)
        : isEveningThresholdRite
        ? const Color(0xFFF2F0FF).withValues(alpha: isPreview ? 0.92 : 1.0)
        : isTheWeighing
        ? const Color(0xFFFFF8E8).withValues(alpha: isPreview ? 0.92 : 1.0)
        : event.isReminder
        ? visual.title.withValues(alpha: isPreview ? 0.72 : 0.88)
        : visual.title.withValues(alpha: isPreview ? 0.74 : 0.9);
    final flowColor = !isGraphicFlow
        ? visual.category.withValues(alpha: isPreview ? 0.52 : 0.68)
        : null;
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
      Gradient? gradient,
    }) {
      final softWrap = maxLines != 1;
      if (gradient != null) {
        return GlossyText(
          text: text,
          style: style,
          gradient: gradient,
          maxLines: maxLines,
          overflow: overflow,
          softWrap: softWrap,
        );
      }
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
          softWrap: softWrap,
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
          Text(
            text,
            style: fillStyle,
            maxLines: maxLines,
            overflow: overflow,
            softWrap: softWrap,
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min, // ✅ Don't expand unnecessarily
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Compact preview label only; detail/body/location belongs in the sheet.
        if (showPreviewLabel) ...[
          isTrackSky
              ? buildTrackSkyText(
                  flow!.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: trackSkyFlowNameColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  gradient: _trackSkyFlowGoldGloss,
                )
              : isDawnHouseRite
              ? buildTrackSkyText(
                  flow!.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: trackSkyFlowNameColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  gradient: _dawnHouseRiteFlowGloss,
                )
              : isEveningThresholdRite
              ? buildTrackSkyText(
                  flow!.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: trackSkyFlowNameColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  gradient: _eveningThresholdRiteFlowGloss,
                )
              : isTheWeighing
              ? buildTrackSkyText(
                  flow!.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: trackSkyFlowNameColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  gradient: _theWeighingFlowGloss,
                )
              : Text(
                  flowLabel,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.55,
                    color: flowColor,
                    fontFamilyFallback: _dayViewSansFallback,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          SizedBox(height: isGraphicFlow ? 1 : 2),
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
              : isDawnHouseRite
              ? buildTrackSkyText(
                  event.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                  maxLines: titleMaxLines,
                  overflow: TextOverflow.ellipsis,
                )
              : isEveningThresholdRite
              ? buildTrackSkyText(
                  event.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                  maxLines: titleMaxLines,
                  overflow: TextOverflow.ellipsis,
                )
              : isTheWeighing
              ? buildTrackSkyText(
                  event.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                  maxLines: titleMaxLines,
                  overflow: TextOverflow.ellipsis,
                )
              : Text(
                  event.title,
                  style: TextStyle(
                    fontSize: event.isReminder ? 13.5 : 13.8,
                    height: 1.08,
                    fontWeight: FontWeight.w600,
                    fontFamily: _dayViewSerifFamily,
                    fontFamilyFallback: _dayViewSerifFallback,
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
              : isDawnHouseRite
              ? buildTrackSkyText(
                  hasFlow ? '(flow block)' : '(scheduled)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: const Color(
                      0xFFFFE8C6,
                    ).withValues(alpha: isPreview ? 0.78 : 0.9),
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : isEveningThresholdRite
              ? buildTrackSkyText(
                  hasFlow ? '(flow block)' : '(scheduled)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: const Color(
                      0xFFDDEAFF,
                    ).withValues(alpha: isPreview ? 0.78 : 0.9),
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : isTheWeighing
              ? buildTrackSkyText(
                  hasFlow ? '(flow block)' : '(scheduled)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: const Color(
                      0xFFFFF8E8,
                    ).withValues(alpha: isPreview ? 0.78 : 0.9),
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : Text(
                  // Fallback so you don't get giant red nothing-brick
                  hasFlow ? '(flow block)' : '(scheduled)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    fontFamily: _dayViewSerifFamily,
                    fontFamilyFallback: _dayViewSerifFallback,
                    color: visual.title.withValues(
                      alpha: isPreview ? 0.56 : 0.76,
                    ),
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
      ],
    );
  }

  Widget _buildNowLine() {
    return Container(height: 1, color: _dayGold.withValues(alpha: 0.42));
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

  CompletionSourceType _completionSourceTypeForEvent(
    EventItem event,
    FlowData? flow,
    _MaatFlowCompletionContext? completionContext,
  ) {
    if (completionContext != null) return CompletionSourceType.maatFlow;
    if (event.isReminder) return CompletionSourceType.reminder;
    final category = event.category?.trim().toLowerCase() ?? '';
    if (category.contains('itinerary') || category.contains('travel')) {
      return CompletionSourceType.itinerary;
    }
    if (flow != null && !_isRepeatingNoteFlowId(event.flowId)) {
      return CompletionSourceType.userFlow;
    }
    if (event.flowId != null || event.clientEventId != null) {
      return CompletionSourceType.calendarEvent;
    }
    return CompletionSourceType.note;
  }

  String _completionIdentityForEvent(EventItem event) {
    return calendarCompletionIdentity(
      eventId: event.id,
      clientEventId: event.clientEventId,
      reminderId: event.reminderId,
      fallback: _eventIdentityKey(event),
    );
  }

  String _completionBadgeIdForEvent(
    EventItem event, {
    required CompletionSourceType sourceType,
  }) {
    return calendarCompletionBadgeId(
      identity: _completionIdentityForEvent(event),
      sourceType: sourceType,
    );
  }

  String _buildBadgeToken(
    EventItem event, {
    required int ky,
    required int km,
    required int kd,
    CompletionStatus completionStatus = CompletionStatus.observed,
    CompletionSourceType sourceType = CompletionSourceType.calendarEvent,
  }) {
    final g = KemeticMath.toGregorian(ky, km, kd);
    final dayStart = DateTime(g.year, g.month, g.day);
    final start = dayStart.add(Duration(minutes: event.startMin));
    final end = dayStart.add(Duration(minutes: event.endMin));
    final rawDesc = event.detail?.trim() ?? '';
    final cleanedDesc = rawDesc.isEmpty ? null : _stripCidLines(rawDesc);
    final descForToken = (cleanedDesc == null || cleanedDesc.isEmpty)
        ? null
        : cleanedDesc;
    return buildCalendarCompletionBadgeToken(
      identity: _completionIdentityForEvent(event),
      sourceType: sourceType,
      completionStatus: completionStatus,
      eventId: event.clientEventId ?? event.id ?? event.reminderId,
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
    CompletionStatus completionStatus = CompletionStatus.observed,
    CompletionSourceType sourceType = CompletionSourceType.calendarEvent,
    bool triggerHaptic = true,
  }) async {
    final cb = widget.onAppendToJournal;
    if (cb == null) return;

    final token = _buildBadgeToken(
      event,
      ky: ky,
      km: km,
      kd: kd,
      completionStatus: completionStatus,
      sourceType: sourceType,
    );
    try {
      await cb('$token ');
      if (triggerHaptic) {
        unawaited(AppHaptics.productiveAction());
      }
    } catch (_) {
      // ignore errors silently to avoid blocking UI
    }
  }

  Future<void> _appendCompletionContinuity(
    DayViewSheetEventTarget target,
    CompletionStatus status, {
    required CompletionSourceType sourceType,
    bool triggerHaptic = true,
  }) async {
    await _quickAddToJournal(
      target.event,
      ky: target.ky,
      km: target.km,
      kd: target.kd,
      completionStatus: status,
      sourceType: sourceType,
      triggerHaptic: triggerHaptic,
    );
  }

  Future<void> _removeCompletionContinuity(
    DayViewSheetEventTarget target, {
    required CompletionSourceType sourceType,
  }) async {
    final cb = widget.onRemoveCompletionBadge;
    if (cb == null) return;
    await cb(_completionBadgeIdForEvent(target.event, sourceType: sourceType));
  }

  CalendarReflectionContext _reflectionContextForTarget(
    DayViewSheetEventTarget target, {
    required CompletionSourceType sourceType,
    CompletionStatus completionStatus = CompletionStatus.none,
  }) {
    final event = target.event;
    final g = KemeticMath.toGregorian(target.ky, target.km, target.kd);
    final dayStart = DateTime(g.year, g.month, g.day);
    return CalendarReflectionContext(
      sourceType: sourceType,
      sourceId: _completionIdentityForEvent(event),
      title: event.title,
      calendarDate: dayStart,
      occurrenceId: event.clientEventId ?? event.id ?? event.reminderId,
      eventId: event.clientEventId ?? event.id ?? event.reminderId,
      flowId: event.flowId,
      start: dayStart.add(Duration(minutes: event.startMin)),
      end: dayStart.add(Duration(minutes: event.endMin)),
      color: event.color,
      completionStatus: completionStatus,
      reflectionPrompt: resolveCalendarReflectionPrompt(
        sourceType: sourceType,
        title: event.title,
        detail: event.detail,
        behaviorPayload: event.behaviorPayload,
      ),
    );
  }

  Future<void> _openReflectionForTarget({
    required BuildContext routeContext,
    required BuildContext sheetContext,
    required DayViewSheetEventTarget target,
    required CompletionSourceType sourceType,
  }) async {
    final identity = _completionIdentityForEvent(target.event);
    Navigator.pop(sheetContext);
    final record = await const CalendarCompletionLocalStore().load(identity);
    if (!routeContext.mounted) return;
    final reflectionContext = _reflectionContextForTarget(
      target,
      sourceType: sourceType,
      completionStatus: record.completionStatus,
    );
    routeContext.go(
      reflectionContext.journalRouteLocation,
      extra: reflectionContext,
    );
  }

  Future<CompletionStatus> _loadCalendarCompletionStatus(
    DayViewSheetEventTarget target,
  ) async {
    final clientEventId = target.event.clientEventId?.trim();
    final flowId = target.event.flowId;
    final user = Supabase.instance.client.auth.currentUser;
    if (clientEventId == null ||
        clientEventId.isEmpty ||
        flowId == null ||
        user == null) {
      return CompletionStatus.none;
    }

    final row = await Supabase.instance.client
        .from('user_event_completions')
        .select('metadata')
        .eq('user_id', user.id)
        .eq('client_event_id', clientEventId)
        .maybeSingle();
    if (row == null) return CompletionStatus.none;
    final metadata = row['metadata'];
    if (metadata is Map) {
      final normalized = CompletionStatusX.fromWireName(
        metadata['completion_status']?.toString() ??
            metadata['status']?.toString(),
      );
      if (normalized != CompletionStatus.none) return normalized;
    }
    return CompletionStatus.observed;
  }

  Future<void> _recordCalendarCompletion(
    DayViewSheetEventTarget target,
    CompletionStatus status, {
    required CompletionSourceType sourceType,
    required FlowData? flow,
  }) async {
    if (status == CompletionStatus.none) {
      await _clearCalendarCompletion(target, sourceType: sourceType);
      return;
    }
    final clientEventId = target.event.clientEventId?.trim();
    final flowId = target.event.flowId;
    if (clientEventId == null || clientEventId.isEmpty || flowId == null) {
      return;
    }
    final completedOnDate = DateUtils.dateOnly(
      KemeticMath.toGregorian(target.ky, target.km, target.kd),
    );
    final metadata = calendarCompletionMetadata(
      completionStatus: status,
      sourceType: sourceType,
      completedOnDate: completedOnDate,
      flowTitle: flow?.name,
      eventTitle: target.event.title,
    );
    final callback = widget.onRecordCompletion;
    if (callback != null) {
      await callback(
        clientEventId: clientEventId,
        flowId: flowId,
        completedOnDate: completedOnDate,
        metadata: metadata,
      );
    } else {
      await UserEventsRepo(Supabase.instance.client).recordEventCompletion(
        clientEventId: clientEventId,
        flowId: flowId,
        completedOnDate: completedOnDate,
        metadata: metadata,
      );
    }
  }

  Future<void> _clearCalendarCompletion(
    DayViewSheetEventTarget target, {
    required CompletionSourceType sourceType,
  }) async {
    final clientEventId = target.event.clientEventId?.trim();
    if (clientEventId != null && clientEventId.isNotEmpty) {
      final callback = widget.onUnrecordCompletion;
      if (callback != null) {
        await callback(clientEventId);
      } else {
        await UserEventsRepo(
          Supabase.instance.client,
        ).unrecordEventCompletion(clientEventId);
      }
    }
    await _removeCompletionContinuity(target, sourceType: sourceType);
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

  TextStyle _detailCategoryStyle(_DayViewEventVisual visual) => TextStyle(
    color: visual.category,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.0,
    height: 1.15,
    fontFamilyFallback: _dayViewSansFallback,
  );

  TextStyle _detailTitleStyle(_DayViewEventVisual visual) => TextStyle(
    color: visual.title,
    fontSize: 21,
    fontWeight: FontWeight.w500,
    height: 1.16,
    fontFamily: _dayViewSerifFamily,
    fontFamilyFallback: _dayViewSerifFallback,
  );

  TextStyle _detailBodyStyle({
    _DayViewEventVisual? visual,
    bool italic = false,
  }) => TextStyle(
    color: visual?.bodyText ?? _dayViewWarmStone.withValues(alpha: 0.9),
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.58,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    fontFamily: _dayViewSerifFamily,
    fontFamilyFallback: _dayViewSerifFallback,
  );

  Widget _buildDetailSectionLabel(String label, {_DayViewEventVisual? visual}) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color:
            visual?.sectionLabelText ??
            _dayViewBronzeLabel.withValues(alpha: 0.56),
        fontSize: 9,
        fontWeight: FontWeight.w600,
        height: 1.15,
        letterSpacing: 2.0,
        fontFamilyFallback: _dayViewSansFallback,
      ),
    );
  }

  Widget _buildDetailTimeLine(String text, _DayViewEventVisual visual) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.access_time_rounded,
          size: 13,
          color: visual.metaText.withValues(alpha: 0.78),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: visual.metaText,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 1.25,
            fontStyle: FontStyle.italic,
            fontFamily: _dayViewSerifFamily,
            fontFamilyFallback: _dayViewSerifFallback,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailFlowNameLine(String text, _DayViewEventVisual visual) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: visual.supportText,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.25,
        fontStyle: FontStyle.italic,
        fontFamily: _dayViewSerifFamily,
        fontFamilyFallback: _dayViewSerifFallback,
      ),
    );
  }

  Widget _buildDetailExternalActionButton(
    _DayViewExternalAction action,
    _DayViewEventVisual visual,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () async {
        final handled = await launchExternalTarget(
          action.target,
          fallbackToMaps: action.fallbackToMaps,
        );
        if (!handled && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open this link.')),
          );
        }
      },
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: visual.actionButtonFill,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: visual.actionButtonBorder, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: visual.actionIconFill,
                shape: BoxShape.circle,
              ),
              child: Icon(action.icon, size: 10, color: visual.actionIconGlyph),
            ),
            const SizedBox(width: 8),
            Text(
              action.label,
              style: TextStyle(
                color: visual.actionButtonText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: _dayViewSerifFamily,
                fontFamilyFallback: _dayViewSerifFallback,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventDetailSheetPage({
    required DayViewSheetEventTarget target,
    bool scrollable = true,
    bool includeOnboardingKeys = true,
    Object? completionReloadSignal,
  }) {
    final currentEvent = target.event;
    final flow = _chromeFlowForId(currentEvent.flowId);
    final bool isReminder = currentEvent.isReminder;
    final bool isNutrition =
        currentEvent.detail != null && currentEvent.detail!.contains('Source:');
    final bool isTrackSky = _isTrackSkyFlowName(flow?.name);
    final bool isDawnHouseRite = _isDawnHouseRiteFlowName(flow?.name);
    final bool isEveningThresholdRite = _isEveningThresholdRiteFlowName(
      flow?.name,
    );
    final bool isTheWeighing = _isTheWeighingFlowName(flow?.name);
    final bool isOfferingTable = _isOfferingTableFlowName(flow?.name);
    final bool isTheTending = _isTheTendingFlowName(flow?.name);
    final bool isKeptWord = _isKeptWordFlowName(flow?.name);
    final bool isTheCourse = _isTheCourseFlowName(flow?.name);
    final bool isTheWag = _isTheWagFlowName(flow?.name);
    final bool isDecanWatch = _isDecanWatchFlowName(flow?.name);
    final bool isDaysOutsideYear = _isDaysOutsideYearFlowName(flow?.name);
    final bool isOpenHand = _isOpenHandFlowName(flow?.name);
    final bool isDjed = _isDjedFlowName(flow?.name);
    final tendingEvent = isTheTending
        ? theTendingEventForEvent(title: currentEvent.title)
        : null;
    final keptWordEvent = isKeptWord
        ? keptWordEventForEvent(title: currentEvent.title)
        : null;
    final courseEvent = isTheCourse
        ? courseEventForEvent(title: currentEvent.title)
        : null;
    final wagEvent = isTheWag
        ? wagEventForEvent(title: currentEvent.title)
        : null;
    final daysOutsideEvent = isDaysOutsideYear
        ? daysOutsideEventForEvent(title: currentEvent.title)
        : null;
    final openHandEvent = isOpenHand
        ? openHandEventForEvent(title: currentEvent.title)
        : null;
    final djedEvent = isDjed
        ? djedEventForEvent(title: currentEvent.title)
        : null;
    final courseContext = courseEvent == null
        ? null
        : courseContextForKemeticDate(
            kYear: target.ky,
            kMonth: target.km,
            kDay: target.kd,
          );
    final decanWatchContext = isDecanWatch
        ? courseContextForKemeticDate(
            kYear: target.ky,
            kMonth: target.km,
            kDay: target.kd,
          )
        : null;
    final completionContext = _maatFlowCompletionContextForEvent(
      currentEvent,
      flow,
    );
    final libraryCta = _maatLibraryCtaPayloadForEvent(currentEvent);
    final enableRitualCompletionFeedback =
        currentEvent.flowId != null && !isNutrition;

    final visual = _dayViewMatteDetailVisual(
      _dayViewVisualForEvent(
        currentEvent,
        flow,
        isReminder: isReminder,
        isNutrition: isNutrition,
      ),
    );
    final isMaatFlow = completionContext != null;
    final detailCategoryLabel = _dayViewFlowLabel(
      currentEvent,
      flow,
      isMaatFlow: isMaatFlow,
      isReminder: isReminder,
      isNutrition: isNutrition,
    );
    final externalAction = _dayViewExternalActionForEvent(currentEvent);
    final showDetailLocation = _dayViewShouldShowDetailLocation(
      currentEvent,
      externalAction,
    );
    final completionPickerStyle = _dayViewCompletionPickerStyle(visual);

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(detailCategoryLabel, style: _detailCategoryStyle(visual)),
        const SizedBox(height: 8),
        Text(
          currentEvent.title.trim().isEmpty
              ? 'Scheduled block'
              : currentEvent.title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: _detailTitleStyle(visual),
        ),
        const SizedBox(height: 8),
        _buildDetailTimeLine(
          _formatTimeRange(currentEvent.startMin, currentEvent.endMin),
          visual,
        ),
        if (flow != null) ...[
          const SizedBox(height: 4),
          _buildDetailFlowNameLine(flow.name, visual),
        ],
        if (showDetailLocation) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _launchLocation(currentEvent.location!.trim()),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: visual.metaText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    currentEvent.location!,
                    style: TextStyle(
                      color: visual.metaText,
                      decoration: TextDecoration.underline,
                      fontSize: 12,
                      height: 1.35,
                      fontFamily: _dayViewSerifFamily,
                      fontFamilyFallback: _dayViewSerifFallback,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (externalAction != null) ...[
          const SizedBox(height: 10),
          _buildDetailExternalActionButton(externalAction, visual),
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
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final rawDisplayDetail = isTrackSky
                  ? _trackSkyDisplayDetail(
                      currentEvent,
                      ky: target.ky,
                      km: target.km,
                      kd: target.kd,
                    )
                  : isTheCourse && courseEvent != null
                  ? courseDetailText(
                      courseEvent,
                      lens: courseLensFromNotes(flow?.notes),
                      context: courseContext,
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
              final displayDetail = _dayViewStripStandaloneExternalTargetLines(
                rawDisplayDetail,
                externalAction,
              );
              if (displayDetail.isEmpty || _looksLikeCidDetail(displayDetail)) {
                return const SizedBox.shrink();
              }

              Widget detailContent;
              if (isDawnHouseRite ||
                  isEveningThresholdRite ||
                  isTheWeighing ||
                  isOfferingTable ||
                  isTheTending ||
                  isKeptWord ||
                  isTheCourse ||
                  isTheWag ||
                  isDecanWatch ||
                  isDaysOutsideYear ||
                  isOpenHand ||
                  isDjed) {
                detailContent = _buildDawnHouseRiteDetailText(
                  displayDetail,
                  visual: visual,
                );
              } else {
                detailContent = RichText(
                  text: TextSpan(
                    style: _detailBodyStyle(visual: visual),
                    children: _buildTextSpans(displayDetail),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailSectionLabel('Purpose', visual: visual),
                  const SizedBox(height: 6),
                  detailContent,
                ],
              );
            },
          ),
        ],
        if (currentEvent.flowId != null &&
            tendingEvent != null &&
            tendingEvent.localPrompt != TheTendingLocalPromptKind.none) ...[
          const SizedBox(height: 12),
          _TheTendingLocalNotesPanel(
            flowId: currentEvent.flowId!,
            event: tendingEvent,
          ),
        ],
        if (currentEvent.flowId != null &&
            keptWordEvent != null &&
            keptWordEvent.localPrompt != KeptWordLocalPromptKind.none) ...[
          const SizedBox(height: 12),
          _KeptWordLocalNotesPanel(
            flowId: currentEvent.flowId!,
            event: keptWordEvent,
          ),
        ],
        if (currentEvent.flowId != null &&
            wagEvent != null &&
            wagEvent.localPrompt != WagLocalPromptKind.none) ...[
          const SizedBox(height: 12),
          _TheWagLocalNotesPanel(flowId: currentEvent.flowId!, event: wagEvent),
        ],
        if (currentEvent.flowId != null && daysOutsideEvent != null) ...[
          const SizedBox(height: 12),
          _DaysOutsideYearLocalNotesPanel(
            flowId: currentEvent.flowId!,
            event: daysOutsideEvent,
          ),
        ],
        if (currentEvent.flowId != null && openHandEvent != null) ...[
          const SizedBox(height: 12),
          _OpenHandLocalNotesPanel(
            flowId: currentEvent.flowId!,
            event: openHandEvent,
          ),
        ],
        if (currentEvent.flowId != null && djedEvent != null) ...[
          const SizedBox(height: 12),
          _DjedLocalNotesPanel(flowId: currentEvent.flowId!, event: djedEvent),
        ],
        if (courseEvent != null && courseContext != null) ...[
          const SizedBox(height: 12),
          _TheCourseDayCardPanel(event: courseEvent, context: courseContext),
        ],
        if (isDecanWatch && decanWatchContext != null) ...[
          const SizedBox(height: 12),
          _DecanWatchDayCardPanel(context: decanWatchContext),
        ],
        if (currentEvent.flowId != null &&
            isDecanWatch &&
            decanWatchContext != null) ...[
          const SizedBox(height: 12),
          _DecanWatchLocalNotesPanel(
            flowId: currentEvent.flowId!,
            kYear: target.ky,
            kMonth: target.km,
            kDay: target.kd,
            decanName: decanWatchContext.decanName,
          ),
        ],
        if (currentEvent.flowId != null && isDecanWatch) ...[
          const SizedBox(height: 12),
          _DecanWatchMilestonePanel(
            flowId: currentEvent.flowId!,
            kYear: target.ky,
          ),
        ],
        if (completionContext != null &&
            currentEvent.clientEventId?.trim().isNotEmpty == true &&
            currentEvent.flowId != null) ...[
          const SizedBox(height: 10),
          Builder(
            builder: (feedbackContext) => _MaatFlowCompletionPanel(
              event: currentEvent,
              identity: _completionIdentityForEvent(currentEvent),
              completion: completionContext,
              ky: target.ky,
              km: target.km,
              kd: target.kd,
              onRecordCompletion: widget.onRecordCompletion,
              onUnrecordCompletion: widget.onUnrecordCompletion,
              onRemoveCompletionBadge: widget.onRemoveCompletionBadge,
              onCompletionContinuity: (status) => _appendCompletionContinuity(
                target,
                status,
                sourceType: CompletionSourceType.maatFlow,
                triggerHaptic: false,
              ),
              onUserCompletionFeedback: enableRitualCompletionFeedback
                  ? (status) => playDayViewRitualCompletionFeedback(
                      feedbackContext,
                      status,
                    )
                  : null,
              onAddReflection: null,
              reloadSignal: completionReloadSignal,
              pickerStyle: completionPickerStyle,
              observedButtonKey:
                  includeOnboardingKeys &&
                      _isOnboardingTargetEvent(currentEvent)
                  ? widget.onboardingObservedKey
                  : null,
            ),
          ),
        ] else ...[
          const SizedBox(height: 10),
          Builder(
            builder: (feedbackContext) => CalendarEventCompletionPanel(
              identity: _completionIdentityForEvent(currentEvent),
              sourceType: _completionSourceTypeForEvent(
                currentEvent,
                flow,
                completionContext,
              ),
              loadStatus: currentEvent.flowId == null
                  ? null
                  : () => _loadCalendarCompletionStatus(target),
              onRecordStatus: (status) => _recordCalendarCompletion(
                target,
                status,
                sourceType: _completionSourceTypeForEvent(
                  currentEvent,
                  flow,
                  completionContext,
                ),
                flow: flow,
              ),
              onClearStatus: () => _clearCalendarCompletion(
                target,
                sourceType: _completionSourceTypeForEvent(
                  currentEvent,
                  flow,
                  completionContext,
                ),
              ),
              onCreateContinuity: (status) => _appendCompletionContinuity(
                target,
                status,
                sourceType: _completionSourceTypeForEvent(
                  currentEvent,
                  flow,
                  completionContext,
                ),
                triggerHaptic: !enableRitualCompletionFeedback,
              ),
              onUserCompletionFeedback: enableRitualCompletionFeedback
                  ? (status) => playDayViewRitualCompletionFeedback(
                      feedbackContext,
                      status,
                    )
                  : null,
              onReflect: null,
              reloadSignal: completionReloadSignal,
              pickerStyle: completionPickerStyle,
            ),
          ),
        ],
        if (libraryCta != null) ...[
          const SizedBox(height: 12),
          _MaatFlowLibraryCtaPanel(event: currentEvent, cta: libraryCta),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: DayViewRitualCompletionFeedbackCard._withVisual(
        enabled: enableRitualCompletionFeedback,
        visual: visual,
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
    required ValueChanged<String?> onEndFlowErrorChanged,
  }) {
    final currentEvent = target.event;
    final flow = _chromeFlowForId(currentEvent.flowId);
    final completionContext = _maatFlowCompletionContextForEvent(
      currentEvent,
      flow,
    );
    final sourceType = _completionSourceTypeForEvent(
      currentEvent,
      flow,
      completionContext,
    );

    return Row(
      children: [
        const Spacer(),
        _buildAddReflectionButton(
          routeContext: rootContext,
          sheetContext: sheetContext,
          target: target,
          sourceType: sourceType,
        ),
        const SizedBox(width: 8),
        _buildEventDetailOverflowButton(
          rootContext: rootContext,
          sheetContext: sheetContext,
          target: target,
          onEndFlowErrorChanged: onEndFlowErrorChanged,
        ),
      ],
    );
  }

  Widget _buildEventDetailInlineError(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF4A1414).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE57373).withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFFB4AB), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFFFDAD6),
                fontSize: 13,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventDetailPrimaryAction({
    required BuildContext rootContext,
    required BuildContext sheetContext,
    required DayViewSheetEventTarget target,
  }) {
    return TextButton.icon(
      onPressed: () async {
        Navigator.pop(sheetContext);
        final handled = await CalendarPage.makeTodoFromEventTarget(target);
        if (!handled && rootContext.mounted) {
          ScaffoldMessenger.of(
            rootContext,
          ).showSnackBar(const SnackBar(content: Text('Could not add to-do.')));
        }
      },
      icon: KemeticGold.icon(Icons.playlist_add_check),
      label: KemeticGold.text(
        'Make to-do',
        style: _goldHeaderStyle.copyWith(fontSize: 15),
      ),
    );
  }

  Widget _buildEventDetailOverflowButton({
    required BuildContext rootContext,
    required BuildContext sheetContext,
    required DayViewSheetEventTarget target,
    required ValueChanged<String?> onEndFlowErrorChanged,
  }) {
    final currentEvent = target.event;
    final flow = _chromeFlowForId(currentEvent.flowId);
    final actionableFlow = _isActionableFlowId(currentEvent.flowId);
    final isReminder = currentEvent.isReminder;
    final isEndingFlow =
        currentEvent.flowId != null &&
        _endingFlowIds.contains(currentEvent.flowId);

    return PopupMenuButton<String>(
      icon: KemeticGold.icon(Icons.more_vert),
      tooltip: 'Event options',
      color: _dayViewBase,
      onSelected: (value) async {
        if (value == 'end_flow') {
          final flowId = currentEvent.flowId;
          final onEndFlow = widget.onEndFlow;
          if (flowId != null && onEndFlow != null) {
            if (!_beginEndFlowAction(flowId)) return;
            onEndFlowErrorChanged(null);
            try {
              final result = await CalendarPage.endFlowFromEventTarget(target);
              if (result == EndFlowActionResult.success) {
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              } else if (result == EndFlowActionResult.failed) {
                onEndFlowErrorChanged(
                  'Could not end this flow right now.\n'
                  'Check your connection and try again.',
                );
              } else if (result == EndFlowActionResult.notHandled) {
                onEndFlow(flowId);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              }
            } finally {
              _finishEndFlowAction(flowId);
            }
          }
        } else if (value == 'end_reminder') {
          Navigator.pop(sheetContext);
          final reminderId = currentEvent.reminderId;
          final onEndReminder = widget.onEndReminder;
          if (reminderId != null && onEndReminder != null) {
            await onEndReminder(reminderId);
          }
        } else if (value == 'end_note') {
          Navigator.pop(sheetContext);
          if (widget.onDeleteNote != null) {
            await widget.onDeleteNote!(
              target.ky,
              target.km,
              target.kd,
              currentEvent,
            );
          }
        } else if (value == 'share') {
          Navigator.pop(sheetContext);
          if (flow != null && !isReminder) {
            await CalendarPage.shareFlowFromEvent(currentEvent);
          } else if (isReminder && widget.onShareReminder != null) {
            await widget.onShareReminder!(currentEvent);
          } else if (widget.onShareNote != null) {
            await widget.onShareNote!(currentEvent);
          }
        } else if (value == 'edit' && flow != null && actionableFlow) {
          await Navigator.of(sheetContext).maybePop();
          widget.onManageFlows?.call(flow.id);
        } else if (value == 'save' && flow != null && actionableFlow) {
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
            (flow == null || _isRepeatingNoteFlowId(currentEvent.flowId)) &&
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
        if (flow != null ||
            (isReminder && widget.onShareReminder != null) ||
            (flow == null && !isReminder && widget.onShareNote != null))
          PopupMenuItem(
            value: 'share',
            child: Row(
              children: [
                KemeticGold.icon(Icons.share_outlined),
                const SizedBox(width: 12),
                Text(
                  flow != null
                      ? 'Share Flow'
                      : isReminder
                      ? 'Share Reminder'
                      : 'Share Note',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        if (flow != null && actionableFlow && !isReminder)
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
        if (flow != null && actionableFlow && !isReminder)
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
        if (flow != null &&
            actionableFlow &&
            !isReminder &&
            widget.onEndFlow != null)
          PopupMenuItem(
            value: 'end_flow',
            enabled: !isEndingFlow,
            child: Row(
              children: [
                KemeticGold.icon(
                  isEndingFlow ? Icons.hourglass_top : Icons.stop_circle,
                ),
                const SizedBox(width: 12),
                Text(
                  isEndingFlow ? 'Ending Flow...' : 'End Flow',
                  style: const TextStyle(color: Colors.white),
                ),
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
        if (isReminder &&
            widget.onEndReminder != null &&
            currentEvent.reminderId != null)
          PopupMenuItem(
            value: 'end_reminder',
            child: Row(
              children: [
                KemeticGold.icon(Icons.stop_circle),
                const SizedBox(width: 12),
                const Text(
                  'End Reminder',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        if ((flow == null || _isRepeatingNoteFlowId(currentEvent.flowId)) &&
            !isReminder &&
            widget.onEditNote != null)
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
        if ((flow == null || _isRepeatingNoteFlowId(currentEvent.flowId)) &&
            !isReminder &&
            widget.onDeleteNote != null)
          PopupMenuItem(
            value: 'end_note',
            child: Row(
              children: [
                KemeticGold.icon(Icons.delete_outline),
                const SizedBox(width: 12),
                const Text('End Note', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEventDetailBottomActionRow({
    required BuildContext rootContext,
    required BuildContext sheetContext,
    required DayViewSheetEventTarget target,
    required ValueChanged<DayViewSheetEventTarget> onTargetChanged,
  }) {
    final calendarLabel = CalendarPage.detailSheetCalendarButtonLabel(
      target.event,
    );
    final calendarEnabled = CalendarPage.canChangeDetailSheetCalendar(
      target.event,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildEventDetailPrimaryAction(
          rootContext: rootContext,
          sheetContext: sheetContext,
          target: target,
        ),
        TextButton(
          onPressed: calendarEnabled
              ? () async {
                  final updatedTarget =
                      await CalendarPage.showDetailSheetCalendarPicker(
                        context: sheetContext,
                        target: target,
                        onOptimisticTargetChanged: (optimisticTarget) {
                          if (sheetContext.mounted) {
                            onTargetChanged(optimisticTarget);
                          }
                        },
                      );
                  if (!sheetContext.mounted || updatedTarget == null) return;
                  onTargetChanged(updatedTarget);
                }
              : null,
          child: calendarEnabled
              ? KemeticGold.text(
                  calendarLabel,
                  style: _goldHeaderStyle.copyWith(fontSize: 15),
                )
              : Text(
                  calendarLabel,
                  style: _goldHeaderStyle.copyWith(
                    fontSize: 15,
                    color: Colors.white24,
                  ),
                ),
        ),
      ],
    );
  }

  // Show event detail sheet
  void _showEventDetail(
    EventItem event, {
    DayViewSheetEventTarget? initialTarget,
  }) {
    if (!CalendarEventDetailSheetCoordinator.tryMarkOpenOrOpening()) {
      return;
    }
    final rootContext = context;
    final sheetDataListenable = widget.dataVersion ?? _kZeroListenable;
    final currentTarget = ValueNotifier<DayViewSheetEventTarget>(
      initialTarget ??
          DayViewSheetEventTarget(
            ky: widget.ky,
            km: widget.km,
            kd: widget.kd,
            event: event,
          ),
    );
    _publishEventDetailRestorationTarget(currentTarget.value);
    final measuredHeights = ValueNotifier<Map<String, double>>({});
    final endFlowError = ValueNotifier<String?>(null);
    final initialPages = _detailSheetPagesForTarget(currentTarget.value);
    PageController sheetPageController = PageController(
      initialPage: initialPages.currentIndex,
    );
    var onboardingDetailPromptScheduled = false;
    var sheetReleased = false;

    if (kDebugMode) {
      debugPrint('[_showEventDetail] Event: "${event.title}"');
      debugPrint(
        '[_showEventDetail] Event flowId: ${event.flowId} (${event.flowId.runtimeType})',
      );
      debugPrint('[_showEventDetail] Event color: ${event.color}');
      debugPrint(
        '[_showEventDetail] FlowIndex keys: ${widget.flowIndex.keys.toList()}',
      );
      debugPrint(
        '[_showEventDetail] FlowIndex length: ${widget.flowIndex.length}',
      );
    }

    void updateMeasuredHeight(String key, double height) {
      if (sheetReleased || !mounted) return;
      final normalized = height.ceilToDouble();
      if (normalized <= 0) return;
      final previous = measuredHeights.value[key];
      if (previous != null && (previous - normalized).abs() < 1) return;
      final nextHeights = Map<String, double>.from(measuredHeights.value);
      nextHeights[key] = normalized;
      measuredHeights.value = nextHeights;
    }

    void resetSheetPageController(int initialPage) {
      if (sheetReleased) return;
      final previous = sheetPageController;
      sheetPageController = PageController(initialPage: initialPage);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        previous.dispose();
      });
    }

    Future<void> moveToTarget(DayViewSheetEventTarget nextTarget) async {
      if (sheetReleased || !mounted) return;
      final previousTarget = currentTarget.value;
      endFlowError.value = null;
      currentTarget.value = nextTarget;
      _publishEventDetailRestorationTarget(nextTarget);
      if (widget.onNavigateToDay != null &&
          (nextTarget.ky != previousTarget.ky ||
              nextTarget.km != previousTarget.km ||
              nextTarget.kd != previousTarget.kd)) {
        unawaited(
          widget.onNavigateToDay!(nextTarget.ky, nextTarget.km, nextTarget.kd),
        );
      }
      unawaited(AppHaptics.selection());
    }

    void setEndFlowError(String? message) {
      if (sheetReleased || !mounted) return;
      if (endFlowError.value == message) return;
      endFlowError.value = message;
    }

    void releaseSheet() {
      if (sheetReleased) return;
      sheetReleased = true;
      final activeCoachmark = GuidedOnboardingController.instance.target;
      final journalKey = widget.onboardingJournalKey;
      if (activeCoachmark?.key == widget.onboardingObservedKey ||
          (journalKey != null &&
              (activeCoachmark?.secondaryKeys.contains(journalKey) ?? false))) {
        GuidedOnboardingController.instance.clear();
      }
      currentTarget.dispose();
      measuredHeights.dispose();
      endFlowError.dispose();
      sheetPageController.dispose();
      _clearEventDetailRestorationIfAllowed();
      CalendarEventDetailSheetCoordinator.markClosed();
    }

    try {
      showModalBottomSheet(
        context: rootContext,
        backgroundColor: _dayViewBase,
        isScrollControlled: true,
        builder: (sheetContext) {
          return ValueListenableBuilder<int>(
            valueListenable: sheetDataListenable,
            builder: (context, dataRevision, child) {
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
                  if (!onboardingDetailPromptScheduled &&
                      _isOnboardingTargetEvent(target.event) &&
                      widget.onboardingObservedKey != null) {
                    onboardingDetailPromptScheduled = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Future<
                        void
                      >.delayed(const Duration(milliseconds: 320), () {
                        if (sheetReleased || !mounted) return;
                        GuidedOnboardingController.instance.show(
                          CoachmarkTarget(
                            key: widget.onboardingObservedKey,
                            secondaryKeys: [
                              if (widget.onboardingJournalKey != null)
                                widget.onboardingJournalKey!,
                            ],
                            title: 'Mark what you lived.',
                            body:
                                'Tap Observed when you complete the event. Add a journal note when you want to remember what happened, what changed, or what you noticed.',
                            placement: CoachmarkPlacement.above,
                            allowBackgroundInteraction: true,
                            showNextButton: true,
                            onNext: () {
                              GuidedOnboardingController.instance.clear();
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).maybePop();
                              }
                              widget.onOnboardingObservedJournalNext?.call();
                            },
                          ),
                        );
                      });
                    });
                  }

                  return ValueListenableBuilder<Map<String, double>>(
                    valueListenable: measuredHeights,
                    builder: (context, heights, child) {
                      final hasOnboardingClosingBanner =
                          _isOnboardingTargetEvent(target.event) &&
                          widget.onboardingClosingBannerBuilder != null;
                      final maxSheetHeight = math.min(
                        MediaQuery.sizeOf(context).height * 0.68,
                        520.0,
                      );
                      final reservedChromeHeight = hasOnboardingClosingBanner
                          ? 250.0
                          : 120.0;
                      final sheetHeight = (heights[currentKey] ?? 200.0)
                          .clamp(
                            0.0,
                            math.max(
                              180.0,
                              maxSheetHeight - reservedChromeHeight,
                            ),
                          )
                          .toDouble();

                      final content = Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasOnboardingClosingBanner) ...[
                            widget.onboardingClosingBannerBuilder!(
                              sheetContext,
                            ),
                            const SizedBox(height: 2),
                          ],
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
                                        includeOnboardingKeys: false,
                                        completionReloadSignal: dataRevision,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildEventDetailTopActionRow(
                                  rootContext: rootContext,
                                  sheetContext: sheetContext,
                                  target: target,
                                  onEndFlowErrorChanged: setEndFlowError,
                                ),
                                ValueListenableBuilder<String?>(
                                  valueListenable: endFlowError,
                                  builder: (context, message, _) {
                                    return AnimatedSize(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      alignment: Alignment.topCenter,
                                      child: message == null
                                          ? const SizedBox.shrink()
                                          : Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    12,
                                                    8,
                                                    12,
                                                    0,
                                                  ),
                                              child:
                                                  _buildEventDetailInlineError(
                                                    message,
                                                  ),
                                            ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
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
                                          completionReloadSignal: dataRevision,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 46,
                                  child: _buildEventDetailBottomActionRow(
                                    rootContext: rootContext,
                                    sheetContext: sheetContext,
                                    target: target,
                                    onTargetChanged: (nextTarget) {
                                      unawaited(moveToTarget(nextTarget));
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );

                      return SafeArea(
                        top: false,
                        child: hasOnboardingClosingBanner
                            ? ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight:
                                      MediaQuery.sizeOf(context).height * 0.94,
                                ),
                                child: SingleChildScrollView(child: content),
                              )
                            : content,
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ).whenComplete(releaseSheet);
      if (kDebugMode) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          debugPrint('[DayView] detail sheet opened title="${event.title}"');
        });
      }
    } catch (_) {
      releaseSheet();
      rethrow;
    }
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

class _TheCourseDayCardPanel extends StatelessWidget {
  const _TheCourseDayCardPanel({required this.event, required this.context});

  final CourseEvent event;
  final CourseCalendarContext context;

  void _trackOpen() {
    unawaited(
      UserEventsRepo(Supabase.instance.client).track(
        event: 'day_card_opened_from_course',
        properties: <String, dynamic>{
          'v': kAppEventsSchemaVersion,
          'flow_key': kTheCourseFlowKey,
          'event_number': event.eventNumber,
          'flow_day': event.flowDay,
          'schedule_kind': event.scheduleKind.key,
          'season': context.seasonKey,
          'day_card_available': context.dayCardAvailable,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showDecan =
        event.decanSection == 'Decan Course' ||
        event.decanSection == 'Seasonal Course';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE8B84A).withValues(alpha: 0.34),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Day card',
            style: TextStyle(
              color: Color(0xFFFFD486),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          KemeticDayButton(
            dayKey: this.context.dayKey,
            kYear: this.context.kYear,
            openOnTap: true,
            onOpen: _trackOpen,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: _dayGold,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.event_note_outlined,
                    color: Colors.black,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Open today\'s day card',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${this.context.kemeticDateLabel} · ${this.context.seasonLabel}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (showDecan) ...[
            const SizedBox(height: 6),
            Text(
              '${this.context.decanName}: ${this.context.maatPrinciple}',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
          if (event.seasonAware) ...[
            const SizedBox(height: 8),
            Text(
              this.context.seasonInstruction,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayViewOnboardingPulse extends StatefulWidget {
  const _DayViewOnboardingPulse({required this.child});

  final Widget child;

  @override
  State<_DayViewOnboardingPulse> createState() =>
      _DayViewOnboardingPulseState();
}

class _DayViewOnboardingPulseState extends State<_DayViewOnboardingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations == true ||
        MediaQuery.maybeOf(context)?.accessibleNavigation == true;
    if (reduceMotion) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child ?? const SizedBox.shrink(),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _dayGold.withValues(alpha: 0.25 + (0.23 * t)),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _dayGold.withValues(alpha: 0.05 + (0.09 * t)),
                        blurRadius: 14 + (8 * t),
                        spreadRadius: 1 + (2 * t),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DecanWatchDayCardPanel extends StatelessWidget {
  const _DecanWatchDayCardPanel({required this.context});

  final CourseCalendarContext context;

  void _trackOpen() {
    unawaited(
      UserEventsRepo(Supabase.instance.client).track(
        event: 'day_card_opened_from_decan_watch',
        properties: <String, dynamic>{
          'v': kAppEventsSchemaVersion,
          'flow_key': kDecanWatchFlowKey,
          'k_year': context.kYear,
          'k_month': context.kMonth,
          'k_day': context.kDay,
          'season': context.seasonKey,
          'day_card_available': context.dayCardAvailable,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2F4A75).withValues(alpha: 0.75),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Day card',
            style: TextStyle(
              color: Color(0xFFFFD486),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          KemeticDayButton(
            dayKey: this.context.dayKey,
            kYear: this.context.kYear,
            openOnTap: true,
            onOpen: _trackOpen,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: _dayGold,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.event_note_outlined,
                    color: Colors.black,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Open this decan day card',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${this.context.kemeticDateLabel} · ${this.context.decanName}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            this.context.maatPrinciple,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _DecanWatchLocalNotesPanel extends StatefulWidget {
  const _DecanWatchLocalNotesPanel({
    required this.flowId,
    required this.kYear,
    required this.kMonth,
    required this.kDay,
    required this.decanName,
  });

  final int flowId;
  final int kYear;
  final int kMonth;
  final int kDay;
  final String decanName;

  @override
  State<_DecanWatchLocalNotesPanel> createState() =>
      _DecanWatchLocalNotesPanelState();
}

class _DecanWatchLocalNotesPanelState
    extends State<_DecanWatchLocalNotesPanel> {
  final TextEditingController _skyController = TextEditingController();
  final TextEditingController _intentionController = TextEditingController();
  final DecanWatchLocalStore _store = const DecanWatchLocalStore();
  bool _loading = true;
  bool _saving = false;
  bool _observedFromInside = false;

  int get _globalDecanId {
    return decanIdFromMonthAndIndex(
      monthIndex: widget.kMonth.clamp(1, 12).toInt(),
      decanInMonth: decanForDay(widget.kDay).clamp(1, 3).toInt(),
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _DecanWatchLocalNotesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flowId != widget.flowId ||
        oldWidget.kYear != widget.kYear ||
        oldWidget.kMonth != widget.kMonth ||
        oldWidget.kDay != widget.kDay) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _skyController.dispose();
    _intentionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    final record = await _store.loadRecord(
      flowId: widget.flowId,
      kYear: widget.kYear,
      globalDecanId: _globalDecanId,
    );
    if (!mounted) return;
    _skyController.text = record.skyNote ?? '';
    _intentionController.text = record.decanIntention ?? '';
    setState(() {
      _observedFromInside = record.observedFromInside;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _store.saveRecord(
        flowId: widget.flowId,
        kYear: widget.kYear,
        globalDecanId: _globalDecanId,
        record: DecanWatchRecord(
          skyNote: _skyController.text,
          decanIntention: _intentionController.text,
          observedFromInside: _observedFromInside,
        ),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved on this device only.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save Decan Watch notes.')),
      );
    }
  }

  Future<void> _clear() async {
    if (_saving) return;
    setState(() => _saving = true);
    await _store.saveRecord(
      flowId: widget.flowId,
      kYear: widget.kYear,
      globalDecanId: _globalDecanId,
      record: const DecanWatchRecord(),
    );
    if (!mounted) return;
    _skyController.clear();
    _intentionController.clear();
    setState(() {
      _observedFromInside = false;
      _saving = false;
    });
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFF090A0D),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _dayGold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2F4A75).withValues(alpha: 0.75),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Decan Watch notes',
            style: TextStyle(
              color: Color(0xFFFFD486),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Record the sky note and ${widget.decanName} intention for this watch.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            TextField(
              controller: _skyController,
              minLines: 2,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: _decoration(
                'One line about the sky: clear, clouded, Moon position, one visible star, or threshold note.',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _intentionController,
              minLines: 2,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: _decoration('One bearing for the next ten days.'),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _observedFromInside,
              contentPadding: EdgeInsets.zero,
              activeColor: _dayGold,
              checkColor: Colors.black,
              title: const Text(
                'Observed from inside or threshold',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              subtitle: const Text(
                'Use this only when outdoor access was not possible.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _observedFromInside = value == true;
                });
              },
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  onPressed: _saving || _loading ? null : _clear,
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _dayGold,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _saving || _loading ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save local'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DecanWatchMilestonePanel extends StatefulWidget {
  const _DecanWatchMilestonePanel({required this.flowId, required this.kYear});

  final int flowId;
  final int kYear;

  @override
  State<_DecanWatchMilestonePanel> createState() =>
      _DecanWatchMilestonePanelState();
}

class _DecanWatchMilestonePanelState extends State<_DecanWatchMilestonePanel> {
  int? _count;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _DecanWatchMilestonePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flowId != widget.flowId || oldWidget.kYear != widget.kYear) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _count = 0);
      return;
    }
    try {
      final rows = await Supabase.instance.client
          .from('user_event_completions')
          .select('metadata')
          .eq('user_id', user.id)
          .eq('flow_id', widget.flowId);
      final decans = <int>{};
      for (final row in (rows as List? ?? const [])) {
        final metadata = row is Map ? row['metadata'] : null;
        if (metadata is! Map) continue;
        if (resolveMaatFlowKind(
              behaviorPayload: Map<String, dynamic>.from(metadata),
            ) !=
            MaatFlowKind.decanWatch) {
          continue;
        }
        final status = metadata['status']?.toString().trim().toLowerCase();
        if (status != 'observed' && status != 'observed_from_inside') {
          continue;
        }
        final kYear = (metadata['k_year'] as num?)?.toInt();
        if (kYear != widget.kYear) continue;
        final globalDecanId = (metadata['global_decan_id'] as num?)?.toInt();
        if (globalDecanId == null) continue;
        decans.add(globalDecanId);
      }
      if (!mounted) return;
      setState(() => _count = decans.length);
    } catch (_) {
      if (mounted) setState(() => _count = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _count;
    final milestone = count == null ? '' : decanWatchMilestoneMessage(count);
    final gregorianYear = KemeticMath.toGregorian(widget.kYear, 1, 1).year;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Watch count',
            style: TextStyle(
              color: Color(0xFFFFD486),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            count == null
                ? 'Loading this year’s count...'
                : '$count watches observed in the $gregorianYear decan cycle. Observed from inside counts with a threshold mark.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          if (milestone.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              milestone,
              style: const TextStyle(
                color: Color(0xFFFFD486),
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MaatFlowCompletionPanel extends StatefulWidget {
  const _MaatFlowCompletionPanel({
    required this.event,
    required this.identity,
    required this.completion,
    required this.ky,
    required this.km,
    required this.kd,
    required this.onRecordCompletion,
    this.onUnrecordCompletion,
    this.onRemoveCompletionBadge,
    this.onCompletionContinuity,
    this.onUserCompletionFeedback,
    this.onAddReflection,
    this.observedButtonKey,
    this.reloadSignal,
    this.pickerStyle,
  });

  final EventItem event;
  final String identity;
  final _MaatFlowCompletionContext completion;
  final int ky;
  final int km;
  final int kd;
  final Future<void> Function({
    required String clientEventId,
    required int flowId,
    required DateTime completedOnDate,
    Map<String, dynamic>? metadata,
  })?
  onRecordCompletion;
  final Future<void> Function(String clientEventId)? onUnrecordCompletion;
  final Future<void> Function(String badgeId)? onRemoveCompletionBadge;
  final Future<void> Function(CompletionStatus status)? onCompletionContinuity;
  final ValueChanged<CompletionStatus>? onUserCompletionFeedback;
  final VoidCallback? onAddReflection;
  final Key? observedButtonKey;
  final Object? reloadSignal;
  final CalendarCompletionPickerStyle? pickerStyle;

  @override
  State<_MaatFlowCompletionPanel> createState() =>
      _MaatFlowCompletionPanelState();
}

class _MaatFlowCompletionPanelState extends State<_MaatFlowCompletionPanel> {
  final LivingTextDayOneNodeStore _livingTextDayOneNodeStore =
      const LivingTextDayOneNodeStore();
  final TextEditingController _eveningThresholdReleaseCarryController =
      TextEditingController();
  OverlayEntry? _sheetFeedbackOverlay;
  Timer? _sheetFeedbackTimer;
  String? _sheetFeedbackMessage;

  String? _status;
  bool _loading = true;
  bool _saving = false;
  DailyOrientationEntry? _eveningThresholdOrientation;
  DailyOrientationEntry? _eveningThresholdPreviousOrientation;
  bool _eveningThresholdReleasePending = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _clearSheetFeedback();
    _eveningThresholdReleaseCarryController.dispose();
    super.dispose();
  }

  void _clearSheetFeedback() {
    _sheetFeedbackTimer?.cancel();
    _sheetFeedbackTimer = null;
    _sheetFeedbackOverlay?.remove();
    _sheetFeedbackOverlay = null;
    _sheetFeedbackMessage = null;
  }

  void _showSheetFeedback(String message) {
    _clearSheetFeedback();
    if (mounted) {
      setState(() {
        _sheetFeedbackMessage = message;
      });
    }

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    final theme = Theme.of(context);
    final snackBarTheme = theme.snackBarTheme;
    final backgroundColor =
        snackBarTheme.backgroundColor ?? theme.colorScheme.inverseSurface;
    final textStyle =
        snackBarTheme.contentTextStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onInverseSurface,
        );

    _sheetFeedbackOverlay = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: IgnorePointer(
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(4),
                color: backgroundColor,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Text(
                    message,
                    style: textStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_sheetFeedbackOverlay!);
    _sheetFeedbackTimer = Timer(const Duration(seconds: 4), () {
      _sheetFeedbackOverlay?.remove();
      _sheetFeedbackOverlay = null;
      _sheetFeedbackTimer = null;
      if (!mounted) {
        _sheetFeedbackMessage = null;
        return;
      }
      setState(() {
        _sheetFeedbackMessage = null;
      });
    });
  }

  @override
  void didUpdateWidget(covariant _MaatFlowCompletionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.clientEventId != widget.event.clientEventId ||
        oldWidget.reloadSignal != widget.reloadSignal) {
      _eveningThresholdReleaseCarryController.clear();
      _eveningThresholdReleasePending = false;
      unawaited(_load());
    }
  }

  bool get _isEveningThresholdCompletion {
    return widget.completion.flowKey == kEveningThresholdFlowKey;
  }

  DateTime get _eventGregorianDate {
    return DateUtils.dateOnly(
      KemeticMath.toGregorian(widget.ky, widget.km, widget.kd),
    );
  }

  DateTime _eveningThresholdOrientationDate() {
    final raw = widget.event.behaviorPayload?['orientation_local_date']
        ?.toString()
        .trim();
    return _parseDateOnly(raw) ?? _eventGregorianDate;
  }

  DateTime? _eveningThresholdPreviousOrientationDate() {
    final raw = widget.event.behaviorPayload?['previous_orientation_local_date']
        ?.toString()
        .trim();
    return _parseDateOnly(raw) ??
        (widget.completion.eventNumber == 2
            ? _eventGregorianDate.subtract(const Duration(days: 1))
            : null);
  }

  static DateTime? _parseDateOnly(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  Future<void> _loadEveningThresholdOrientationState(String userId) async {
    if (!_isEveningThresholdCompletion) return;
    final repo = DailyOrientationRepo(Supabase.instance.client);
    final orientationDate = _eveningThresholdOrientationDate();
    final previousDate = _eveningThresholdPreviousOrientationDate();
    final orientation = await repo.loadEffectiveCarry(
      userId: userId,
      localDate: orientationDate,
    );
    final previous = previousDate == null
        ? null
        : await repo.loadEffectiveCarry(
            userId: userId,
            localDate: previousDate,
          );
    if (!mounted) return;
    setState(() {
      _eveningThresholdOrientation = orientation;
      _eveningThresholdPreviousOrientation = previous;
    });
  }

  Future<void> _load() async {
    final clientEventId = widget.event.clientEventId?.trim();
    final user = Supabase.instance.client.auth.currentUser;
    if (clientEventId == null || clientEventId.isEmpty || user == null) {
      if (mounted) {
        setState(() {
          _status = null;
          _loading = false;
          _eveningThresholdOrientation = null;
          _eveningThresholdPreviousOrientation = null;
          _eveningThresholdReleasePending = false;
        });
      }
      return;
    }

    await _loadEveningThresholdOrientationState(user.id);

    try {
      final row = await Supabase.instance.client
          .from('user_event_completions')
          .select('metadata')
          .eq('user_id', user.id)
          .eq('client_event_id', clientEventId)
          .maybeSingle();
      final metadata = row?['metadata'];
      final rawStatus = metadata is Map
          ? metadata['status']?.toString().trim().toLowerCase()
          : null;
      final nextStatus =
          _normalizeStatus(rawStatus) ??
          (widget.completion.customStatusLabels.containsKey(rawStatus)
              ? rawStatus
              : null);
      final hasCompletionRow = row != null;
      if (!mounted) return;
      setState(() {
        _status = nextStatus ?? (hasCompletionRow ? 'observed' : null);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  static String? _normalizeStatus(String? raw) {
    final value = raw?.trim().toLowerCase();
    if (value == 'observed' ||
        value == 'observed_partly' ||
        value == 'observed_from_inside' ||
        value == 'skipped' ||
        value == 'names_spoken' ||
        value == 'held' ||
        value == 'slipped' ||
        value == 'working' ||
        value == 'carry_forward' ||
        value == 'release' ||
        value == 'raised' ||
        value == 'conversation_pending') {
      return value;
    }
    if (value == 'partly_observed') return 'observed_partly';
    if (value == 'inside' || value == 'observed_inside') {
      return 'observed_from_inside';
    }
    return null;
  }

  Future<bool> _canRecordStatus(String status) async {
    if (widget.completion.flowKey == kKeptWordFlowKey &&
        widget.completion.eventNumber == 5 &&
        status == 'observed') {
      final flowId = widget.event.flowId;
      if (flowId == null) return true;
      final completed = await const TheKeptWordLocalStore()
          .loadConversationCompleted(flowId);
      if (completed) return true;
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mark the conversation complete locally, or choose Conversation pending.',
          ),
        ),
      );
      return false;
    }
    if (widget.completion.flowKey == kTheOpenHandFlowKey &&
        (widget.completion.eventNumber == 2 ||
            widget.completion.eventNumber == 5) &&
        status == 'observed') {
      final flowId = widget.event.flowId;
      if (flowId == null) return true;
      final completed = await const TheOpenHandLocalStore().loadActCompleted(
        flowId,
        widget.completion.eventNumber!,
      );
      if (completed) return true;
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mark the outward act complete locally first, or choose Partly/Skipped.',
          ),
        ),
      );
      return false;
    }
    if (widget.completion.flowKey == kTheDjedFlowKey && status == 'raised') {
      final flowId = widget.event.flowId;
      if (flowId == null) return true;
      final completed = await const TheDjedLocalStore().loadRaisingCompleted(
        flowId,
      );
      if (completed) return true;
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mark the raising complete locally first, or choose Observed/Partly/Skipped.',
          ),
        ),
      );
      return false;
    }
    return true;
  }

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  CompletionStatus _completionFeedbackStatusForRawStatus(String status) {
    final normalized = CompletionStatusX.fromWireName(status);
    if (normalized == CompletionStatus.observed ||
        normalized == CompletionStatus.partial) {
      return normalized;
    }
    switch (status.trim().toLowerCase()) {
      case 'observed_from_inside':
      case 'names_spoken':
      case 'held':
      case 'carry_forward':
      case 'release':
      case 'raised':
      case 'decision_pronounced':
      case 'transmitted':
      case 'stones_placed':
      case 'cooled':
      case 'spoken':
      case 'record_complete':
      case 'beer_poured':
      case 'golden_one_present':
        return CompletionStatus.observed;
      case 'working':
      case 'slipped':
      case 'conversation_pending':
        return CompletionStatus.partial;
    }
    return CompletionStatus.none;
  }

  String? _eveningThresholdPrerequisiteMessage() {
    if (!_isEveningThresholdCompletion) return null;
    if (widget.completion.eventNumber == 1 &&
        !_hasText(_eveningThresholdOrientation?.chosenReturn)) {
      return 'No carry was set this morning. The flow will resume tomorrow.';
    }
    if (widget.completion.eventNumber == 2 &&
        (!_hasText(_eveningThresholdPreviousOrientation?.chosenReturn) ||
            !_hasText(_eveningThresholdPreviousOrientation?.landingStatus))) {
      return 'Land yesterday\'s carry before choosing what crosses.';
    }
    return null;
  }

  bool _showEveningThresholdPrerequisiteFeedbackIfBlocked() {
    final message = _eveningThresholdPrerequisiteMessage();
    if (message == null) return false;
    _showSheetFeedback(message);
    return true;
  }

  String _landingStatusLabel(String? status) {
    switch (status?.trim().toLowerCase()) {
      case 'held':
        return 'held';
      case 'slipped':
        return 'slipped';
      case 'working':
      case 'working_on_it':
        return 'still working on it';
    }
    return 'not landed yet';
  }

  Future<bool> _ensureEveningThresholdCanChoose() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) return true;
    await _loadEveningThresholdOrientationState(userId);
    if (!mounted) return false;
    return !_showEveningThresholdPrerequisiteFeedbackIfBlocked();
  }

  Future<void> _beginEveningThresholdRelease() async {
    if (_saving || _loading || !await _ensureEveningThresholdCanChoose()) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _eveningThresholdReleasePending = true;
      _status = null;
    });
  }

  Future<bool> _applyEveningThresholdCompletion(
    String status, {
    String? releaseCarryText,
  }) async {
    if (!_isEveningThresholdCompletion) return true;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) return true;
    if (!await _ensureEveningThresholdCanChoose()) return false;

    final repo = DailyOrientationRepo(Supabase.instance.client);
    final orientationDate = _eveningThresholdOrientationDate();
    if (widget.completion.eventNumber == 1) {
      await repo.recordLanding(
        userId: userId,
        localDate: orientationDate,
        landingStatus: status,
      );
    } else if (widget.completion.eventNumber == 2) {
      final previousDate = _eveningThresholdPreviousOrientationDate();
      final previousCarry = _eveningThresholdPreviousOrientation?.chosenReturn
          ?.trim();
      if (previousDate == null ||
          previousCarry == null ||
          previousCarry.isEmpty) {
        return false;
      }
      if (status == 'carry_forward') {
        await repo.carryForward(
          userId: userId,
          localDate: orientationDate,
          previousLocalDate: previousDate,
          chosenReturn: previousCarry,
        );
      } else if (status == 'release') {
        final newCarry = releaseCarryText?.trim();
        if (newCarry == null || newCarry.isEmpty) {
          if (!mounted) return false;
          setState(() {
            _eveningThresholdReleasePending = true;
          });
          _showSheetFeedback('Name what you carry today first.');
          return false;
        }
        await repo.releaseWithNewCarry(
          userId: userId,
          localDate: orientationDate,
          chosenReturn: newCarry,
        );
      }
    }

    await _loadEveningThresholdOrientationState(userId);
    return true;
  }

  Future<void> _record(String status, {String? releaseCarryText}) async {
    if (status == 'none') {
      await _clear();
      return;
    }
    if (_saving) return;
    final clientEventId = widget.event.clientEventId?.trim();
    final flowId = widget.event.flowId;
    if (clientEventId == null || clientEventId.isEmpty || flowId == null) {
      return;
    }
    if (!await _canRecordStatus(status)) return;
    setState(() => _saving = true);
    final completedOnDate = DateUtils.dateOnly(
      KemeticMath.toGregorian(widget.ky, widget.km, widget.kd),
    );
    try {
      final thresholdApplied = await _applyEveningThresholdCompletion(
        status,
        releaseCarryText: releaseCarryText,
      );
      if (!thresholdApplied) {
        if (!mounted) return;
        setState(() => _saving = false);
        return;
      }
      final metadata = <String, dynamic>{
        ...widget.completion.metadataFor(
          status: status,
          completedOnDate: completedOnDate,
        ),
      };
      if (widget.completion.flowKey == kDecanWatchFlowKey) {
        final decanIndex = decanForDay(widget.kd);
        metadata.addAll(<String, dynamic>{
          'k_year': widget.ky,
          'k_month': widget.km,
          'decan_index': decanIndex,
          'decan_start_day': ((decanIndex - 1) * 10) + 1,
          'global_decan_id': decanIdFromMonthAndIndex(
            monthIndex: widget.km.clamp(1, 12).toInt(),
            decanInMonth: decanIndex.clamp(1, 3).toInt(),
          ),
        });
      } else if (widget.completion.flowKey == kDaysOutsideTheYearFlowKey) {
        final closingKYear = widget.km == 1 && widget.kd == 1
            ? widget.ky - 1
            : widget.ky;
        metadata.addAll(<String, dynamic>{
          'closing_k_year': closingKYear,
          'event_k_year': widget.ky,
          'k_month': widget.km,
          'k_day': widget.kd,
        });
      } else if (widget.completion.flowKey == kTheDjedFlowKey &&
          status == 'raised') {
        metadata.addAll(<String, dynamic>{
          'completion': 'raised',
          'raising_seconds': kDjedRaisingSeconds,
        });
      }
      final callback = widget.onRecordCompletion;
      if (callback != null) {
        await callback(
          clientEventId: clientEventId,
          flowId: flowId,
          completedOnDate: completedOnDate,
          metadata: metadata,
        );
      } else {
        await UserEventsRepo(Supabase.instance.client).recordEventCompletion(
          clientEventId: clientEventId,
          flowId: flowId,
          completedOnDate: completedOnDate,
          metadata: metadata,
        );
      }
      if (!mounted) return;
      setState(() {
        _status = status;
        _saving = false;
        _eveningThresholdReleasePending = false;
      });
      if (status == 'release') {
        _eveningThresholdReleaseCarryController.clear();
      }
      final completionStatus = CompletionStatusX.fromWireName(status);
      await const CalendarCompletionLocalStore().save(
        identity: widget.identity,
        status: completionStatus,
      );
      if (completionStatus.createsJournalContinuity) {
        await widget.onCompletionContinuity?.call(completionStatus);
      }
      final feedbackStatus = _completionFeedbackStatusForRawStatus(status);
      if (feedbackStatus == CompletionStatus.observed ||
          feedbackStatus == CompletionStatus.partial) {
        widget.onUserCompletionFeedback?.call(feedbackStatus);
      }
      unawaited(_maybeCaptureLivingTextDayOneNode(status));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      if (_isEveningThresholdCompletion) {
        _showSheetFeedback('Could not record this sitting.');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not record this sitting.')),
        );
      }
    }
  }

  Future<void> _clear() async {
    if (_saving) return;
    final clientEventId = widget.event.clientEventId?.trim();
    if (clientEventId == null || clientEventId.isEmpty) return;
    setState(() => _saving = true);
    try {
      final callback = widget.onUnrecordCompletion;
      if (callback != null) {
        await callback(clientEventId);
      } else {
        await UserEventsRepo(
          Supabase.instance.client,
        ).unrecordEventCompletion(clientEventId);
      }
      await const CalendarCompletionLocalStore().save(
        identity: widget.identity,
        status: CompletionStatus.none,
      );
      final removeBadge = widget.onRemoveCompletionBadge;
      if (removeBadge != null) {
        await removeBadge(
          calendarCompletionBadgeId(
            identity: widget.identity,
            sourceType: CompletionSourceType.maatFlow,
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _status = null;
        _saving = false;
        _eveningThresholdReleasePending = false;
      });
      _eveningThresholdReleaseCarryController.clear();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not clear this sitting.')),
      );
    }
  }

  Future<void> _maybeCaptureLivingTextDayOneNode(String status) async {
    if (status != 'observed' ||
        widget.completion.flowKey != kLivingTextFlowKey ||
        widget.completion.eventNumber != 1) {
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'local';
    final flowInstanceId = widget.event.flowId?.toString();
    final existing = await _livingTextDayOneNodeStore.readSlug(
      userId: userId,
      flowInstanceId: flowInstanceId,
    );
    if (existing != null || !mounted) return;

    final shouldChoose = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF090909),
        title: const Text(
          'Which Library entry did you choose for Day 1?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Choose the entry now so later Living Text events can open Your Insights there.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: KemeticGold.text(
              'Choose entry',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (shouldChoose != true || !mounted) return;

    final selectedNodeSlug = await showKemeticNodeSearch(context);
    if (selectedNodeSlug == null || !mounted) return;
    await _livingTextDayOneNodeStore.writeSlug(
      userId: userId,
      flowInstanceId: flowInstanceId,
      nodeSlug: selectedNodeSlug,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Day 1 Library entry saved.')));
  }

  Widget _statusButton(String status, String label, {bool expanded = true}) {
    final selected =
        _status == status ||
        (status == 'release' && _eveningThresholdReleasePending);
    final style = widget.pickerStyle ?? const CalendarCompletionPickerStyle();
    final button = OutlinedButton(
      key: status == 'observed' ? widget.observedButtonKey : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: selected
            ? style.selectedForegroundColor
            : style.unselectedForegroundColor,
        backgroundColor: selected
            ? style.selectedBackgroundColor
            : style.unselectedBackgroundColor,
        side: BorderSide(
          color: selected
              ? style.selectedBorderColor
              : style.unselectedBorderColor,
          width: style.buttonBorderWidth,
        ),
        padding: style.buttonPadding,
        minimumSize: style.buttonMinimumSize,
        tapTargetSize: style.buttonTapTargetSize,
        visualDensity: style.buttonVisualDensity,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(style.buttonRadius),
        ),
      ),
      onPressed: _saving || _loading
          ? null
          : () {
              if (selected) {
                if (status == 'release' && _eveningThresholdReleasePending) {
                  setState(() {
                    _eveningThresholdReleasePending = false;
                    _eveningThresholdReleaseCarryController.clear();
                  });
                } else {
                  unawaited(_clear());
                }
              } else if (_isEveningThresholdCompletion &&
                  _showEveningThresholdPrerequisiteFeedbackIfBlocked()) {
                return;
              } else if (_isEveningThresholdCompletion &&
                  widget.completion.eventNumber == 2 &&
                  status == 'release') {
                unawaited(_beginEveningThresholdRelease());
              } else {
                unawaited(_record(status));
              }
            },
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: style.buttonFontSize,
          fontWeight: style.buttonFontWeight,
          fontFamily: style.buttonFontFamily,
          fontFamilyFallback: style.buttonFontFamilyFallback,
        ),
      ),
    );
    if (!expanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return Expanded(child: button);
  }

  Widget _buildEveningThresholdWitnessBlock({
    required String label,
    required String body,
    String? subLabel,
    String? subBody,
  }) {
    final style = widget.pickerStyle ?? const CalendarCompletionPickerStyle();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: style.unselectedBackgroundColor.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: style.unselectedBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: style.labelColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            body,
            style: TextStyle(
              color: style.selectedForegroundColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          if (subLabel != null && subBody != null) ...[
            const SizedBox(height: 12),
            Text(
              subLabel,
              style: TextStyle(
                color: style.labelColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subBody,
              style: TextStyle(
                color: style.unselectedForegroundColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEveningThresholdFeedbackMessage(String message) {
    final style = widget.pickerStyle ?? const CalendarCompletionPickerStyle();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: style.unselectedBackgroundColor.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: style.selectedBorderColor),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: style.selectedForegroundColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
      ),
    );
  }

  Widget _buildEveningThresholdReleaseEditor() {
    final style = widget.pickerStyle ?? const CalendarCompletionPickerStyle();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        TextField(
          controller: _eveningThresholdReleaseCarryController,
          maxLines: 3,
          minLines: 2,
          onChanged: (_) => setState(() {}),
          style: TextStyle(
            color: style.selectedForegroundColor,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
          decoration: InputDecoration(
            labelText: 'What do you carry today?',
            labelStyle: TextStyle(color: style.labelColor),
            filled: true,
            fillColor: style.unselectedBackgroundColor,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: style.unselectedBorderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: style.selectedBorderColor),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed:
                _saving ||
                    _eveningThresholdReleaseCarryController.text.trim().isEmpty
                ? null
                : () => unawaited(
                    _record(
                      'release',
                      releaseCarryText:
                          _eveningThresholdReleaseCarryController.text,
                    ),
                  ),
            child: const Text('Save carry'),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildEveningThresholdContextWidgets() {
    if (!_isEveningThresholdCompletion) return const <Widget>[];
    final eventNumber = widget.completion.eventNumber;
    if (eventNumber == 1) {
      final carried = _eveningThresholdOrientation?.chosenReturn?.trim();
      return <Widget>[
        _buildEveningThresholdWitnessBlock(
          label: 'WHAT YOU CARRIED',
          body: carried == null || carried.isEmpty
              ? 'No carry was set this morning. The flow will resume tomorrow.'
              : carried,
        ),
        if (_sheetFeedbackMessage != null) ...[
          const SizedBox(height: 8),
          _buildEveningThresholdFeedbackMessage(_sheetFeedbackMessage!),
        ],
        const SizedBox(height: 12),
      ];
    }
    if (eventNumber == 2) {
      final previous = _eveningThresholdPreviousOrientation;
      final carried = previous?.chosenReturn?.trim();
      return <Widget>[
        _buildEveningThresholdWitnessBlock(
          label: 'YESTERDAY YOU CARRIED',
          body: carried == null || carried.isEmpty
              ? 'No carry was landed yesterday.'
              : carried,
          subLabel: 'IT LANDED AS',
          subBody: _landingStatusLabel(previous?.landingStatus),
        ),
        if (_eveningThresholdReleasePending)
          _buildEveningThresholdReleaseEditor(),
        if (_sheetFeedbackMessage != null) ...[
          const SizedBox(height: 8),
          _buildEveningThresholdFeedbackMessage(_sheetFeedbackMessage!),
        ],
        const SizedBox(height: 12),
      ];
    }
    return const <Widget>[];
  }

  @override
  Widget build(BuildContext context) {
    final standardStatus = CompletionStatusX.fromWireName(_status);
    final canShare =
        widget.completion.sharePromptOnComplete &&
        (_status == 'observed' ||
            _status == 'observed_partly' ||
            _status == 'raised');
    final style = widget.pickerStyle ?? const CalendarCompletionPickerStyle();
    final eveningThresholdContext = _buildEveningThresholdContextWidgets();

    if (widget.completion.customStatusesOnly) {
      final customButtons = widget.completion.customStatusLabels.entries
          .expand<Widget>(
            (entry) => <Widget>[
              _statusButton(entry.key, entry.value, expanded: false),
              SizedBox(height: style.buttonGap),
            ],
          )
          .toList();
      if (customButtons.isNotEmpty) {
        customButtons.removeLast();
      }
      return Container(
        width: double.infinity,
        padding: style.containerPadding,
        decoration: BoxDecoration(
          color: style.containerColor,
          borderRadius: BorderRadius.circular(style.containerRadius),
          border: Border.all(
            color: style.containerBorderColor,
            width: style.containerBorderWidth,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...eveningThresholdContext,
            Text(
              style.label,
              style: TextStyle(
                color: style.labelColor,
                fontSize: style.labelFontSize,
                fontWeight: style.labelFontWeight,
                letterSpacing: style.labelLetterSpacing,
              ),
            ),
            SizedBox(height: style.labelGap),
            ...customButtons,
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...eveningThresholdContext,
        CalendarCompletionPicker(
          current: standardStatus,
          saving: _saving,
          loading: _loading,
          showPartial: widget.completion.showPartly,
          observedButtonKey: widget.observedButtonKey,
          onReflect: widget.onAddReflection,
          style: widget.pickerStyle,
          onChanged: (status) {
            if (status == standardStatus) {
              unawaited(_clear());
            } else {
              unawaited(_record(status.maatStatusName));
            }
          },
        ),
        if (!_loading && widget.completion.extraStatusLabels.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children:
                widget.completion.extraStatusLabels.entries
                    .expand<Widget>(
                      (entry) => <Widget>[
                        _statusButton(entry.key, entry.value),
                        const SizedBox(width: 8),
                      ],
                    )
                    .toList()
                  ..removeLast(),
          ),
        ],
        if (canShare) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _saving
                ? null
                : () =>
                      unawaited(CalendarPage.shareFlowFromEvent(widget.event)),
            icon: KemeticGold.icon(Icons.share_outlined, size: 18),
            label: KemeticGold.text(
              widget.completion.shareButtonLabel,
              style: _goldHeaderStyle.copyWith(fontSize: 14),
            ),
          ),
        ],
      ],
    );
  }
}

class _MaatFlowLibraryCtaPanel extends StatefulWidget {
  const _MaatFlowLibraryCtaPanel({required this.event, required this.cta});

  final EventItem event;
  final _MaatLibraryCtaPayload cta;

  @override
  State<_MaatFlowLibraryCtaPanel> createState() =>
      _MaatFlowLibraryCtaPanelState();
}

class _MaatFlowLibraryCtaPanelState extends State<_MaatFlowLibraryCtaPanel> {
  final LivingTextDayOneNodeStore _store = const LivingTextDayOneNodeStore();

  String? _resolvedNodeSlug;
  bool _loading = true;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadNodeSlug());
  }

  @override
  void didUpdateWidget(covariant _MaatFlowLibraryCtaPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.clientEventId != widget.event.clientEventId ||
        oldWidget.event.flowId != widget.event.flowId ||
        oldWidget.cta.nodeSlug != widget.cta.nodeSlug ||
        oldWidget.cta.flowKey != widget.cta.flowKey) {
      unawaited(_loadNodeSlug());
    }
  }

  Future<void> _loadNodeSlug() async {
    final generation = ++_loadGeneration;
    final fixedSlug = widget.cta.nodeSlug;
    if (fixedSlug != null && fixedSlug.isNotEmpty) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _resolvedNodeSlug = fixedSlug;
        _loading = false;
      });
      return;
    }

    if (widget.cta.flowKey != kLivingTextFlowKey) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _resolvedNodeSlug = null;
        _loading = false;
      });
      return;
    }

    if (mounted) {
      setState(() => _loading = true);
    }
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'local';
    final storedSlug = await _store.readSlug(
      userId: userId,
      flowInstanceId: widget.event.flowId?.toString(),
    );
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _resolvedNodeSlug = storedSlug;
      _loading = false;
    });
  }

  void _openTarget() {
    if (_loading) return;
    final nodeSlug = _resolvedNodeSlug?.trim();
    if (widget.cta.type == kMaatLibraryCtaAddInsight &&
        nodeSlug != null &&
        nodeSlug.isNotEmpty) {
      context.push(
        '/nodes/${Uri.encodeComponent(nodeSlug)}?action=add_insight',
      );
      return;
    }
    context.push('/nodes');
  }

  @override
  Widget build(BuildContext context) {
    final hasResolvedSlug = _resolvedNodeSlug?.trim().isNotEmpty == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF5E8CB).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Library',
            style: TextStyle(
              color: Color(0xFFFFD486),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _openTarget,
              style: ElevatedButton.styleFrom(
                backgroundColor: KemeticGold.base,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.12),
                disabledForegroundColor: Colors.white60,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.edit_note, size: 18),
              label: Text(
                widget.cta.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (!_loading && !hasResolvedSlug) ...[
            const SizedBox(height: 8),
            Text(
              'Choose the Day 1 entry you read, then open Your Insights.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TheTendingLocalNotesPanel extends StatefulWidget {
  const _TheTendingLocalNotesPanel({required this.flowId, required this.event});

  final int flowId;
  final TheTendingEvent event;

  @override
  State<_TheTendingLocalNotesPanel> createState() =>
      _TheTendingLocalNotesPanelState();
}

class _TheTendingLocalNotesPanelState
    extends State<_TheTendingLocalNotesPanel> {
  final TextEditingController _controller = TextEditingController();
  final TheTendingLocalStore _store = const TheTendingLocalStore();
  bool _loading = true;
  bool _saving = false;
  int _careListCount = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _TheTendingLocalNotesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flowId != widget.flowId ||
        oldWidget.event.localPrompt != widget.event.localPrompt) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    final text = await _store.loadPromptText(
      widget.flowId,
      widget.event.localPrompt,
    );
    final careList = await _store.loadCareList(widget.flowId);
    if (!mounted) return;
    _controller.text = text;
    setState(() {
      _careListCount = careList.length;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _store.savePromptText(
        widget.flowId,
        widget.event.localPrompt,
        _controller.text,
      );
      final careList = await _store.loadCareList(widget.flowId);
      if (!mounted) return;
      setState(() {
        _careListCount = careList.length;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved on this device only.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save local care notes.')),
      );
    }
  }

  Future<void> _clearThisPrompt() async {
    if (_saving) return;
    setState(() => _saving = true);
    await _store.savePromptText(widget.flowId, widget.event.localPrompt, '');
    final careList = await _store.loadCareList(widget.flowId);
    if (!mounted) return;
    _controller.clear();
    setState(() {
      _careListCount = careList.length;
      _saving = false;
    });
  }

  int get _minLines {
    switch (widget.event.localPrompt) {
      case TheTendingLocalPromptKind.careInventory:
      case TheTendingLocalPromptKind.sealSeeingStatuses:
      case TheTendingLocalPromptKind.closePerPerson:
        return 4;
      case TheTendingLocalPromptKind.none:
      case TheTendingLocalPromptKind.heardOneSentence:
      case TheTendingLocalPromptKind.day11Commitment:
      case TheTendingLocalPromptKind.day15Check:
      case TheTendingLocalPromptKind.day21RepairCommit:
      case TheTendingLocalPromptKind.day25RepairCheck:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF7A6B9E).withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.event.localPrompt.label,
            style: const TextStyle(
              color: Color(0xFFFFD486),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Record the care note for this tending step.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.event.localPrompt.helperText,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          if (_careListCount > 0 &&
              widget.event.localPrompt !=
                  TheTendingLocalPromptKind.careInventory) ...[
            const SizedBox(height: 6),
            Text(
              'Care inventory: $_careListCount ${_careListCount == 1 ? 'entry' : 'entries'}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          if (_loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextField(
              controller: _controller,
              minLines: _minLines,
              maxLines: 8,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF090A0D),
                hintText: _hintText(widget.event.localPrompt),
                hintStyle: const TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _dayGold),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  onPressed: _saving || _loading ? null : _clearThisPrompt,
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _dayGold,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _saving || _loading ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save local'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _hintText(TheTendingLocalPromptKind prompt) {
    switch (prompt) {
      case TheTendingLocalPromptKind.careInventory:
        return 'Name - need\nName - need';
      case TheTendingLocalPromptKind.heardOneSentence:
        return 'One sentence I heard or saw...';
      case TheTendingLocalPromptKind.sealSeeingStatuses:
        return 'Name - tended / partial / unseen';
      case TheTendingLocalPromptKind.day11Commitment:
        return 'I will complete...';
      case TheTendingLocalPromptKind.day15Check:
        return 'Done / partial / still open...';
      case TheTendingLocalPromptKind.day21RepairCommit:
        return 'I missed... I will repair by...';
      case TheTendingLocalPromptKind.day25RepairCheck:
        return 'Repair moved / stalled / next step...';
      case TheTendingLocalPromptKind.closePerPerson:
        return 'Name - private closing line\nWho tended me...';
      case TheTendingLocalPromptKind.none:
        return '';
    }
  }
}

class _KeptWordLocalNotesPanel extends StatefulWidget {
  const _KeptWordLocalNotesPanel({required this.flowId, required this.event});

  final int flowId;
  final KeptWordEvent event;

  @override
  State<_KeptWordLocalNotesPanel> createState() =>
      _KeptWordLocalNotesPanelState();
}

class _KeptWordLocalNotesPanelState extends State<_KeptWordLocalNotesPanel> {
  final TextEditingController _controller = TextEditingController();
  final TheKeptWordLocalStore _store = const TheKeptWordLocalStore();
  bool _loading = true;
  bool _saving = false;
  bool _conversationCompleted = false;
  bool _conversationPaused = false;
  int _agreementCount = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _KeptWordLocalNotesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flowId != widget.flowId ||
        oldWidget.event.localPrompt != widget.event.localPrompt) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    final text = await _store.loadPromptText(
      widget.flowId,
      widget.event.localPrompt,
    );
    final agreements = await _store.loadAgreementInventory(widget.flowId);
    final completed = await _store.loadConversationCompleted(widget.flowId);
    final paused = await _store.loadConversationPaused(widget.flowId);
    if (!mounted) return;
    _controller.text = text;
    setState(() {
      _agreementCount = agreements.length;
      _conversationCompleted = completed;
      _conversationPaused = paused;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _store.savePromptText(
        widget.flowId,
        widget.event.localPrompt,
        _controller.text,
      );
      final agreements = await _store.loadAgreementInventory(widget.flowId);
      if (!mounted) return;
      setState(() {
        _agreementCount = agreements.length;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved on this device only.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save local household notes.')),
      );
    }
  }

  Future<void> _clearThisPrompt() async {
    if (_saving) return;
    setState(() => _saving = true);
    await _store.savePromptText(widget.flowId, widget.event.localPrompt, '');
    final agreements = await _store.loadAgreementInventory(widget.flowId);
    if (!mounted) return;
    _controller.clear();
    setState(() {
      _agreementCount = agreements.length;
      _saving = false;
    });
  }

  Future<void> _setConversationCompleted(bool value) async {
    setState(() {
      _conversationCompleted = value;
    });
    await _store.saveConversationCompleted(widget.flowId, value);
  }

  Future<void> _setConversationPaused(bool value) async {
    setState(() {
      _conversationPaused = value;
    });
    await _store.saveConversationPaused(widget.flowId, value);
  }

  int get _minLines {
    switch (widget.event.localPrompt) {
      case KeptWordLocalPromptKind.agreementInventory:
      case KeptWordLocalPromptKind.conversationRecord:
      case KeptWordLocalPromptKind.closeInventory:
        return 4;
      case KeptWordLocalPromptKind.none:
      case KeptWordLocalPromptKind.sharedRhythm:
      case KeptWordLocalPromptKind.sealSeeingGreedCheck:
      case KeptWordLocalPromptKind.conversationPrep:
      case KeptWordLocalPromptKind.sealNaming:
      case KeptWordLocalPromptKind.renewedAgreement:
      case KeptWordLocalPromptKind.rhythmCheck:
        return 3;
    }
  }

  bool get _showConversationControls {
    return widget.event.eventNumber >= 4 && widget.event.eventNumber <= 6;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF8B7355).withValues(alpha: 0.62),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.event.localPrompt.label,
            style: const TextStyle(
              color: Color(0xFFFFD486),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Record the household note for this step.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.event.localPrompt.helperText,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          if (_agreementCount > 0 &&
              widget.event.localPrompt !=
                  KeptWordLocalPromptKind.agreementInventory) ...[
            const SizedBox(height: 6),
            Text(
              'Agreement inventory: $_agreementCount ${_agreementCount == 1 ? 'entry' : 'entries'}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
          if (_showConversationControls) ...[
            const SizedBox(height: 10),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _conversationCompleted,
              activeColor: _dayGold,
              title: const Text(
                'Conversation happened',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              onChanged: _loading || _saving
                  ? null
                  : (value) =>
                        unawaited(_setConversationCompleted(value == true)),
            ),
            SwitchListTile.adaptive(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _conversationPaused,
              activeThumbColor: _dayGold,
              title: const Text(
                'Pause conversation work locally',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              subtitle: const Text(
                'Use this if contact is unsafe, unavailable, or not possible.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onChanged: _loading || _saving
                  ? null
                  : (value) => unawaited(_setConversationPaused(value)),
            ),
            if (!_conversationCompleted && widget.event.eventNumber == 5)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'The conversation from Day 11 has not been marked complete. It can still happen before the decan closes.',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 10),
          if (_loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextField(
              controller: _controller,
              minLines: _minLines,
              maxLines: 8,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF090A0D),
                hintText: _hintText(widget.event.localPrompt),
                hintStyle: const TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _dayGold),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  onPressed: _saving || _loading ? null : _clearThisPrompt,
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _dayGold,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _saving || _loading ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save local'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _hintText(KeptWordLocalPromptKind prompt) {
    switch (prompt) {
      case KeptWordLocalPromptKind.agreementInventory:
        return 'Person - agreement - kept/drifted/broken';
      case KeptWordLocalPromptKind.sharedRhythm:
        return 'The rhythm that drifted...';
      case KeptWordLocalPromptKind.sealSeeingGreedCheck:
        return 'The first break to name in Decan 2...';
      case KeptWordLocalPromptKind.conversationPrep:
        return 'We agreed to... What has been happening is... I will speak by...';
      case KeptWordLocalPromptKind.conversationRecord:
        return 'What I said...\nWhat they said...\nWhat was agreed...';
      case KeptWordLocalPromptKind.sealNaming:
        return 'Resolved / in process / named but unresolved...';
      case KeptWordLocalPromptKind.renewedAgreement:
        return 'The current agreement is...';
      case KeptWordLocalPromptKind.rhythmCheck:
        return 'The rhythm is holding / shifted because...';
      case KeptWordLocalPromptKind.closeInventory:
        return 'One line now true...';
      case KeptWordLocalPromptKind.none:
        return '';
    }
  }
}

class _TheWagLocalNotesPanel extends StatefulWidget {
  const _TheWagLocalNotesPanel({required this.flowId, required this.event});

  final int flowId;
  final WagEvent event;

  @override
  State<_TheWagLocalNotesPanel> createState() => _TheWagLocalNotesPanelState();
}

class _TheWagLocalNotesPanelState extends State<_TheWagLocalNotesPanel> {
  final TextEditingController _controller = TextEditingController();
  final TheWagLocalStore _store = const TheWagLocalStore();
  bool _loading = true;
  bool _saving = false;
  int _ancestorCount = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _TheWagLocalNotesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flowId != widget.flowId ||
        oldWidget.event.localPrompt != widget.event.localPrompt) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    final text = await _store.loadPromptText(
      widget.flowId,
      widget.event.localPrompt,
    );
    final ancestors = await _store.loadAncestorNames(widget.flowId);
    if (!mounted) return;
    _controller.text = text;
    setState(() {
      _ancestorCount = ancestors.length;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _store.savePromptText(
        widget.flowId,
        widget.event.localPrompt,
        _controller.text,
      );
      final ancestors = await _store.loadAncestorNames(widget.flowId);
      if (!mounted) return;
      setState(() {
        _ancestorCount = ancestors.length;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved on this device only.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save local Wag notes.')),
      );
    }
  }

  Future<void> _clearThisPrompt() async {
    if (_saving) return;
    setState(() => _saving = true);
    await _store.savePromptText(widget.flowId, widget.event.localPrompt, '');
    final ancestors = await _store.loadAncestorNames(widget.flowId);
    if (!mounted) return;
    _controller.clear();
    setState(() {
      _ancestorCount = ancestors.length;
      _saving = false;
    });
  }

  int get _minLines {
    switch (widget.event.localPrompt) {
      case WagLocalPromptKind.ancestorNames:
      case WagLocalPromptKind.extendedNames:
      case WagLocalPromptKind.feastNames:
      case WagLocalPromptKind.closingConfirmation:
        return 4;
      case WagLocalPromptKind.none:
      case WagLocalPromptKind.tableConfirmation:
      case WagLocalPromptKind.wagFocus:
      case WagLocalPromptKind.vigilChecklist:
      case WagLocalPromptKind.inheritedGift:
      case WagLocalPromptKind.legacyLine:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF9C6B4E).withValues(alpha: 0.62),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.event.localPrompt.label,
            style: const TextStyle(
              color: Color(0xFFFFD486),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Record the ancestor note for this procession step.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.event.localPrompt.helperText,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          if (_ancestorCount > 0 &&
              widget.event.localPrompt != WagLocalPromptKind.ancestorNames) ...[
            const SizedBox(height: 6),
            Text(
              'Ancestor names: $_ancestorCount ${_ancestorCount == 1 ? 'entry' : 'entries'}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          if (_loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextField(
              controller: _controller,
              minLines: _minLines,
              maxLines: 8,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF090A0D),
                hintText: _hintText(widget.event.localPrompt),
                hintStyle: const TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _dayGold),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  onPressed: _saving || _loading ? null : _clearThisPrompt,
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _dayGold,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _saving || _loading ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save local'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _hintText(WagLocalPromptKind prompt) {
    switch (prompt) {
      case WagLocalPromptKind.ancestorNames:
        return 'Name\n[Name unknown] - grandmother\nPractice ancestor - craft elder';
      case WagLocalPromptKind.extendedNames:
        return 'Additional name\nUnknown ancestor - relationship\nMentor or elder';
      case WagLocalPromptKind.tableConfirmation:
        return 'List read / water set / table ready...';
      case WagLocalPromptKind.wagFocus:
        return 'At the Wag I most want to acknowledge...';
      case WagLocalPromptKind.vigilChecklist:
        return 'Water / bread or food / scent / names spoken...';
      case WagLocalPromptKind.feastNames:
        return 'Names spoken / full feast kept / partial offering...';
      case WagLocalPromptKind.inheritedGift:
        return '[Name] gave me... I carry it by...';
      case WagLocalPromptKind.legacyLine:
        return 'After my name, I would want them to say...';
      case WagLocalPromptKind.closingConfirmation:
        return 'What this cycle confirmed...';
      case WagLocalPromptKind.none:
        return '';
    }
  }
}

class _DaysOutsideYearLocalNotesPanel extends StatefulWidget {
  const _DaysOutsideYearLocalNotesPanel({
    required this.flowId,
    required this.event,
  });

  final int flowId;
  final DaysOutsideEvent event;

  @override
  State<_DaysOutsideYearLocalNotesPanel> createState() =>
      _DaysOutsideYearLocalNotesPanelState();
}

class _DaysOutsideYearLocalNotesPanelState
    extends State<_DaysOutsideYearLocalNotesPanel> {
  final TextEditingController _controller = TextEditingController();
  final DaysOutsideYearLocalStore _store = const DaysOutsideYearLocalStore();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _DaysOutsideYearLocalNotesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flowId != widget.flowId ||
        oldWidget.event.localPrompt != widget.event.localPrompt) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final text = await _store.loadPromptText(
      widget.flowId,
      widget.event.localPrompt,
    );
    if (!mounted) return;
    _controller.text = text;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _store.savePromptText(
        widget.flowId,
        widget.event.localPrompt,
        _controller.text,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved on this device only.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save local year-threshold notes.'),
        ),
      );
    }
  }

  Future<void> _clear() async {
    if (_saving) return;
    setState(() => _saving = true);
    await _store.savePromptText(widget.flowId, widget.event.localPrompt, '');
    if (!mounted) return;
    _controller.clear();
    setState(() => _saving = false);
  }

  int get _minLines {
    return widget.event.kind == DaysOutsideEventKind.wepRonpetOpening ? 4 : 3;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFB8A8FF).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.event.localPrompt.label,
            style: const TextStyle(
              color: Color(0xFFFFD486),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Record the threshold note for this year-opening step.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.event.localPrompt.helperText,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextField(
              controller: _controller,
              minLines: _minLines,
              maxLines: 8,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF090A0D),
                hintText: _hintText(widget.event.localPrompt),
                hintStyle: const TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _dayGold),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  onPressed: _saving || _loading ? null : _clear,
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _dayGold,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _saving || _loading ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save local'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _hintText(DaysOutsideLocalPromptKind prompt) {
    switch (prompt) {
      case DaysOutsideLocalPromptKind.yearCloseTriple:
        return 'Unexpected gift...\nUngiven ask...\nCarries across...';
      case DaysOutsideLocalPromptKind.ausarQuality:
        return 'This needs to be gathered back...';
      case DaysOutsideLocalPromptKind.heruWerQuality:
        return 'I need to see this from above...';
      case DaysOutsideLocalPromptKind.setQuality:
        return 'This force needs direction...';
      case DaysOutsideLocalPromptKind.asetQuality:
        return 'This truth needs the right moment...';
      case DaysOutsideLocalPromptKind.nebetHetQuality:
        return 'This threshold needs witness...';
      case DaysOutsideLocalPromptKind.wepRonpetIntention:
        return 'Ausar - one word\nHeru Wer - one word\nSet - one word\nAset - one word\nNebet-Het - one word\nYear intention...';
    }
  }
}

class _OpenHandLocalNotesPanel extends StatefulWidget {
  const _OpenHandLocalNotesPanel({required this.flowId, required this.event});

  final int flowId;
  final OpenHandEvent event;

  @override
  State<_OpenHandLocalNotesPanel> createState() =>
      _OpenHandLocalNotesPanelState();
}

class _OpenHandLocalNotesPanelState extends State<_OpenHandLocalNotesPanel> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _deferredController = TextEditingController();
  final TheOpenHandLocalStore _store = const TheOpenHandLocalStore();
  bool _loading = true;
  bool _saving = false;
  bool _actCompleted = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _OpenHandLocalNotesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flowId != widget.flowId ||
        oldWidget.event.eventNumber != widget.event.eventNumber) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _deferredController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final text = await _store.loadPromptText(
      widget.flowId,
      widget.event.localPrompt,
    );
    final completed = await _store.loadActCompleted(
      widget.flowId,
      widget.event.eventNumber,
    );
    final deferred = widget.event.strangerAct
        ? await _store.loadDeferredStrangerActDate(widget.flowId)
        : '';
    if (!mounted) return;
    _controller.text = text;
    _deferredController.text = deferred;
    setState(() {
      _actCompleted = completed;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _store.savePromptText(
        widget.flowId,
        widget.event.localPrompt,
        _controller.text,
      );
      if (widget.event.strangerAct) {
        await _store.saveDeferredStrangerActDate(
          widget.flowId,
          _deferredController.text,
        );
      }
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved on this device only.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save local Open Hand notes.')),
      );
    }
  }

  Future<void> _setActCompleted(bool value) async {
    if (_saving) return;
    setState(() {
      _actCompleted = value;
      _saving = true;
    });
    await _store.saveActCompleted(
      widget.flowId,
      widget.event.eventNumber,
      value,
    );
    if (!mounted) return;
    setState(() => _saving = false);
  }

  Future<void> _clear() async {
    if (_saving) return;
    setState(() => _saving = true);
    await _store.savePromptText(widget.flowId, widget.event.localPrompt, '');
    if (widget.event.requiresOutwardAct) {
      await _store.saveActCompleted(
        widget.flowId,
        widget.event.eventNumber,
        false,
      );
    }
    if (widget.event.strangerAct) {
      await _store.saveDeferredStrangerActDate(widget.flowId, '');
    }
    if (!mounted) return;
    _controller.clear();
    _deferredController.clear();
    setState(() {
      _actCompleted = false;
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFD486).withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.event.localPrompt.label,
            style: const TextStyle(
              color: Color(0xFFFFD486),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Record names, needs, act details, and commitments for this step.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (widget.event.requiresOutwardAct) ...[
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _actCompleted,
              onChanged: _loading || _saving
                  ? null
                  : (value) => unawaited(_setActCompleted(value == true)),
              activeColor: _dayGold,
              checkColor: Colors.black,
              title: const Text(
                'I completed the outward act',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Observed unlocks after you mark the outward act complete.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (_loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextField(
              controller: _controller,
              minLines:
                  widget.event.eventNumber == 4 ||
                      widget.event.eventNumber == 6 ||
                      widget.event.eventNumber == 9
                  ? 4
                  : 3,
              maxLines: 8,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF090A0D),
                hintText: widget.event.localPrompt.placeholder,
                hintStyle: const TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _dayGold),
                ),
              ),
            ),
          if (widget.event.strangerAct) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _deferredController,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF090A0D),
                hintText:
                    'If skipped: specific future date for the stranger act',
                hintStyle: const TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _dayGold),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  onPressed: _saving || _loading ? null : _clear,
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _dayGold,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _saving || _loading ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save local'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DjedLocalNotesPanel extends StatefulWidget {
  const _DjedLocalNotesPanel({required this.flowId, required this.event});

  final int flowId;
  final DjedEvent event;

  @override
  State<_DjedLocalNotesPanel> createState() => _DjedLocalNotesPanelState();
}

class _DjedLocalNotesPanelState extends State<_DjedLocalNotesPanel> {
  final TextEditingController _controller = TextEditingController();
  final TheDjedLocalStore _store = const TheDjedLocalStore();
  bool _loading = true;
  bool _saving = false;
  bool _directEngagementCompleted = false;
  bool _raisingCompleted = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _DjedLocalNotesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flowId != widget.flowId ||
        oldWidget.event.eventNumber != widget.event.eventNumber) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final text = await _store.loadPromptText(
      widget.flowId,
      widget.event.localPrompt,
    );
    final directCompleted = await _store.loadDirectEngagementCompleted(
      widget.flowId,
    );
    final raisingCompleted = await _store.loadRaisingCompleted(widget.flowId);
    if (!mounted) return;
    _controller.text = text;
    setState(() {
      _directEngagementCompleted = directCompleted;
      _raisingCompleted = raisingCompleted;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _store.savePromptText(
        widget.flowId,
        widget.event.localPrompt,
        _controller.text,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved on this device only.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save local Djed notes.')),
      );
    }
  }

  Future<void> _setDirectEngagementCompleted(bool value) async {
    if (_saving) return;
    setState(() {
      _directEngagementCompleted = value;
      _saving = true;
    });
    await _store.saveDirectEngagementCompleted(widget.flowId, value);
    if (!mounted) return;
    setState(() => _saving = false);
  }

  Future<void> _setRaisingCompleted(bool value) async {
    if (_saving) return;
    setState(() {
      _raisingCompleted = value;
      _saving = true;
    });
    await _store.saveRaisingCompleted(widget.flowId, value);
    if (!mounted) return;
    setState(() => _saving = false);
  }

  Future<void> _clear() async {
    if (_saving) return;
    setState(() => _saving = true);
    await _store.savePromptText(widget.flowId, widget.event.localPrompt, '');
    if (widget.event.requiresDirectEngagement) {
      await _store.saveDirectEngagementCompleted(widget.flowId, false);
    }
    if (widget.event.physicalRaising) {
      await _store.saveRaisingCompleted(widget.flowId, false);
    }
    if (!mounted) return;
    _controller.clear();
    setState(() {
      _directEngagementCompleted = false;
      _raisingCompleted = false;
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF9BD0A5).withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.event.localPrompt.label,
            style: const TextStyle(
              color: Color(0xFFB8E6BD),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Record spine labels, wobble notes, battle commitments, and raising notes for this step.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (widget.event.eventNumber == 1) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SpineCondition.values.map((condition) {
                return Chip(
                  label: Text(condition.label),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: const Color(0xFF15171B),
                  side: const BorderSide(color: Colors.white24),
                  labelStyle: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
          ],
          if (widget.event.eventNumber == 8) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0C0F),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF9BD0A5)),
              ),
              child: const Text(
                'Next event requires standing room for about 30 seconds.',
                style: TextStyle(
                  color: Color(0xFFB8E6BD),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (widget.event.requiresDirectEngagement) ...[
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _directEngagementCompleted,
              onChanged: _loading || _saving
                  ? null
                  : (value) =>
                        unawaited(_setDirectEngagementCompleted(value == true)),
              activeColor: _dayGold,
              checkColor: Colors.black,
              title: const Text(
                'I engaged the challenge directly',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Record what actually happened; no false victory is required.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
          if (widget.event.physicalRaising) ...[
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _raisingCompleted,
              onChanged: _loading || _saving
                  ? null
                  : (value) => unawaited(_setRaisingCompleted(value == true)),
              activeColor: _dayGold,
              checkColor: Colors.black,
              title: const Text(
                'I stood upright and raised my arms for at least 30 seconds',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Raised unlocks after you mark the raising act complete.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (_loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextField(
              controller: _controller,
              minLines:
                  widget.event.eventNumber == 1 ||
                      widget.event.eventNumber == 4 ||
                      widget.event.eventNumber == 9
                  ? 4
                  : 3,
              maxLines: 8,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF090A0D),
                hintText: widget.event.localPrompt.placeholder,
                hintStyle: const TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _dayGold),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  onPressed: _saving || _loading ? null : _clear,
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _dayGold,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _saving || _loading ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save local'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
