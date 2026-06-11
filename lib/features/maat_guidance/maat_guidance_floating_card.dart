import 'dart:async';

import 'package:flutter/material.dart';
import '../../data/maat_guidance_model.dart';
import 'package:mobile/features/onboarding/guided_onboarding_overlay.dart';
import '../../shared/glossy_text.dart';
import 'maat_guidance_controller.dart';

const maatGuidanceOrientationLowerThirdBadgeKey = ValueKey<String>(
  'maat-guidance-orientation-lower-third-badge',
);
const maatGuidanceOrientationLowerThirdDismissButtonKey = ValueKey<String>(
  'maat-guidance-orientation-lower-third-dismiss',
);

class MaatGuidanceOverlayHost extends StatelessWidget {
  const MaatGuidanceOverlayHost({
    super.key,
    required this.controller,
    required this.onOpen,
    required this.visible,
  });

  final MaatGuidanceController controller;
  final ValueChanged<MaatGuidanceDelivery> onOpen;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: GuidedOnboardingController.instance,
      builder: (context, _) {
        final delivery = controller.current;
        if (!visible ||
            GuidedOnboardingController.instance.suppressExternalOverlays ||
            delivery == null) {
          return const SizedBox.shrink();
        }

        if (delivery.isDeterministicWeighingOpeningOrientation) {
          final media = MediaQuery.of(context);
          return Positioned(
            right: 12,
            bottom: 16 + media.padding.bottom,
            child: MaatGuidanceOrientationLowerThirdBadge(
              delivery: delivery,
              maxWidth: media.size.width * 0.72,
              onDismiss: () => unawaited(controller.dismissCurrent()),
              onOpen: () => onOpen(delivery),
            ),
          );
        }

        return Positioned.fill(
          child: _MaatGuidanceScrim(
            onDismiss: () => unawaited(controller.dismissCurrent()),
            child: Center(
              child: MaatGuidanceFloatingCard(
                delivery: delivery,
                onDismiss: () => unawaited(controller.dismissCurrent()),
                onOpen: () => onOpen(delivery),
              ),
            ),
          ),
        );
      },
    );
  }
}

class MaatGuidanceOrientationLowerThirdBadge extends StatelessWidget {
  const MaatGuidanceOrientationLowerThirdBadge({
    super.key = maatGuidanceOrientationLowerThirdBadgeKey,
    required this.delivery,
    required this.maxWidth,
    required this.onDismiss,
    required this.onOpen,
  });

  final MaatGuidanceDelivery delivery;
  final double maxWidth;
  final VoidCallback onDismiss;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${delivery.lowerThirdBadgeTitle}: ${delivery.lowerThirdBadgeText}',
      button: true,
      child: Material(
        color: Colors.black.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        elevation: 8,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.explore_outlined,
                    color: KemeticGold.base,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          delivery.lowerThirdBadgeTitle,
                          style: const TextStyle(
                            color: KemeticGold.base,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          delivery.lowerThirdBadgeText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            height: 1.25,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox.square(
                    dimension: 34,
                    child: Semantics(
                      label: 'Dismiss orientation',
                      button: true,
                      child: IconButton(
                        key: maatGuidanceOrientationLowerThirdDismissButtonKey,
                        padding: EdgeInsets.zero,
                        tooltip: 'Dismiss',
                        icon: const Icon(Icons.close, size: 18),
                        color: Colors.white70,
                        onPressed: onDismiss,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MaatGuidanceScrim extends StatelessWidget {
  const _MaatGuidanceScrim({required this.child, required this.onDismiss});

  final Widget child;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 180),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: const ColoredBox(color: Color(0x33000000)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class MaatGuidanceFloatingCard extends StatelessWidget {
  const MaatGuidanceFloatingCard({
    super.key,
    required this.delivery,
    required this.onDismiss,
    required this.onOpen,
  });

  final MaatGuidanceDelivery delivery;
  final VoidCallback onDismiss;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final title = delivery.bannerTitle;
    return Semantics(
      label: title,
      button: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width < 520 ? width - 40 : 420,
          minWidth: width < 360 ? width - 40 : 320,
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.96, end: 1),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onOpen,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xF20D0D10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: KemeticGold.base.withValues(alpha: 0.42),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x99000000),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 10, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: KemeticGold.text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          SizedBox.square(
                            dimension: 36,
                            child: Semantics(
                              label: 'Dismiss',
                              button: true,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close, size: 19),
                                color: Colors.white70,
                                onPressed: onDismiss,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        delivery.displayTeaserText,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.42,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: onOpen,
                          style: TextButton.styleFrom(
                            foregroundColor: KemeticGold.base,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: const Size(0, 38),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            delivery.hasCta ? 'Open guidance' : 'Read guidance',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
