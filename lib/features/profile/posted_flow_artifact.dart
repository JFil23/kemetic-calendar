import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/flow_appearance.dart';
import '../../utils/detail_sanitizer.dart';
import 'posted_artifact_frame.dart';
import '../calendar/presentation/user_flow_appearance_visual.dart';

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
    this.allowImageFetch = true,
    this.imageCacheWidth,
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
  final bool allowImageFetch;
  final int? imageCacheWidth;
  final DateTime Function()? clock;

  Color get _accent => appearance.accentArgb == null
      ? Color(0xFF000000 | (color & 0x00FFFFFF))
      : Color(appearance.accentArgb!);

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
    final title = cleanFlowTitle(name);
    final resolvedTitle = title.isEmpty ? 'Untitled Flow' : title;
    return PostedArtifactFrame(
      artifactKey: const ValueKey<String>('posted-flow-artifact'),
      semanticLabel: '$resolvedTitle, $_spanLabel',
      accent: _accent,
      badgeLabel: _spanLabel,
      readoutLabel: _readoutLabel,
      typeLabel: _typeLabel(appearance.signKind),
      title: resolvedTitle,
      overview: cleanFlowOverview(notes),
      hero: UserFlowAppearanceHero(
        key: const ValueKey<String>('posted-flow-artifact-appearance'),
        appearance: appearance,
        accent: _accent,
        localImageBytes: localImageBytes,
        allowImageFetch: allowImageFetch,
        imageCacheWidth: imageCacheWidth,
        height: PostedArtifactFrame.heroHeight,
        compact: false,
        completedOccurrences: _currentProgressUnit,
        totalOccurrences: _totalProgressUnits,
        signSize: 136,
        showSignLabel: false,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
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
