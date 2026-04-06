import 'package:flutter/material.dart';
import 'package:mobile/shared/glossy_text.dart';

class OnboardingStep {
  const OnboardingStep({
    required this.title,
    required this.description,
    this.targetKey,
  });

  final String title;
  final String description;
  final GlobalKey? targetKey;
}

class OnboardingOverlay extends StatefulWidget {
  OnboardingOverlay({
    super.key,
    required this.steps,
    required this.onSkip,
    required this.onComplete,
  }) : assert(steps.isNotEmpty, 'At least one onboarding step is required.');

  final List<OnboardingStep> steps;
  final VoidCallback onSkip;
  final VoidCallback onComplete;

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> {
  final GlobalKey _overlayKey = GlobalKey();
  final GlobalKey _cardKey = GlobalKey();

  int _currentIndex = 0;
  Rect? _targetRect;
  Size? _cardSize;

  OnboardingStep get _step => widget.steps[_currentIndex];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateTargetRect());
  }

  @override
  void didUpdateWidget(covariant OnboardingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateTargetRect());
  }

  void _updateTargetRect() {
    final overlayBox =
        _overlayKey.currentContext?.findRenderObject() as RenderBox?;
    final targetCtx = _step.targetKey?.currentContext;
    final targetBox = targetCtx?.findRenderObject() as RenderBox?;

    Rect? nextTargetRect;
    if (overlayBox != null && targetBox != null && targetBox.hasSize) {
      final targetTopLeft = overlayBox.globalToLocal(
        targetBox.localToGlobal(Offset.zero),
      );
      nextTargetRect = targetTopLeft & targetBox.size;
    }

    Size? nextCardSize;
    final cardBox = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (cardBox != null && cardBox.hasSize) {
      nextCardSize = cardBox.size;
    }

    if (!mounted) return;

    if (nextTargetRect != _targetRect || nextCardSize != _cardSize) {
      setState(() {
        _targetRect = nextTargetRect;
        _cardSize = nextCardSize;
      });
    }
  }

  void _goNext() {
    if (_currentIndex < widget.steps.length - 1) {
      setState(() => _currentIndex++);
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateTargetRect());
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepNumber = _currentIndex + 1;
    final totalSteps = widget.steps.length;
    final isLast = stepNumber == totalSteps;

    final overlaySize =
        _overlayKey.currentContext?.size ?? MediaQuery.of(context).size;
    final double cardMaxWidth = (overlaySize.width - 24).clamp(240.0, 320.0);
    final double cardWidth = cardMaxWidth;
    final double estimatedHeight = _cardSize?.height ?? 160.0;
    final _CardPlacement placement = _computePlacement(
      overlaySize,
      _targetRect,
      cardWidth,
      estimatedHeight,
    );

    final Rect cardRect = Rect.fromLTWH(
      placement.left,
      placement.top,
      cardWidth,
      _cardSize?.height ?? estimatedHeight,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _updateTargetRect());

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: _overlayKey,
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: CustomPaint(
              painter: _SpotlightPainter(targetRect: _targetRect),
            ),
          ),
        ),
        if (_targetRect != null)
          IgnorePointer(
            child: Positioned(
              left: _targetRect!.left,
              top: _targetRect!.top,
              width: _targetRect!.width,
              height: _targetRect!.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.35),
                    width: 1.4,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 16,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_targetRect != null)
          Positioned(
            left: _arrowLeft(cardRect, _targetRect!),
            top: placement.placeAbove
                ? cardRect.bottom - 1
                : cardRect.top - _kArrowHeight + 1,
            child: IgnorePointer(
              child: CustomPaint(
                size: const Size(_kArrowWidth, _kArrowHeight),
                painter: _ArrowPainter(
                  pointingDown: placement.placeAbove,
                  color: _cardBg.withOpacity(0.95),
                  borderColor: Colors.white12,
                ),
              ),
            ),
          ),
        Positioned(
          left: cardRect.left,
          top: cardRect.top,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: cardMaxWidth, minWidth: 240),
            child: _OnboardingCard(
              key: _cardKey,
              title: _step.title,
              description: _step.description,
              stepLabel: 'Step $stepNumber of $totalSteps',
              isLast: isLast,
              onSkip: widget.onSkip,
              onNext: _goNext,
            ),
          ),
        ),
      ],
    );
  }

  _CardPlacement _computePlacement(
    Size overlaySize,
    Rect? target,
    double cardWidth,
    double cardHeight,
  ) {
    const gap = 10.0; // space between target and card (includes arrow)
    const margin = _kScreenMargin;

    if (target == null) {
      final left = (overlaySize.width - cardWidth) / 2;
      final top = overlaySize.height - cardHeight - margin;
      return _CardPlacement(
        left: left.clamp(margin, overlaySize.width - margin - cardWidth),
        top: top.clamp(margin, overlaySize.height - margin - cardHeight),
        placeAbove: false,
      );
    }

    final spaceBelow = overlaySize.height - target.bottom;
    final spaceAbove = target.top;
    bool placeAbove = spaceBelow < cardHeight + gap && spaceAbove > spaceBelow;

    double left = target.left;
    left = left.clamp(margin, overlaySize.width - margin - cardWidth);

    double top;
    if (placeAbove) {
      top = target.top - gap - cardHeight;
      if (top < margin) {
        top = margin;
        placeAbove = false; // fallback to below if not enough space
      }
    } else {
      top = target.bottom + gap;
      if (top + cardHeight > overlaySize.height - margin) {
        top = overlaySize.height - margin - cardHeight;
      }
    }

    return _CardPlacement(left: left, top: top, placeAbove: placeAbove);
  }

  double _arrowLeft(Rect cardRect, Rect target) {
    final double targetCenter = target.center.dx;
    final double minX = cardRect.left + 14;
    final double maxX = cardRect.right - 14;
    final double center = targetCenter.clamp(minX, maxX);
    return center - (_kArrowWidth / 2);
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({
    super.key,
    required this.title,
    required this.description,
    required this.stepLabel,
    required this.isLast,
    required this.onSkip,
    required this.onNext,
  });

  final String title;
  final String description;
  final String stepLabel;
  final bool isLast;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFF111216);

    return Container(
      decoration: BoxDecoration(
        color: cardBg.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            stepLabel.toUpperCase(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              height: 1.35,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                child: const Text('Skip'),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: KemeticGold.base,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                child: Text(isLast ? 'Done' : 'Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({required this.targetRect});

  final Rect? targetRect;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..fillType = PathFillType.evenOdd;
    path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (targetRect != null) {
      final padded = targetRect!.inflate(10);
      path.addRRect(RRect.fromRectAndRadius(padded, const Radius.circular(12)));

      final glowPaint = Paint()
        ..color = Colors.white.withOpacity(0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
      canvas.drawRRect(
        RRect.fromRectAndRadius(padded, const Radius.circular(12)),
        glowPaint,
      );
    }

    canvas.drawPath(path, Paint()..color = Colors.black.withOpacity(0.68));
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({
    required this.pointingDown,
    required this.color,
    required this.borderColor,
  });

  final bool pointingDown;
  final Color color;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointingDown) {
      path.moveTo(0, 0);
      path.lineTo(size.width / 2, size.height);
      path.lineTo(size.width, 0);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
    }
    path.close();

    final paint = Paint()..color = color;
    canvas.drawPath(path, paint);

    final stroke = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) {
    return oldDelegate.pointingDown != pointingDown ||
        oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor;
  }
}

class _CardPlacement {
  const _CardPlacement({
    required this.left,
    required this.top,
    required this.placeAbove,
  });

  final double left;
  final double top;
  final bool placeAbove;
}

const double _kScreenMargin = 12.0;
const double _kArrowHeight = 10.0;
const double _kArrowWidth = 18.0;
const Color _cardBg = Color(0xFF111216);
