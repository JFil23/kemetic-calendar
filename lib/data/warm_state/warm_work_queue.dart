import 'dart:async';

/// Runs passive work only while its foreground/account generation is current.
/// The zone guard is checked at every repository read and before publication.
const warmReadGuard = #hawWarmReadGuard;

class WarmWorkQueue {
  WarmWorkQueue({this.concurrency = 2});
  final int concurrency;
  final _jobs = <String, Future<void> Function()>{};
  final _running = <String>{};
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
  }

  void enqueue(String key, Future<void> Function() job) {
    if (!_active || _running.contains(key)) return;
    _jobs[key] = job;
    _pump();
  }

  void _pump() {
    while (_active && _running.length < concurrency && _jobs.isNotEmpty) {
      final key = _jobs.keys.first;
      final job = _jobs.remove(key)!;
      final generation = _generation;
      _running.add(key);
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
