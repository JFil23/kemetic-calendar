import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/flow_appearance.dart';
import '../../utils/detail_sanitizer.dart';
import '../calendar/presentation/user_flow_appearance_visual.dart';

const Color _artifactBone = Color(0xFFF2ECE0);
const Color _artifactMuted = Color(0xFF9E9A94);
const Color _artifactPanel = Color(0xFF0D0B08);
const double _artifactHeight = 236;
const double _artifactHeroHeight = 150;
const double _artifactCopyHeight = 84;
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
    this.clock,
  });

  final String name;
  final int color;
  final String? notes;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<dynamic> events;
  final FlowAppearance appearance;
  final Uint8List? localImageBytes;
  final DateTime Function()? clock;

  Color get _accent => appearance.accentArgb == null
      ? Color(0xFF000000 | (color & 0x00FFFFFF))
      : Color(appearance.accentArgb!);

  Color get _accentText => Color.lerp(_accent, _artifactBone, 0.58)!;

  int get _totalProgressUnits {
    var largestOffset = -1;
    for (final raw in events) {
      if (raw is! Map) continue;
      final offset = (raw['offset_days'] as num?)?.toInt();
      if (offset != null && offset >= 0) {
        largestOffset = math.max(largestOffset, offset);
      }
    }
    if (largestOffset >= 0) return largestOffset + 1;

    if (startDate != null && endDate != null) {
      final start = DateUtils.dateOnly(startDate!);
      final end = DateUtils.dateOnly(endDate!);
      return math.max(0, end.difference(start).inDays + 1);
    }
    return 0;
  }

  int get _currentProgressUnit {
    final total = _totalProgressUnits;
    if (total <= 0 || startDate == null) return 0;
    final start = DateUtils.dateOnly(startDate!);
    final today = DateUtils.dateOnly((clock ?? DateTime.now)());
    return (today.difference(start).inDays + 1).clamp(0, total);
  }

  String get _spanLabel {
    final total = _totalProgressUnits;
    if (total > 0) return '$total ${total == 1 ? 'day' : 'days'}';
    if (events.isNotEmpty) {
      final count = events.length;
      return '$count ${count == 1 ? 'occurrence' : 'occurrences'}';
    }
    return 'Flow';
  }

  String? get _readoutLabel {
    final total = _totalProgressUnits;
    if (total <= 0 || startDate == null) return null;
    return 'DAY $_currentProgressUnit OF $total';
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    final accentText = _accentText;
    final title = cleanFlowTitle(name);
    final resolvedTitle = title.isEmpty ? 'Untitled Flow' : title;
    final overview = cleanFlowOverview(notes);
    final readoutLabel = _readoutLabel;
    final radius = BorderRadius.circular(16);

    return Semantics(
      container: true,
      label: '$resolvedTitle, $_spanLabel',
      child: SizedBox(
        height: _artifactHeight,
        child: Container(
          key: const ValueKey<String>('posted-flow-artifact'),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _artifactPanel,
            borderRadius: radius,
            border: Border.all(color: accent.withValues(alpha: 0.42)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                height: _artifactHeroHeight,
                child: Stack(
                  fit: StackFit.expand,
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
                      completedOccurrences: _currentProgressUnit,
                      totalOccurrences: _totalProgressUnits,
                      signSize: 136,
                      showSignLabel: false,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
                    ),
                    const IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Color(0x05080806),
                              Color(0xE60D0B08),
                            ],
                            stops: <double>[0.38, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 11,
                      right: 11,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xA8090806),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.42),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          child: Text(
                            _spanLabel.toUpperCase(),
                            style: TextStyle(
                              color: accentText,
                              fontFamily: 'Inter',
                              fontSize: 8,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 1.6,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (readoutLabel != null)
                      Positioned(
                        left: 12,
                        bottom: 10,
                        child: Text(
                          readoutLabel,
                          style: TextStyle(
                            color: accentText,
                            fontFamily: 'Inter',
                            fontSize: 8.5,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.53,
                            height: 1,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: _artifactCopyHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(15, 6, 15, 0),
                  child: ClipRect(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _typeLabel(appearance.signKind),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accent,
                            fontFamily: 'Inter',
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.68,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          resolvedTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _artifactBone,
                            fontFamily: 'CormorantGaramond',
                            fontFamilyFallback: _artifactSerifFallback,
                            fontSize: 21,
                            fontWeight: FontWeight.w500,
                            height: 1.08,
                          ),
                        ),
                        if (overview.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 3),
                          Text(
                            overview,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _artifactMuted,
                              fontFamily: 'CormorantGaramond',
                              fontFamilyFallback: _artifactSerifFallback,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              fontStyle: FontStyle.italic,
                              height: 1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _typeLabel(FlowSignKind? kind) {
    if (kind == null) return 'FLOW';
    return 'FLOW · ${switch (kind) {
      FlowSignKind.palmCount => 'PALM COUNT',
      FlowSignKind.shen => 'SHEN CYCLE',
      FlowSignKind.gatheringVessel => 'GATHERING VESSEL',
      FlowSignKind.riverPath => 'RIVER PATH',
      FlowSignKind.papyrus => 'PAPYRUS GROWTH',
      FlowSignKind.kheper => 'KHEPER',
    }}';
  }
}
