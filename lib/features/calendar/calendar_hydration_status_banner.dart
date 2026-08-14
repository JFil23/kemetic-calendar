import 'package:flutter/material.dart';

enum CalendarHydrationAvailability { current, stale, unavailable }

enum CalendarRefreshStatus { idle, pending, succeeded, failed }

@immutable
class CalendarHydrationStatus {
  const CalendarHydrationStatus({
    this.visibleViewportComplete = true,
    this.lastSuccessfulRefreshAtUtc,
    this.latestRefreshStatus = CalendarRefreshStatus.succeeded,
    this.hasUsableSnapshot = true,
    required this.accountingStale,
    CalendarHydrationAvailability? calendarAvailability,
  }) : _calendarAvailabilityOverride = calendarAvailability;

  static const current = CalendarHydrationStatus(accountingStale: false);

  /// Completeness is about the active viewport, not whether any event rows
  /// happened to survive a cache compaction.
  final bool visibleViewportComplete;

  /// Freshness is durable snapshot metadata and remains meaningful when the
  /// latest network attempt fails.
  final DateTime? lastSuccessfulRefreshAtUtc;

  /// Refresh outcome is independent from both completeness and freshness.
  final CalendarRefreshStatus latestRefreshStatus;

  final bool hasUsableSnapshot;
  final bool accountingStale;
  final CalendarHydrationAvailability? _calendarAvailabilityOverride;

  CalendarHydrationAvailability get calendarAvailability {
    final override = _calendarAvailabilityOverride;
    if (override != null) return override;
    if (!hasUsableSnapshot) {
      return latestRefreshStatus == CalendarRefreshStatus.failed
          ? CalendarHydrationAvailability.unavailable
          : CalendarHydrationAvailability.current;
    }
    if (!visibleViewportComplete ||
        latestRefreshStatus == CalendarRefreshStatus.failed) {
      return CalendarHydrationAvailability.stale;
    }
    return CalendarHydrationAvailability.current;
  }

  bool get hasWarning =>
      calendarAvailability != CalendarHydrationAvailability.current ||
      accountingStale;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarHydrationStatus &&
          other.calendarAvailability == calendarAvailability &&
          other.visibleViewportComplete == visibleViewportComplete &&
          other.lastSuccessfulRefreshAtUtc == lastSuccessfulRefreshAtUtc &&
          other.latestRefreshStatus == latestRefreshStatus &&
          other.hasUsableSnapshot == hasUsableSnapshot &&
          other.accountingStale == accountingStale;

  @override
  int get hashCode => Object.hash(
    calendarAvailability,
    visibleViewportComplete,
    lastSuccessfulRefreshAtUtc,
    latestRefreshStatus,
    hasUsableSnapshot,
    accountingStale,
  );
}

CalendarHydrationAvailability calendarAvailabilityAfterFailure({
  required bool hasFallbackSnapshot,
}) => hasFallbackSnapshot
    ? CalendarHydrationAvailability.stale
    : CalendarHydrationAvailability.unavailable;

class CalendarHydrationStatusBanner extends StatelessWidget {
  const CalendarHydrationStatusBanner({
    super.key,
    required this.calendarAvailability,
    required this.accountingStale,
  });

  final CalendarHydrationAvailability calendarAvailability;
  final bool accountingStale;

  @override
  Widget build(BuildContext context) {
    if (calendarAvailability == CalendarHydrationAvailability.current &&
        !accountingStale) {
      return const SizedBox.shrink();
    }

    final calendarMessage = switch (calendarAvailability) {
      CalendarHydrationAvailability.current => null,
      CalendarHydrationAvailability.stale =>
        'Calendar may be out of date. It will retry when you return.',
      CalendarHydrationAvailability.unavailable =>
        'Calendar is temporarily unavailable. It will retry when you return.',
    };

    return Semantics(
      container: true,
      liveRegion: true,
      child: IgnorePointer(
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (calendarMessage != null)
                    _HydrationStatusLine(
                      key: const ValueKey('calendar-hydration-status'),
                      message: calendarMessage,
                      icon:
                          calendarAvailability ==
                              CalendarHydrationAvailability.unavailable
                          ? Icons.cloud_off_outlined
                          : Icons.schedule_outlined,
                      accent:
                          calendarAvailability ==
                              CalendarHydrationAvailability.unavailable
                          ? const Color(0xFFE77768)
                          : const Color(0xFFE0B95A),
                    ),
                  if (calendarMessage != null && accountingStale)
                    const SizedBox(height: 6),
                  if (accountingStale)
                    const _HydrationStatusLine(
                      key: ValueKey('calendar-accounting-status'),
                      message: 'Flow totals may be out of date.',
                      icon: Icons.functions_outlined,
                      accent: Color(0xFF6DC8C8),
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

class _HydrationStatusLine extends StatelessWidget {
  const _HydrationStatusLine({
    super.key,
    required this.message,
    required this.icon,
    required this.accent,
  });

  final String message;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xF20A0A0A),
        border: Border.all(color: accent.withValues(alpha: 0.72)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 10)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: accent),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFFE7E2D8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
