import 'package:flutter/foundation.dart';

enum CalendarRefreshStatus { idle, pending, succeeded, failed }

/// Internal refresh telemetry. This does not own calendar presentation.
///
/// A failed network attempt must never invalidate an already-presented
/// snapshot or turn refresh state into visible calendar availability.
@immutable
class CalendarRefreshState {
  const CalendarRefreshState({
    this.visibleViewportComplete = true,
    this.lastSuccessfulRefreshAtUtc,
    this.latestRefreshStatus = CalendarRefreshStatus.succeeded,
    this.hasUsableSnapshot = true,
  });

  static const initial = CalendarRefreshState();

  final bool visibleViewportComplete;
  final DateTime? lastSuccessfulRefreshAtUtc;
  final CalendarRefreshStatus latestRefreshStatus;
  final bool hasUsableSnapshot;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarRefreshState &&
          other.visibleViewportComplete == visibleViewportComplete &&
          other.lastSuccessfulRefreshAtUtc == lastSuccessfulRefreshAtUtc &&
          other.latestRefreshStatus == latestRefreshStatus &&
          other.hasUsableSnapshot == hasUsableSnapshot;

  @override
  int get hashCode => Object.hash(
    visibleViewportComplete,
    lastSuccessfulRefreshAtUtc,
    latestRefreshStatus,
    hasUsableSnapshot,
  );
}
