import 'package:flutter/material.dart';

import '../../data/flow_appearance.dart';
import '../../utils/detail_sanitizer.dart';
import '../calendar/presentation/user_flow_appearance_visual.dart';

const Color _artifactBone = Color(0xFFF2ECE0);
const Color _artifactMuted = Color(0xFFA69A83);
const List<String> _artifactSerifFallback = <String>[
  'GentiumPlus',
  'Georgia',
  'serif',
];

/// The portable visual identity of a posted user-created flow.
///
/// Author identity, caption, engagement, and owner controls deliberately stay
/// with the profile/feed/composer that contains this artifact. Keeping that
/// chrome outside prevents this widget from becoming another mode-switched
/// social card authority.
class PostedFlowArtifact extends StatelessWidget {
  const PostedFlowArtifact({
    super.key,
    required this.name,
    required this.color,
    required this.appearance,
    this.notes,
    this.startDate,
    this.endDate,
    this.events = const <dynamic>[],
    this.compact = false,
  });

  final String name;
  final int color;
  final String? notes;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<dynamic> events;
  final FlowAppearance appearance;
  final bool compact;

  Color get _accent => appearance.accentArgb == null
      ? Color(0xFF000000 | (color & 0x00FFFFFF))
      : Color(appearance.accentArgb!);

  String get _spanLabel {
    if (startDate != null && endDate != null) {
      final start = DateUtils.dateOnly(startDate!);
      final end = DateUtils.dateOnly(endDate!);
      final days = end.difference(start).inDays + 1;
      if (days > 0) return '$days ${days == 1 ? 'day' : 'days'}';
    }

    var largestOffset = -1;
    for (final raw in events) {
      if (raw is! Map) continue;
      final offset = (raw['offset_days'] as num?)?.toInt();
      if (offset != null && offset > largestOffset) largestOffset = offset;
    }
    if (largestOffset >= 0) {
      final days = largestOffset + 1;
      return '$days ${days == 1 ? 'day' : 'days'}';
    }
    if (events.isNotEmpty) {
      final count = events.length;
      return '$count ${count == 1 ? 'occurrence' : 'occurrences'}';
    }
    return 'Flow';
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    final title = cleanFlowTitle(name);
    final overview = cleanFlowOverview(notes);
    final radius = BorderRadius.circular(compact ? 16 : 20);

    return Semantics(
      container: true,
      label: '${title.isEmpty ? 'Untitled Flow' : title}, $_spanLabel',
      child: Container(
        key: const ValueKey<String>('posted-flow-artifact'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xE6080705),
          borderRadius: radius,
          border: Border.all(color: accent.withValues(alpha: 0.48)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accent.withValues(alpha: 0.10),
              blurRadius: compact ? 14 : 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (!appearance.isEmpty)
              UserFlowAppearanceHero(
                key: const ValueKey<String>('posted-flow-artifact-appearance'),
                appearance: appearance,
                accent: accent,
                height: compact ? 128 : 184,
                compact: false,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(19),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 14 : 18,
                appearance.isEmpty ? (compact ? 14 : 18) : (compact ? 12 : 15),
                compact ? 14 : 18,
                compact ? 14 : 17,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title.isEmpty ? 'Untitled Flow' : title,
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _artifactBone,
                      fontFamily: 'CormorantGaramond',
                      fontFamilyFallback: _artifactSerifFallback,
                      fontSize: compact ? 23 : 28,
                      fontWeight: FontWeight.w600,
                      height: 1.02,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 18,
                        height: 2,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _spanLabel.toUpperCase(),
                        style: TextStyle(
                          color: accent.withValues(alpha: 0.92),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.35,
                        ),
                      ),
                    ],
                  ),
                  if (overview.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 9),
                    Text(
                      overview,
                      maxLines: compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _artifactMuted.withValues(alpha: 0.90),
                        fontFamily: 'CormorantGaramond',
                        fontFamilyFallback: _artifactSerifFallback,
                        fontSize: compact ? 15 : 16,
                        fontWeight: FontWeight.w400,
                        height: 1.28,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
