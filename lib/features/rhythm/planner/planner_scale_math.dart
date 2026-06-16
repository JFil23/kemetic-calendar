import 'dart:math' as math;

/// Converts planner completion percent into the Ma'at scale beam angle.
///
/// The beam starts fully tilted, remains visibly tilted through most progress,
/// and reaches level at 100%. Values above 100% are clamped and never cross
/// equilibrium.
double plannerScaleTiltDegrees(num percent, {double emptyTiltDegrees = 11}) {
  final warmth = (percent / 100.0).clamp(0.0, 1.0).toDouble();
  return emptyTiltDegrees * (1 - math.pow(warmth, 4));
}
