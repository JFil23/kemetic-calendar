import 'dart:async';

/// Runs passive work only while its foreground/account generation is current.
/// The zone guard is checked at every repository read and before publication.
const warmReadGuard = #hawWarmReadGuard;

class WarmWorkQueue {
  WarmWorkQueue({this.concurrency = 2});
  final int concurrency;
  final _jobs = <String, Future<void> Function()>{};
  final _running = <String, int>{};
  final _priority = <String>{};
  int _generation = 0;
  bool _active = false;
  void resume() {
    _active = true;
    _pump();
  }

  void pause() {
    _active = false;
    _generation++;
    _jobs.clear();
    _priority.clear();
  }

  void enqueue(
    String key,
    Future<void> Function() job, {
    bool priority = false,
  }) {
    if (!_active || _running[key] == _generation) return;
    _jobs[key] = job;
    if (priority) _priority.add(key);
    _pump();
  }

  /// Promote queued work without adding a worker, duplicating a request, or
  /// cancelling an in-flight read that a visible route may already share.
  void prioritize(String key) {
    if (_jobs.containsKey(key)) _priority.add(key);
  }

  void _pump() {
    while (_active && _running.length < concurrency && _jobs.isNotEmpty) {
      // A new lifecycle may queue a replacement for a departed read. Wait for
      // that read to exit before reusing its key, without blocking other work.
      bool available(String key) => !_running.containsKey(key);
      final key =
          _priority.where(available).firstOrNull ??
          _jobs.keys.where(available).firstOrNull;
      if (key == null) return;
      _priority.remove(key);
      final job = _jobs.remove(key)!;
      final generation = _generation;
      _running[key] = generation;
      unawaited(() async {
        try {
          await runZoned(
            job,
            zoneValues: {
              warmReadGuard: () => _active && generation == _generation,
            },
          );
        } catch (_) {
          // Keep the last confirmed value; retry on the next bounded sweep.
        } finally {
          _running.remove(key);
          _pump();
        }
      }());
    }
  }
}
