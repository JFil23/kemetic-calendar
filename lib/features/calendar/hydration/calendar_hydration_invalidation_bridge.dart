import 'dart:async';

import '../calendar_invalidation.dart';

typedef CalendarHydrationInvalidationHandler =
    Future<bool> Function(CalendarInvalidated invalidation);

/// Debounced bridge from the global invalidation bus into typed hydration
/// intents. Scheduling and database serialization remain owned by
/// CalendarHydrationScheduler.
class CalendarHydrationInvalidationBridge {
  CalendarHydrationInvalidationBridge({
    required CalendarHydrationInvalidationHandler onInvalidation,
    required bool Function() isMounted,
    bool Function()? isDeferred,
    Duration debounce = const Duration(milliseconds: 80),
    CalendarInvalidationBus? bus,
  }) : _onInvalidation = onInvalidation,
       _isMounted = isMounted,
       _isDeferred = isDeferred ?? _never,
       _debounce = debounce,
       _bus = bus ?? CalendarInvalidationBus.instance;

  final CalendarHydrationInvalidationHandler _onInvalidation;
  final bool Function() _isMounted;
  final bool Function() _isDeferred;
  final Duration _debounce;
  final CalendarInvalidationBus _bus;

  StreamSubscription<CalendarInvalidated>? _subscription;
  Timer? _timer;
  int _scheduledRevision = 0;
  CalendarInvalidated? _pending;

  static bool _never() => false;

  void attach() {
    _subscription ??= _bus.stream.listen((_) => _drain());
    _drain();
  }

  void _drain() {
    if (!_isMounted()) return;
    final next = _bus.peekPendingAfter(_scheduledRevision);
    if (next == null) return;
    _scheduledRevision = next.revision;
    _pending = next.invalidation;
    _timer?.cancel();
    _timer = Timer(_debounce, _flush);
  }

  void _flush() {
    _timer?.cancel();
    _timer = null;
    if (!_isMounted() || _pending == null) return;
    if (_isDeferred()) {
      _timer = Timer(_debounce, _flush);
      return;
    }
    final invalidation = _pending!;
    final revision = _scheduledRevision;
    _pending = null;
    unawaited(
      _onInvalidation(invalidation).then((succeeded) {
        if (succeeded) _bus.markConsumed(revision);
        _drain();
      }),
    );
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }
}
