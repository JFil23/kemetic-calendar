import 'package:flutter/widgets.dart';

/// Coordinates public presentation with visitor entry and activity timing.
/// Authentication and account writes remain with AccountAccess.
class VisitorPresentationScope extends InheritedWidget {
  const VisitorPresentationScope({
    super.key,
    required this.readyForPublicOverlays,
    required this.onDailyRhythmVisibilityChanged,
    required super.child,
  });

  final bool readyForPublicOverlays;
  final ValueChanged<bool> onDailyRhythmVisibilityChanged;

  static VisitorPresentationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VisitorPresentationScope>();

  @override
  bool updateShouldNotify(VisitorPresentationScope oldWidget) =>
      readyForPublicOverlays != oldWidget.readyForPublicOverlays ||
      onDailyRhythmVisibilityChanged !=
          oldWidget.onDailyRhythmVisibilityChanged;
}
