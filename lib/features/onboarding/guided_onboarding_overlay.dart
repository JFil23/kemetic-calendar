import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile/shared/glossy_text.dart';

enum CoachmarkVariant { onboarding, helperBubble }

enum CoachmarkPlacement {
  auto,
  above,
  below,
  left,
  right,
  bottomCompact,
  center,
}

class CoachmarkTarget {
  const CoachmarkTarget({
    this.key,
    this.secondaryKeys = const <GlobalKey>[],
    required this.title,
    required this.body,
    this.instruction,
    this.placement = CoachmarkPlacement.auto,
    this.variant = CoachmarkVariant.onboarding,
    this.allowBackgroundInteraction = true,
    this.showNextButton = false,
    this.nextLabel = 'Next',
    this.onNext,
    this.showDismissButton = false,
    this.dismissLabel = 'Dismiss',
    this.onDismiss,
    this.showSkipButton = false,
    this.onSkip,
  });

  final GlobalKey? key;
  final List<GlobalKey> secondaryKeys;
  final String title;
  final String body;
  final String? instruction;
  final CoachmarkPlacement placement;
  final CoachmarkVariant variant;
  final bool allowBackgroundInteraction;
  final bool showNextButton;
  final String nextLabel;
  final VoidCallback? onNext;
  final bool showDismissButton;
  final String dismissLabel;
  final VoidCallback? onDismiss;
  final bool showSkipButton;
  final VoidCallback? onSkip;
}

class GuidedOnboardingController extends ChangeNotifier {
  GuidedOnboardingController._();

  static final GuidedOnboardingController instance =
      GuidedOnboardingController._();

  CoachmarkTarget? _target;
  bool _suppressExternalOverlays = false;

  CoachmarkTarget? get target => _target;
  bool get suppressExternalOverlays =>
      _suppressExternalOverlays || _target != null;

  void show(CoachmarkTarget target) {
    _target = target;
    notifyListeners();
  }

  void clear() {
    if (_target == null) return;
    _target = null;
    notifyListeners();
  }

  void setExternalOverlaySuppressed(bool suppressed) {
    if (_suppressExternalOverlays == suppressed) return;
    _suppressExternalOverlays = suppressed;
    notifyListeners();
  }
}

class GuidedOnboardingOverlayHost extends StatelessWidget {
  const GuidedOnboardingOverlayHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: GuidedOnboardingController.instance,
      builder: (context, _) {
        final target = GuidedOnboardingController.instance.target;
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (target != null)
              Positioned.fill(child: GuidedOnboardingOverlay(target: target)),
          ],
        );
      },
    );
  }
}

class GuidedOnboardingOverlay extends StatefulWidget {
  const GuidedOnboardingOverlay({super.key, required this.target});

  final CoachmarkTarget target;

  @override
  State<GuidedOnboardingOverlay> createState() =>
      _GuidedOnboardingOverlayState();
}

class _CoachmarkGeometry {
  const _CoachmarkGeometry({
    required this.offset,
    required this.placement,
    required this.arrowOffset,
  });

  final Offset offset;
  final CoachmarkPlacement placement;
  final Offset? arrowOffset;
}

class _GuidedOnboardingOverlayState extends State<GuidedOnboardingOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1350),
  )..repeat(reverse: true);
  Timer? _refreshTimer;
  List<Rect> _targetRects = const <Rect>[];

  @override
  void initState() {
    super.initState();
    _scheduleRefresh();
  }

  @override
  void didUpdateWidget(covariant GuidedOnboardingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _scheduleRefresh();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshRects());
    _refreshTimer = Timer.periodic(
      const Duration(milliseconds: 240),
      (_) => _refreshRects(),
    );
  }

  void _refreshRects() {
    if (!mounted) return;
    final next = <Rect>[];
    final keys = <GlobalKey>[
      if (widget.target.key != null) widget.target.key!,
      ...widget.target.secondaryKeys,
    ];
    for (final key in keys) {
      final context = key.currentContext;
      final renderObject = context?.findRenderObject();
      if (renderObject is! RenderBox ||
          !renderObject.hasSize ||
          renderObject.size.isEmpty) {
        continue;
      }
      final topLeft = renderObject.localToGlobal(Offset.zero);
      next.add(topLeft & renderObject.size);
    }
    if (_sameRects(_targetRects, next)) return;
    setState(() => _targetRects = next);
  }

  bool _sameRects(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i].left - b[i].left).abs() > 0.5 ||
          (a[i].top - b[i].top).abs() > 0.5 ||
          (a[i].width - b[i].width).abs() > 0.5 ||
          (a[i].height - b[i].height).abs() > 0.5) {
        return false;
      }
    }
    return true;
  }

  Rect? get _primaryRect => _targetRects.isEmpty ? null : _targetRects.first;

  _CoachmarkGeometry _geometry({
    required Size size,
    required EdgeInsets safePadding,
    required double cardWidth,
    required double estimatedCardHeight,
  }) {
    if (widget.target.variant == CoachmarkVariant.helperBubble) {
      return _helperBubbleGeometry(
        size: size,
        safePadding: safePadding,
        cardWidth: cardWidth,
        estimatedCardHeight: estimatedCardHeight,
      );
    }

    final rect = _primaryRect;
    if (rect == null || widget.target.placement == CoachmarkPlacement.center) {
      return _CoachmarkGeometry(
        offset: Offset(
          (size.width - cardWidth) / 2,
          (size.height - estimatedCardHeight) / 2,
        ),
        placement: CoachmarkPlacement.center,
        arrowOffset: null,
      );
    }

    final placement = widget.target.placement == CoachmarkPlacement.auto
        ? (rect.center.dy > size.height * 0.52
              ? CoachmarkPlacement.above
              : CoachmarkPlacement.below)
        : widget.target.placement;

    final x = (rect.center.dx - cardWidth / 2).clamp(
      16.0,
      math.max(16.0, size.width - cardWidth - 16),
    );
    final maxY = math.max(18.0, size.height - estimatedCardHeight - 18);
    final y = placement == CoachmarkPlacement.above
        ? (rect.top - estimatedCardHeight - 18).clamp(18.0, maxY)
        : (rect.bottom + 18).clamp(18.0, maxY);
    return _CoachmarkGeometry(
      offset: Offset(x.toDouble(), y.toDouble()),
      placement: placement,
      arrowOffset: null,
    );
  }

  _CoachmarkGeometry _helperBubbleGeometry({
    required Size size,
    required EdgeInsets safePadding,
    required double cardWidth,
    required double estimatedCardHeight,
  }) {
    final rect = _primaryRect;
    final margin = 14.0;
    final gap = 12.0;
    final safeLeft = margin + safePadding.left;
    final safeRight = size.width - margin - safePadding.right;
    final safeTop = math.max(margin, safePadding.top + 8);
    final safeBottom = size.height - math.max(margin, safePadding.bottom + 12);
    final maxX = math.max(safeLeft, safeRight - cardWidth);
    final maxY = math.max(safeTop, safeBottom - estimatedCardHeight);

    if (rect == null || widget.target.placement == CoachmarkPlacement.center) {
      final y = math.min(
        maxY,
        math.max(safeTop, size.height - estimatedCardHeight - 28),
      );
      return _CoachmarkGeometry(
        offset: Offset(((size.width - cardWidth) / 2).clamp(safeLeft, maxX), y),
        placement: CoachmarkPlacement.bottomCompact,
        arrowOffset: null,
      );
    }

    CoachmarkPlacement resolvePlacement() {
      final requested = widget.target.placement;
      if (requested != CoachmarkPlacement.auto) return requested;
      if (rect.bottom + gap + estimatedCardHeight <= safeBottom) {
        return CoachmarkPlacement.below;
      }
      if (rect.top - gap - estimatedCardHeight >= safeTop) {
        return CoachmarkPlacement.above;
      }
      if (rect.right + gap + cardWidth <= safeRight) {
        return CoachmarkPlacement.right;
      }
      if (rect.left - gap - cardWidth >= safeLeft) {
        return CoachmarkPlacement.left;
      }
      return CoachmarkPlacement.bottomCompact;
    }

    final placement = resolvePlacement();
    final (x, y) = switch (placement) {
      CoachmarkPlacement.above => (
        (rect.center.dx - cardWidth / 2).clamp(safeLeft, maxX).toDouble(),
        (rect.top - estimatedCardHeight - gap).clamp(safeTop, maxY).toDouble(),
      ),
      CoachmarkPlacement.below => (
        (rect.center.dx - cardWidth / 2).clamp(safeLeft, maxX).toDouble(),
        (rect.bottom + gap).clamp(safeTop, maxY).toDouble(),
      ),
      CoachmarkPlacement.left => (
        (rect.left - cardWidth - gap).clamp(safeLeft, maxX).toDouble(),
        (rect.center.dy - estimatedCardHeight / 2)
            .clamp(safeTop, maxY)
            .toDouble(),
      ),
      CoachmarkPlacement.right => (
        (rect.right + gap).clamp(safeLeft, maxX).toDouble(),
        (rect.center.dy - estimatedCardHeight / 2)
            .clamp(safeTop, maxY)
            .toDouble(),
      ),
      CoachmarkPlacement.bottomCompact ||
      CoachmarkPlacement.auto ||
      CoachmarkPlacement.center => (
        (rect.center.dx - cardWidth / 2).clamp(safeLeft, maxX).toDouble(),
        math
            .max(rect.bottom + gap, safeBottom - estimatedCardHeight)
            .clamp(safeTop, maxY)
            .toDouble(),
      ),
    };

    final arrowOffset = switch (placement) {
      CoachmarkPlacement.above || CoachmarkPlacement.below => Offset(
        (rect.center.dx - x).clamp(26.0, cardWidth - 26.0).toDouble(),
        0,
      ),
      CoachmarkPlacement.left || CoachmarkPlacement.right => Offset(
        0,
        (rect.center.dy - y).clamp(24.0, estimatedCardHeight - 24.0).toDouble(),
      ),
      _ => null,
    };

    return _CoachmarkGeometry(
      offset: Offset(x, y),
      placement: placement,
      arrowOffset: arrowOffset,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final target = widget.target;
        final isHelper = target.variant == CoachmarkVariant.helperBubble;
        final cardWidth = isHelper
            ? math.min(size.width - 28, 320.0).clamp(220.0, 320.0).toDouble()
            : math.min(size.width - 32, 360.0);
        final estimatedCardHeight = isHelper
            ? (target.instruction == null ? 146.0 : 168.0)
            : 206.0;
        final geometry = _geometry(
          size: size,
          safePadding: MediaQuery.paddingOf(context),
          cardWidth: cardWidth,
          estimatedCardHeight: estimatedCardHeight,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              ignoring: target.allowBackgroundInteraction,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _CoachmarkPainter(
                      rects: _targetRects,
                      pulse: _pulseController.value,
                      variant: target.variant,
                    ),
                  );
                },
              ),
            ),
            if (!target.allowBackgroundInteraction)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: const SizedBox.expand(),
                ),
              ),
            Positioned(
              left: geometry.offset.dx,
              top: geometry.offset.dy,
              width: cardWidth,
              child: CoachmarkCard(
                target: target,
                resolvedPlacement: geometry.placement,
                arrowOffset: geometry.arrowOffset,
              ),
            ),
            if (target.showNextButton)
              Positioned(
                top: math.max(MediaQuery.paddingOf(context).top + 22, 42.0),
                right: math.max(18.0, size.width * 0.08),
                child: PulsingNextButton(
                  label: target.nextLabel,
                  onPressed: target.onNext,
                ),
              ),
            if (target.showSkipButton)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 12,
                left: 14,
                child: TextButton(
                  onPressed: target.onSkip,
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
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

class CoachmarkCard extends StatelessWidget {
  const CoachmarkCard({
    super.key,
    required this.target,
    required this.resolvedPlacement,
    required this.arrowOffset,
  });

  final CoachmarkTarget target;
  final CoachmarkPlacement resolvedPlacement;
  final Offset? arrowOffset;

  bool get _isHelper => target.variant == CoachmarkVariant.helperBubble;

  @override
  Widget build(BuildContext context) {
    final card = Semantics(
      container: true,
      liveRegion: true,
      label: [
        target.title,
        target.body,
        if (target.instruction != null) target.instruction!,
      ].join('. '),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: _isHelper
              ? const EdgeInsets.fromLTRB(14, 12, 14, 10)
              : const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: _isHelper
                ? const Color(0xEA090909)
                : const Color(0xF20A0A0A),
            borderRadius: BorderRadius.circular(_isHelper ? 17 : 16),
            border: Border.all(
              color: KemeticGold.base.withValues(
                alpha: _isHelper ? 0.45 : 0.42,
              ),
              width: _isHelper ? 1 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isHelper ? 0.32 : 0.54),
                blurRadius: _isHelper ? 14 : 24,
                offset: Offset(0, _isHelper ? 7 : 12),
              ),
              BoxShadow(
                color: KemeticGold.base.withValues(
                  alpha: _isHelper ? 0.08 : 0.10,
                ),
                blurRadius: _isHelper ? 18 : 30,
                spreadRadius: _isHelper ? 1 : 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isHelper)
                KemeticGold.text(
                  target.title,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.14,
                    fontWeight: FontWeight.w800,
                  ),
                )
              else
                KemeticGold.text(
                  target.title,
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              SizedBox(height: _isHelper ? 6 : 8),
              Text(
                target.body,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontSize: _isHelper ? 13.2 : 14,
                  height: _isHelper ? 1.32 : 1.38,
                ),
              ),
              if (target.instruction != null) ...[
                SizedBox(height: _isHelper ? 8 : 12),
                Text(
                  target.instruction!,
                  style: const TextStyle(
                    color: Color(0xFFFFE7A3),
                    fontSize: 13,
                    height: 1.34,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (target.showDismissButton) ...[
                SizedBox(height: _isHelper ? 6 : 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    style: _isHelper
                        ? TextButton.styleFrom(
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          )
                        : null,
                    onPressed:
                        target.onDismiss ??
                        GuidedOnboardingController.instance.clear,
                    child: KemeticGold.text(
                      _isHelper && target.dismissLabel == 'Dismiss'
                          ? 'Got it'
                          : target.dismissLabel,
                      style: TextStyle(
                        fontSize: _isHelper ? 13.5 : null,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (!_isHelper || arrowOffset == null) {
      return card;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        _HelperBubbleArrow(placement: resolvedPlacement, offset: arrowOffset!),
        card,
      ],
    );
  }
}

class _HelperBubbleArrow extends StatelessWidget {
  const _HelperBubbleArrow({required this.placement, required this.offset});

  final CoachmarkPlacement placement;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    final diamond = Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: const Color(0xEA090909),
          border: Border.all(
            color: KemeticGold.base.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
      ),
    );

    return switch (placement) {
      CoachmarkPlacement.below => Positioned(
        left: offset.dx - 5,
        top: -5,
        child: diamond,
      ),
      CoachmarkPlacement.above => Positioned(
        left: offset.dx - 5,
        bottom: -5,
        child: diamond,
      ),
      CoachmarkPlacement.right => Positioned(
        left: -5,
        top: offset.dy - 5,
        child: diamond,
      ),
      CoachmarkPlacement.left => Positioned(
        right: -5,
        top: offset.dy - 5,
        child: diamond,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class PulsingNextButton extends StatefulWidget {
  const PulsingNextButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  State<PulsingNextButton> createState() => _PulsingNextButtonState();
}

class _PulsingNextButtonState extends State<PulsingNextButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label == 'Next' ? 'Next onboarding step' : widget.label,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_controller.value);
          return Transform.scale(
            scale: 1 + (t * 0.045),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: KemeticGold.base.withValues(alpha: 0.20 + t * 0.20),
                    blurRadius: 12 + (t * 10),
                    spreadRadius: 1 + (t * 3),
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: KemeticGold.base,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          onPressed: widget.onPressed,
          child: Text(
            widget.label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _CoachmarkPainter extends CustomPainter {
  _CoachmarkPainter({
    required this.rects,
    required this.pulse,
    required this.variant,
  });

  final List<Rect> rects;
  final double pulse;
  final CoachmarkVariant variant;

  @override
  void paint(Canvas canvas, Size size) {
    final isHelper = variant == CoachmarkVariant.helperBubble;
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(
        alpha: isHelper
            ? (rects.isEmpty ? 0.12 : 0.10)
            : (rects.isEmpty ? 0.38 : 0.26),
      );
    canvas.drawRect(Offset.zero & size, overlayPaint);

    for (final rect in rects) {
      final inflated = rect.inflate(
        (isHelper ? 6 : 10) + pulse * (isHelper ? 3 : 5),
      );
      final radius = Radius.circular(math.min(18, inflated.height / 2));
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (isHelper ? 1.6 : 2.2) + pulse * (isHelper ? 0.8 : 1.2)
        ..color = KemeticGold.base.withValues(
          alpha: (isHelper ? 0.42 : 0.48) + pulse * (isHelper ? 0.22 : 0.30),
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isHelper ? 4 : 6);
      final edgePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHelper ? 1.1 : 1.4
        ..color = const Color(
          0xFFFFE8A3,
        ).withValues(alpha: isHelper ? 0.68 : 0.78);
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = KemeticGold.base.withValues(
          alpha: (isHelper ? 0.035 : 0.06) + pulse * (isHelper ? 0.02 : 0.035),
        );

      canvas.drawRRect(RRect.fromRectAndRadius(inflated, radius), fillPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(inflated, radius), glowPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(inflated, radius), edgePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CoachmarkPainter oldDelegate) {
    return oldDelegate.rects != rects ||
        oldDelegate.pulse != pulse ||
        oldDelegate.variant != variant;
  }
}
