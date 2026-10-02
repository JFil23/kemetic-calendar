import 'dart:async';

enum CalendarInvalidationReason {
  flowStudioPersisted,
  flowDeleted,
  flowJoined,
  flowEndedCommitted,
  eventSaved,
  calendarImportSynced,
}

/// A confirmed external read window; carries no event data or write authority.
class ExternalCalendarRange {
  const ExternalCalendarRange(this.from, this.until);
  final DateTime from, until;
  @override
  bool operator ==(Object other) =>
      other is ExternalCalendarRange &&
      from == other.from &&
      until == other.until;
  @override
  int get hashCode => Object.hash(from, until);
}

class ExternalCalendarInvalidation {
  const ExternalCalendarInvalidation({
    required this.accountId,
    required this.lane,
    this.ranges = const [],
    this.removedSourceIds = const {},
  });
  final String accountId, lane;
  final List<ExternalCalendarRange> ranges;
  final Set<String> removedSourceIds;

  ExternalCalendarInvalidation merge(ExternalCalendarInvalidation next) {
    if (accountId != next.accountId || lane != next.lane) return next;
    return ExternalCalendarInvalidation(
      accountId: accountId,
      lane: lane,
      ranges: List.unmodifiable({...ranges, ...next.ranges}),
      removedSourceIds: Set.unmodifiable({
        ...removedSourceIds,
        ...next.removedSourceIds,
      }),
    );
  }
}

class CalendarInvalidated {
  const CalendarInvalidated({
    required this.reason,
    this.flowId,
    this.clientEventIds = const <String>[],
    this.externalCalendar,
  });

  final CalendarInvalidationReason reason;
  final int? flowId;
  final List<String> clientEventIds;
  final ExternalCalendarInvalidation? externalCalendar;

  CalendarInvalidated merge(CalendarInvalidated next) {
    return CalendarInvalidated(
      reason: next.reason,
      externalCalendar: next.externalCalendar == null
          ? externalCalendar
          : externalCalendar?.merge(next.externalCalendar!) ??
                next.externalCalendar,
      flowId: next.flowId ?? flowId,
      clientEventIds: List.unmodifiable(<String>{
        ...clientEventIds,
        ...next.clientEventIds,
      }),
    );
  }
}

class PendingCalendarInvalidation {
  const PendingCalendarInvalidation({
    required this.revision,
    required this.invalidation,
  });

  final int revision;
  final CalendarInvalidated invalidation;
}

class CalendarInvalidationBus {
  CalendarInvalidationBus();

  static final CalendarInvalidationBus instance = CalendarInvalidationBus();

  final StreamController<CalendarInvalidated> _controller =
      StreamController<CalendarInvalidated>.broadcast();
  int _revision = 0;
  int _consumedRevision = 0;
  CalendarInvalidated? _pending;

  Stream<CalendarInvalidated> get stream => _controller.stream;

  PendingCalendarInvalidation? peekPendingAfter(int revision) {
    if (_revision <= _consumedRevision || _revision <= revision) return null;
    final pending = _pending;
    if (pending == null) return null;
    return PendingCalendarInvalidation(
      revision: _revision,
      invalidation: pending,
    );
  }

  void markConsumed(int revision) {
    if (revision <= _consumedRevision) return;
    _consumedRevision = revision;
    if (_consumedRevision >= _revision) {
      _pending = null;
    }
  }

  void publish(CalendarInvalidated invalidation) {
    if (_controller.isClosed) return;
    _revision += 1;
    _pending = _pending?.merge(invalidation) ?? invalidation;
    _controller.add(invalidation);
  }
}
