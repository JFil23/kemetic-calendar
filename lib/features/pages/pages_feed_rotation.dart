import 'dart:async';
import 'package:flutter/foundation.dart';

enum PagesFeedDisplay { question, practice, publicRhythm }

enum PagesFeedEdition { dawn, midday, dusk }

/// Local presentation only. A boundary never fetches, invalidates or persists.
class PagesFeedRotation extends ChangeNotifier {
  PagesFeedRotation({DateTime Function()? now}) : _now = now ?? DateTime.now {
    edition = editionAt(this.now);
  }
  final DateTime Function() _now;
  DateTime get now => _now().toLocal();
  late PagesFeedEdition edition;
  Timer? _timer;
  bool _active = false;

  static PagesFeedEdition editionAt(DateTime time) {
    final local = time.toLocal();
    final minute = local.hour * 60 + local.minute;
    if (minute < 300 || minute >= 1050) return PagesFeedEdition.dusk;
    return minute < 690 ? PagesFeedEdition.dawn : PagesFeedEdition.midday;
  }

  static DateTime nextBoundary(DateTime time) {
    final local = time.toLocal();
    for (final minute in [300, 690, 1050]) {
      final at = DateTime(
        local.year,
        local.month,
        local.day,
        minute ~/ 60,
        minute % 60,
      );
      if (at.isAfter(local)) return at;
    }
    return DateTime(local.year, local.month, local.day + 1, 5);
  }

  void setActive(bool active) {
    _timer?.cancel();
    _active = active;
    if (!active) return;
    _refresh();
    _schedule();
  }

  void _refresh() {
    final next = editionAt(now);
    if (edition == next) return;
    edition = next;
    notifyListeners();
  }

  void _schedule() {
    if (!_active) return;
    final current = now;
    _timer = Timer(
      nextBoundary(current).difference(current) +
          const Duration(milliseconds: 20),
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
