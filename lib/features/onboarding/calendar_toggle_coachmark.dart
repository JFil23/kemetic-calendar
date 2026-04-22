import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile/shared/glossy_text.dart';

class CalendarToggleCoachmark extends StatefulWidget {
  const CalendarToggleCoachmark({
    super.key,
    required this.targetKey,
    required this.onTargetTap,
  });

  final GlobalKey targetKey;
  final VoidCallback onTargetTap;

  @override
  State<CalendarToggleCoachmark> createState() =>
      _CalendarToggleCoachmarkState();
}

class _CalendarToggleCoachmarkState extends State<CalendarToggleCoachmark>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();
  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  )..forward();

  Rect? _targetRect;
  bool _targetMeasurementQueued = false;

  @override
  void initState() {
    super.initState();
    _queueTargetMeasurement();
  }

  @override
  void didUpdateWidget(covariant CalendarToggleCoachmark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetKey != widget.targetKey) {
      _queueTargetMeasurement();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _queueTargetMeasurement() {
    if (_targetMeasurementQueued) return;
    _targetMeasurementQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _targetMeasurementQueued = false;
      if (!mounted) return;

      final measured = _measureTargetRect();
      if (measured == null) {
        _queueTargetMeasurement();
        return;
      }

      if (_targetRect != measured) {
        setState(() => _targetRect = measured);
      }
    });
  }

  Rect? _measureTargetRect() {
    final targetContext = widget.targetKey.currentContext;
    final overlayBox = context.findRenderObject() as RenderBox?;
    final targetBox = targetContext?.findRenderObject() as RenderBox?;
    if (targetContext == null ||
        overlayBox == null ||
        targetBox == null ||
        !overlayBox.attached ||
        !targetBox.attached) {
      return null;
    }

    final topLeft = targetBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    return (topLeft & targetBox.size).inflate(16);
  }

  @override
  Widget build(BuildContext context) {
    _queueTargetMeasurement();
    final media = MediaQuery.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _entranceController]),
      builder: (context, _) {
        final rect = _targetRect;
        final wave = (math.sin(_pulseController.value * math.pi * 2) + 1) / 2;
        final entrance = Curves.easeOutCubic.transform(
          _entranceController.value,
        );
        final panelLift = 18 * (1 - entrance);
        final panelScale = 0.96 + (0.04 * entrance);
        final highlightScale = 0.9 + (0.1 * entrance);
        final bubbleTop = rect == null
            ? media.padding.top + kToolbarHeight + 20
            : math.max(
                rect.bottom + 18,
                media.padding.top + kToolbarHeight + 10,
              );

        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: rect == null
                            ? const Alignment(-0.86, -0.92)
                            : Alignment(
                                ((rect.center.dx / media.size.width) * 2) - 1,
                                ((rect.center.dy / media.size.height) * 2) - 1,
                              ),
                        radius: 1.15,
                        colors: [
                          Colors.black.withValues(alpha: 0.10 * entrance),
                          Colors.black.withValues(alpha: 0.72 * entrance),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (rect != null) ...[
                Positioned.fromRect(
                  rect: rect.inflate(14),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: widget.onTargetTap,
                  ),
                ),
                Positioned.fromRect(
                  rect: rect.inflate(6 + (wave * 8)),
                  child: IgnorePointer(
                    child: Transform.scale(
                      scale: highlightScale,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: KemeticGold.light.withValues(
                              alpha: (0.24 + (wave * 0.26)) * entrance,
                            ),
                            width: 2.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fromRect(
                  rect: rect,
                  child: IgnorePointer(
                    child: Transform.scale(
                      scale: highlightScale,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: KemeticGold.light.withValues(
                              alpha: 0.92 * entrance,
                            ),
                            width: 2.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: KemeticGold.base.withValues(
                                alpha: (0.14 + (wave * 0.18)) * entrance,
                              ),
                              blurRadius: 18 + (wave * 14),
                              spreadRadius: 1 + (wave * 6),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              Positioned(
                left: 16,
                right: 16,
                top: bubbleTop,
                child: SafeArea(
                  bottom: false,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Opacity(
                      opacity: entrance,
                      child: Transform.translate(
                        offset: Offset(0, panelLift),
                        child: Transform.scale(
                          scale: panelScale,
                          alignment: Alignment.topLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: math.min(340, media.size.width - 32),
                            ),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xFF090909),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: KemeticGold.base.withValues(
                                    alpha: 0.30,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.34),
                                    blurRadius: 28,
                                    offset: const Offset(0, 14),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  18,
                                  18,
                                  14,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Switch calendar views',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap ḥꜣw to toggle between the Kemetic calendar and the Gregorian calendar at any time.',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.78,
                                        ),
                                        height: 1.4,
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
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
