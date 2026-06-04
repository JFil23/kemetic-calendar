import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NavigationTrace extends ChangeNotifier {
  NavigationTrace._();

  static final NavigationTrace instance = NavigationTrace._();
  static const String preferencesKey = 'navigation_trace.enabled';
  static const int _maxEntries = 40;

  final List<String> _entries = <String>[];
  bool _enabled = false;
  bool _loaded = false;

  bool get enabled => _enabled;
  List<String> get entries => List<String>.unmodifiable(_entries);

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(preferencesKey) ?? false;
      if (_enabled) {
        _addEntry('Navigation Trace restored');
      }
    } catch (_) {
      _enabled = false;
    }
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    _loaded = true;
    if (_enabled != enabled) {
      _enabled = enabled;
      if (!enabled) _entries.clear();
      notifyListeners();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(preferencesKey, enabled);
    } catch (_) {
      // Trace persistence is diagnostic only.
    }

    if (enabled) {
      _entries.clear();
      _addEntry('Navigation Trace enabled');
      notifyListeners();
    }
  }

  void record(String label, {Map<String, Object?> state = const {}}) {
    if (!_enabled) return;
    final stateText = _formatState(state);
    _addEntry(stateText.isEmpty ? label : '$label $stateText');
    notifyListeners();
  }

  void recordError(
    String label,
    Object error,
    StackTrace stackTrace, {
    Map<String, Object?> state = const {},
    int stackLines = 8,
  }) {
    if (!_enabled) return;
    record(
      label,
      state: <String, Object?>{
        ...state,
        'errorType': error.runtimeType,
        'error': error.toString(),
      },
    );
    final frames = stackTrace
        .toString()
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(stackLines);
    var index = 1;
    for (final frame in frames) {
      _addEntry(
        '${_safeText(label, maxLength: 80)} stack$index '
        '${_safeText(frame, maxLength: 120)}',
      );
      index += 1;
    }
    notifyListeners();
  }

  @visibleForTesting
  void resetForTesting() {
    _enabled = false;
    _loaded = false;
    _entries.clear();
    notifyListeners();
  }

  void _addEntry(String text) {
    _entries.add(
      '${_clock(DateTime.now())} ${_safeText(text, maxLength: 180)}',
    );
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
  }

  String _formatState(Map<String, Object?> state) {
    if (state.isEmpty) return '';
    final parts = <String>[];
    for (final entry in state.entries) {
      final value = entry.value;
      if (value == null) continue;
      parts.add(
        '${_safeText(entry.key, maxLength: 32)}='
        '${_safeText(value.toString(), maxLength: 72)}',
      );
    }
    return parts.join(' ');
  }

  String _safeText(String value, {required int maxLength}) {
    final compact = value
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    final safe = compact.replaceAll(
      RegExp(r"[^A-Za-z0-9 ._:+/=?&<>,()'-]"),
      '?',
    );
    if (safe.length <= maxLength) return safe;
    return '${safe.substring(0, maxLength - 3)}...';
  }

  String _clock(DateTime value) {
    return [
      value.hour.toString().padLeft(2, '0'),
      value.minute.toString().padLeft(2, '0'),
      value.second.toString().padLeft(2, '0'),
    ].join(':');
  }
}

class NavigationTraceOverlay extends StatelessWidget {
  const NavigationTraceOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final trace = NavigationTrace.instance;
    return AnimatedBuilder(
      animation: trace,
      builder: (context, _) {
        if (!trace.enabled) return child;
        final entries = trace.entries;
        final start = entries.length > 8 ? entries.length - 8 : 0;
        final visibleEntries = entries.sublist(start);

        return Stack(
          fit: StackFit.expand,
          alignment: Alignment.topLeft,
          children: [
            child,
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: SafeArea(
                bottom: false,
                child: IgnorePointer(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Navigation Trace',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                for (final entry in visibleEntries)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      entry,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                        height: 1.25,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
