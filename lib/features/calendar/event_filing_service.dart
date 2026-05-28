import 'notify.dart';

const int kEventFilingNoAlertMinutes = -1;

typedef ScheduleEventNotification =
    Future<void> Function({
      required String clientEventId,
      required DateTime scheduledAt,
      required String title,
      String? body,
      String? payload,
      NotificationType type,
    });

typedef CancelEventNotification = Future<void> Function(String clientEventId);

enum EventFilingOutcome { scheduled, cancelled, skipped }

class EventFilingResult {
  const EventFilingResult._(this.outcome, {this.scheduledAt});

  const EventFilingResult.scheduled(DateTime scheduledAt)
    : this._(EventFilingOutcome.scheduled, scheduledAt: scheduledAt);

  const EventFilingResult.cancelled() : this._(EventFilingOutcome.cancelled);

  const EventFilingResult.skipped() : this._(EventFilingOutcome.skipped);

  final EventFilingOutcome outcome;
  final DateTime? scheduledAt;
}

class EventFilingService {
  EventFilingService({
    ScheduleEventNotification? scheduleNotification,
    CancelEventNotification? cancelNotification,
  }) : _scheduleNotification =
           scheduleNotification ?? Notify.scheduleAlertWithPersistence,
       _cancelNotification =
           cancelNotification ??
           ((clientEventId) =>
               Notify.cancelNotificationsForClientEventIds([clientEventId]));

  final ScheduleEventNotification _scheduleNotification;
  final CancelEventNotification _cancelNotification;

  /// Alert semantics:
  /// - positive value: alert N minutes before event
  /// - 0: alert at event time
  /// - null: legacy at-time alert behavior
  /// - -1: explicit no-alert / cancel delivery
  Future<EventFilingResult> fileDelivery({
    required String clientEventId,
    required DateTime startsAtLocal,
    required int? alertOffsetMinutes,
    required String title,
    String? body,
    String payload = '{}',
    NotificationType type = NotificationType.eventStart,
  }) async {
    final normalizedClientEventId = clientEventId.trim();
    if (normalizedClientEventId.isEmpty) {
      return const EventFilingResult.skipped();
    }

    if (alertOffsetMinutes == kEventFilingNoAlertMinutes) {
      await _cancelNotification(normalizedClientEventId);
      return const EventFilingResult.cancelled();
    }

    final effectiveMinutes = alertOffsetMinutes ?? 0;
    final scheduledAt = startsAtLocal.subtract(
      Duration(minutes: effectiveMinutes),
    );
    await _scheduleNotification(
      clientEventId: normalizedClientEventId,
      scheduledAt: scheduledAt,
      title: title,
      body: body,
      payload: payload,
      type: type,
    );
    return EventFilingResult.scheduled(scheduledAt);
  }
}
