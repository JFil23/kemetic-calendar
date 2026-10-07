import '../reflections/decan_review_controller.dart';
import '../reflections/decan_review_widgets.dart';
import 'package:flutter/material.dart';

import '../../data/decan_reflection_model.dart';
import '../../shared/glossy_text.dart';
import 'decan_reflection_composition/decan_reflection_composer.dart';

const decanReflectionLowerThirdBadgeKey = ValueKey<String>(
  'decan-reflection-lower-third-badge',
);

@immutable
class CalendarDecanReflectionPrompt {
  const CalendarDecanReflectionPrompt({
    required this.id,
    required this.decanName,
    required this.decanTheme,
    required this.decanStart,
    required this.decanEnd,
    required this.badgeCount,
    required this.reflectionText,
    required this.persisted,
    this.renderMetadata,
    this.reviewWindow,
  });

  final String? id;
  final String decanName;
  final String? decanTheme;
  final DateTime decanStart;
  final DateTime decanEnd;
  final int badgeCount;
  final String reflectionText;
  final bool persisted;
  final DecanReflectionRenderMetadata? renderMetadata;
  final DecanReviewWindow? reviewWindow;

  bool get isDeterministicSpectrum =>
      renderMetadata?.isDeterministicSpectrum == true;

  bool get isTheWeighingSpectrum =>
      renderMetadata?.isTheWeighingSpectrum == true;

  bool get isCompositionalV1 =>
      renderMetadata?.renderer == kDecanReflectionCompositionalRenderer;

  int get compositionalInteractionCount =>
      decanCompositionInteractionCountFromMetadata(renderMetadata);

  String get badgeText {
    if (isTheWeighingSpectrum) {
      final deterministicBadge = _compact(renderMetadata?.badgeBody);
      if (deterministicBadge != null) return deterministicBadge;
    }
    return _compact(reflectionText) ?? 'Decan reflection ready';
  }

  String get detailText {
    if (isTheWeighingSpectrum) {
      final deterministicDetail = _preserve(renderMetadata?.detailBody);
      if (deterministicDetail != null) return deterministicDetail;
    }
    return _preserve(reflectionText) ?? '';
  }

  static String? _compact(String? value) {
    final text = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String? _preserve(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}

class DecanReflectionLowerThirdBadge extends StatelessWidget {
  const DecanReflectionLowerThirdBadge({
    super.key = decanReflectionLowerThirdBadgeKey,
    required this.prompt,
    required this.maxWidth,
    required this.onTap,
  });

  final CalendarDecanReflectionPrompt prompt;
  final double maxWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (prompt.reviewWindow != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(99),
            child: Container(
              padding: const EdgeInsets.fromLTRB(13, 13, 20, 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: const Color(0x66D4AE43)),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1B140D), Color(0xFF120E0A)],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xAA000000),
                    blurRadius: 40,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DecanReviewSeal(),
                  const SizedBox(width: 15),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'These ten days',
                          style: DecanReviewStyle.serif(23, height: 1),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Your decan reflection',
                          style: DecanReviewStyle.ui(
                            11,
                            height: 1,
                            spacing: .22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: DecanReviewStyle.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Material(
      color: Colors.black.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(14),
      elevation: 8,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.menu_book_rounded,
                  color: KemeticGold.base,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Decan reflection',
                        style: TextStyle(
                          color: KemeticGold.base,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        prompt.badgeText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
