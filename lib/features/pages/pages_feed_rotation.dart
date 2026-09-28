import 'dart:async';
import 'package:flutter/foundation.dart';

enum PagesFeedDisplay { question, publicRhythm }

/// Local presentation only: no repository, cache invalidation or persistence.
/// Even local hours show the question; odd hours show public rhythm.
class PagesFeedRotation extends ChangeNotifier {
  PagesFeedRotation({DateTime Function()? now}) : _now = now ?? DateTime.now {
    display = displayAt(_now());
  }
  final DateTime Function() _now;
  late PagesFeedDisplay display;
  Timer? _timer;
  bool _active = false;

  static PagesFeedDisplay displayAt(DateTime now) => now.hour.isEven
      ? PagesFeedDisplay.question
      : PagesFeedDisplay.publicRhythm;

  void setActive(bool active) {
    _timer?.cancel();
    _active = active;
    if (!active) return;
    _refresh();
    _schedule();
  }

  void _refresh() {
    final next = displayAt(_now());
    if (display == next) return;
    display = next;
    notifyListeners();
  }

  void _schedule() {
    if (!_active) return;
    final now = _now();
    final elapsed = Duration(
      minutes: now.minute,
      seconds: now.second,
      milliseconds: now.millisecond,
      microseconds: now.microsecond,
    );
    _timer = Timer(
      const Duration(hours: 1) - elapsed + const Duration(milliseconds: 20),
      () {
        if (!_active) return;
        _refresh();
        _schedule();
      },
    );
  }

  @override
  void dispose() {
    _active = false;
    _timer?.cancel();
    super.dispose();
  }
}
