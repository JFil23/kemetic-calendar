import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/flow_appearance.dart';
import '../../utils/detail_sanitizer.dart';
import '../calendar/presentation/user_flow_appearance_visual.dart';

const Color _artifactBone = Color(0xFFF2ECE0);
const Color _artifactMuted = Color(0xFFA69A83);
const double _artifactHeight = 300;
const double _artifactHeroHeight = 148;
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
    this.localImageBytes,
  });

  final String name;
  final int color;
  final String? notes;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<dynamic> events;
  final FlowAppearance appearance;
  final Uint8List? localImageBytes;

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
    final radius = BorderRadius.circular(20);

    return Semantics(
      container: true,
      label: '${title.isEmpty ? 'Untitled Flow' : title}, $_spanLabel',
      child: SizedBox(
        height: _artifactHeight,
        child: Container(
          key: const ValueKey<String>('posted-flow-artifact'),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xE6080705),
            borderRadius: radius,
            border: Border.all(color: accent.withValues(alpha: 0.48)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Stack(
                children: <Widget>[
                  UserFlowAppearanceHero(
                    key: const ValueKey<String>(
                      'posted-flow-artifact-appearance',
                    ),
                    appearance: appearance,
                    accent: accent,
                    localImageBytes: localImageBytes,
                    height: _artifactHeroHeight,
                    compact: false,
                    signSize: 136,
                    showSignLabel: false,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(19),
                    ),
                  ),
                  Positioned(
                    top: 11,
                    right: 11,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xB8090806),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.42),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        child: Text(
                          _spanLabel.toUpperCase(),
                          style: TextStyle(
                            color: accent.withValues(alpha: 0.94),
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.35,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'FLOW · ${_signTypeLabel(appearance.signKind)}',
                        style: TextStyle(
                          color: accent.withValues(alpha: 0.92),
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.55,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title.isEmpty ? 'Untitled Flow' : title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _artifactBone,
                          fontFamily: 'CormorantGaramond',
                          fontFamilyFallback: _artifactSerifFallback,
                          fontSize: 25,
                          fontWeight: FontWeight.w500,
                          height: 1.02,
                        ),
                      ),
                      if (overview.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          overview,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _artifactMuted.withValues(alpha: 0.90),
                            fontFamily: 'CormorantGaramond',
                            fontFamilyFallback: _artifactSerifFallback,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            height: 1.28,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _signTypeLabel(FlowSignKind? kind) => switch (kind) {
    FlowSignKind.palmCount => 'PALM COUNT',
    FlowSignKind.shen => 'SHEN CYCLE',
    FlowSignKind.gatheringVessel => 'GATHERING VESSEL',
    FlowSignKind.riverPath => 'RIVER PATH',
    FlowSignKind.papyrus => 'PAPYRUS GROWTH',
    FlowSignKind.kheper => 'KHEPER',
    null => 'PRACTICE',
  };
}
