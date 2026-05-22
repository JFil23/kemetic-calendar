import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/maat_guidance_model.dart';
import '../../data/maat_guidance_repo.dart';

class MaatGuidanceScope extends InheritedNotifier<MaatGuidanceController> {
  const MaatGuidanceScope({
    super.key,
    required this.controller,
    required super.child,
  }) : super(notifier: controller);

  final MaatGuidanceController controller;

  static MaatGuidanceController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<MaatGuidanceScope>()
        ?.controller;
  }
}

class MaatGuidanceController extends ChangeNotifier {
  MaatGuidanceController(this._repo);

  static const String _lastShownIdKey = 'maat_guidance.lastShownDeliveryId';
  static const String _lastShownPeriodKey = 'maat_guidance.lastShownPeriodKey';
  static const Duration _fetchThrottle = Duration(minutes: 15);

  final MaatGuidanceDataSource _repo;
  MaatGuidanceDelivery? _current;
  MaatGuidanceEvaluateResult? _lastEvaluateResult;
  Future<void>? _inFlight;
  DateTime? _lastFetchAt;
  bool _suppressed = true;

  MaatGuidanceDelivery? get current => _current;
  MaatGuidanceEvaluateResult? get lastEvaluateResult => _lastEvaluateResult;
  bool get hasVisibleDelivery => _current != null && !_suppressed;

  void updateSuppression(bool suppressed) {
    if (_suppressed == suppressed) return;
    _suppressed = suppressed;
    notifyListeners();
    if (!suppressed) {
      final currentDelivery = _current;
      if (currentDelivery != null) {
        unawaited(_markShown(currentDelivery));
      } else {
        unawaited(refresh(force: true));
      }
    }
  }

  Future<void> refresh({bool force = false}) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final now = DateTime.now();
    if (!force &&
        _lastFetchAt != null &&
        now.difference(_lastFetchAt!) < _fetchThrottle) {
      return Future<void>.value();
    }

    late final Future<void> future;
    future = _runRefresh(force: force).whenComplete(() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    });
    _inFlight = future;
    return future;
  }

  Future<void> evaluateAndRefresh({String? timezone}) async {
    _lastEvaluateResult = await _repo.evaluate(timezone: timezone);
    await refresh(force: true);
  }

  Future<void> _runRefresh({required bool force}) async {
    if (_suppressed && !force) return;
    _lastFetchAt = DateTime.now();
    final pending = await _repo.fetchPending();
    if (pending == null || pending.id.isEmpty) return;

    if (_current?.id == pending.id) {
      _current = pending;
      notifyListeners();
      if (!_suppressed) {
        await _markShown(pending);
      }
      return;
    }

    _current = pending;
    notifyListeners();
    if (!_suppressed) {
      await _markShown(pending);
    }
  }

  Future<void> _markShown(MaatGuidanceDelivery delivery) async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyMarked =
        prefs.getString(_lastShownIdKey) == delivery.id &&
        prefs.getString(_lastShownPeriodKey) == delivery.decanPeriodKey &&
        delivery.status == MaatGuidanceStatus.shown;
    if (alreadyMarked) return;

    await prefs.setString(_lastShownIdKey, delivery.id);
    await prefs.setString(_lastShownPeriodKey, delivery.decanPeriodKey);
    await _repo.ack(deliveryId: delivery.id, action: 'shown');
  }

  Future<void> dismissCurrent() async {
    final delivery = _current;
    if (delivery == null) return;
    _current = null;
    notifyListeners();
    await _repo.ack(deliveryId: delivery.id, action: 'dismissed');
    await refresh(force: true);
  }

  Future<void> markOpened(MaatGuidanceDelivery delivery) async {
    await _repo.ack(deliveryId: delivery.id, action: 'opened');
    await refresh(force: true);
  }

  Future<void> markActed(
    MaatGuidanceDelivery delivery, {
    Map<String, dynamic>? metadata,
  }) async {
    await _repo.ack(
      deliveryId: delivery.id,
      action: 'acted',
      metadata: metadata,
    );
    if (_current?.id == delivery.id) {
      _current = null;
      notifyListeners();
    }
    await refresh(force: true);
  }

  void clearForSignedOut() {
    unawaited(_clearShownPrefs());
    if (_current == null) return;
    _current = null;
    notifyListeners();
  }

  Future<void> _clearShownPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastShownIdKey);
    await prefs.remove(_lastShownPeriodKey);
  }
}
