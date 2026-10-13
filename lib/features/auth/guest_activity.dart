/// Accumulates actual interaction bursts. A gesture grants at most one second
/// until another input arrives; one tap followed by waiting cannot earn five.
/// Pausing discards the current burst but preserves already earned activity.
class GuestActivity {
  GuestActivity({required this.now});
  final Duration Function() now;
  static const threshold = Duration(seconds: 5);
  static const idleGap = Duration(seconds: 1);
  Duration activeTime = Duration.zero;
  Duration? _input, _sample;
  bool _enabled = false, _consumed = false;

  void setEnabled(bool value) {
    if (_enabled == value) return;
    if (_enabled) sample();
    _enabled = value;
    _input = null;
    _sample = now();
  }

  void interact() {
    if (!_enabled || _consumed) return;
    sample();
    _input = now();
  }

  bool sample() {
    final time = now();
    final last = _sample;
    final input = _input;
    if (_enabled && !_consumed && last != null && input != null) {
      final end = time < input + idleGap ? time : input + idleGap;
      if (end > last) activeTime += end - last;
    }
    _sample = time;
    return !_consumed && activeTime >= threshold;
  }

  void consume() {
    _consumed = true;
  }
}
