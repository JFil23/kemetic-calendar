import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'maat_flow_temporal_policy.dart';
import 'maat_flow_temporal_resolver.dart';

typedef MaatFlowIanaTimeZoneProvider = Future<String> Function();
typedef MaatFlowTemporalResolutionBuilder =
    MaatFlowTemporalResolution? Function(MaatFlowTemporalContext context);

abstract interface class MaatFlowTemporalTimerHandle {
  void cancel();
}

typedef MaatFlowTemporalScheduler =
    MaatFlowTemporalTimerHandle Function(Duration delay, VoidCallback callback);

enum MaatFlowTemporalLock { none, explicitDate, carried }

class _TimerHandle implements MaatFlowTemporalTimerHandle {
  _TimerHandle(Duration delay, VoidCallback callback)
    : _timer = Timer(delay, callback);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

MaatFlowTemporalTimerHandle scheduleMaatFlowTemporalCallback(
  Duration delay,
  VoidCallback callback,
) => _TimerHandle(delay, callback);

/// Process-wide app/device timezone authority for Ma'at present-day tracking.
///
/// Production initializes this before [runApp]. Tests and embedded surfaces can
/// provide an explicit IANA zone to [MaatFlowTemporalController].
abstract final class MaatFlowDeviceTimeZone {
  static String? _currentIanaTimeZone;

  static String get currentIanaTimeZone => _currentIanaTimeZone ?? 'UTC';

  static Future<String> initialize({
    MaatFlowIanaTimeZoneProvider? provider,
  }) async {
    tzdata.initializeTimeZones();
    return refresh(provider: provider);
  }

  static Future<String> refresh({
    MaatFlowIanaTimeZoneProvider? provider,
  }) async {
    final current = _currentIanaTimeZone;
    try {
      final candidate = provider == null
          ? (await FlutterTimezone.getLocalTimezone()).identifier
          : await provider();
      final validated = _validatedIanaTimeZone(candidate);
      _currentIanaTimeZone = validated;
      tz.setLocalLocation(tz.getLocation(validated));
      return validated;
    } catch (_) {
      if (current != null) return current;
      const fallback = 'UTC';
      _currentIanaTimeZone = fallback;
      tz.setLocalLocation(tz.getLocation(fallback));
      return fallback;
    }
  }

  @visibleForTesting
  static void setForTesting(String ianaTimeZone) {
    tzdata.initializeTimeZones();
    final validated = _validatedIanaTimeZone(ianaTimeZone);
    _currentIanaTimeZone = validated;
    tz.setLocalLocation(tz.getLocation(validated));
  }
}

String _validatedIanaTimeZone(String value) {
  tzdata.initializeTimeZones();
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'UTC';
  try {
    return tz.getLocation(trimmed).name;
  } catch (_) {
    return 'UTC';
  }
}

/// Shared live temporal baseline for every Ma'at Flow preview.
///
/// The controller owns device-zone refresh, the local-midnight timer, resume
/// handling, and both lock states. Consumers render [renderedStartDate] and
/// use [resolutionForCarry] / [startDateForCarry] without resolving again in
/// the tap handler, so Carry can never silently differ from the preview.
class MaatFlowTemporalController extends ChangeNotifier
    with WidgetsBindingObserver {
  MaatFlowTemporalController({
    required String ianaTimeZone,
    required MaatFlowTemporalResolutionBuilder resolve,
    MaatFlowClock clock = maatFlowSystemClock,
    MaatFlowIanaTimeZoneProvider? ianaTimeZoneProvider,
    MaatFlowTemporalScheduler scheduler = scheduleMaatFlowTemporalCallback,
    DateTime? explicitStartDate,
    bool carried = false,
  }) : _clock = clock,
       _ianaTimeZoneProvider = ianaTimeZoneProvider,
       _scheduler = scheduler,
       _resolve = resolve,
       _ianaTimeZone = _validatedIanaTimeZone(ianaTimeZone) {
    _context = _captureContext();
    _resolution = _resolve(_context);
    if (carried) {
      _lock = MaatFlowTemporalLock.carried;
      _lockedStartDate = _dateOnly(explicitStartDate ?? _resolution?.startDate);
    } else if (explicitStartDate != null) {
      _lock = MaatFlowTemporalLock.explicitDate;
      _lockedStartDate = _dateOnly(explicitStartDate);
    }
  }

  final MaatFlowClock _clock;
  final MaatFlowIanaTimeZoneProvider? _ianaTimeZoneProvider;
  final MaatFlowTemporalScheduler _scheduler;
  MaatFlowTemporalResolutionBuilder _resolve;
  late MaatFlowTemporalContext _context;
  MaatFlowTemporalResolution? _resolution;
  late String _ianaTimeZone;
  MaatFlowTemporalLock _lock = MaatFlowTemporalLock.none;
  DateTime? _lockedStartDate;
  MaatFlowTemporalTimerHandle? _midnightTimer;
  bool _started = false;
  bool _disposed = false;

  MaatFlowTemporalContext get context => _context;
  MaatFlowTemporalResolution? get resolution => _resolution;
  MaatFlowTemporalLock get lock => _lock;
  bool get isExplicitlyLocked => _lock == MaatFlowTemporalLock.explicitDate;
  bool get isCarried => _lock == MaatFlowTemporalLock.carried;
  bool get isLocked => _lock != MaatFlowTemporalLock.none;
  String get ianaTimeZone => _ianaTimeZone;

  DateTime get renderedStartDate {
    final date = _lockedStartDate ?? _resolution?.startDate;
    if (date == null) {
      throw StateError('This temporal controller has no resolved start date.');
    }
    return _dateOnly(date)!;
  }

  MaatFlowTemporalResolution? get resolutionForCarry => _resolution;
  DateTime get startDateForCarry => renderedStartDate;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _scheduleNextMidnight();
  }

  void replaceResolver(
    MaatFlowTemporalResolutionBuilder resolve, {
    bool refresh = true,
  }) {
    _resolve = resolve;
    if (refresh) refreshPresentDay(force: true);
  }

  void setIanaTimeZone(String ianaTimeZone) {
    final validated = _validatedIanaTimeZone(ianaTimeZone);
    if (validated == _ianaTimeZone) return;
    _ianaTimeZone = validated;
    refreshPresentDay(force: true);
  }

  void lockExplicitDate(DateTime date) {
    _lock = MaatFlowTemporalLock.explicitDate;
    _lockedStartDate = _dateOnly(date);
    _scheduleNextMidnight();
    notifyListeners();
  }

  void lockCarried({
    DateTime? persistedStartDate,
    MaatFlowTemporalResolution? persistedResolution,
    bool notify = true,
  }) {
    if (persistedResolution != null) _resolution = persistedResolution;
    _lockedStartDate = _dateOnly(
      persistedStartDate ?? _lockedStartDate ?? _resolution?.startDate,
    );
    _lock = MaatFlowTemporalLock.carried;
    _scheduleNextMidnight();
    if (notify) notifyListeners();
  }

  void unlock({bool refresh = true}) {
    _lock = MaatFlowTemporalLock.none;
    _lockedStartDate = null;
    if (refresh) {
      refreshPresentDay(force: true);
    } else {
      notifyListeners();
    }
  }

  void refreshPresentDay({bool force = false}) {
    if (_disposed) return;
    final nextContext = _captureContext();
    final dayChanged = !_context.hasSamePresentDay(nextContext);
    _context = nextContext;
    if (_resolution == null || (!isLocked && (force || dayChanged))) {
      _resolution = _resolve(nextContext);
    }
    _scheduleNextMidnight();
    if (force || dayChanged) notifyListeners();
  }

  Future<void> refreshAfterResume() async {
    if (_disposed) return;
    final provider = _ianaTimeZoneProvider;
    if (provider != null) {
      try {
        _ianaTimeZone = _validatedIanaTimeZone(await provider());
      } catch (_) {
        // Keep the last verified IANA zone when the platform is unavailable.
      }
    }
    refreshPresentDay(force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refreshAfterResume());
  }

  void _scheduleNextMidnight() {
    _midnightTimer?.cancel();
    _midnightTimer = null;
    if (!_started || _disposed) return;
    final nowUtc = _clock().toUtc();
    var delay = _context.nextLocalMidnightUtc.difference(nowUtc);
    if (delay.isNegative) delay = Duration.zero;
    _midnightTimer = _scheduler(
      delay + const Duration(milliseconds: 50),
      () => refreshPresentDay(force: true),
    );
  }

  MaatFlowTemporalContext _captureContext() => MaatFlowTemporalContext.capture(
    ianaTimeZone: _ianaTimeZone,
    clock: _clock,
  );

  static DateTime? _dateOnly(DateTime? value) =>
      value == null ? null : DateTime(value.year, value.month, value.day);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _midnightTimer?.cancel();
    if (_started) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
