import 'dart:async';

enum CalendarInvalidationReason {
  flowStudioPersisted,
  flowDeleted,
  flowJoined,
  eventSaved,
}

class CalendarInvalidated {
  const CalendarInvalidated({
    required this.reason,
    this.flowId,
    this.clientEventIds = const <String>[],
  });

  final CalendarInvalidationReason reason;
  final int? flowId;
  final List<String> clientEventIds;

  CalendarInvalidated merge(CalendarInvalidated next) {
    return CalendarInvalidated(
      reason: next.reason,
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
