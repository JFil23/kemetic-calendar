import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

typedef BootAppFactory = Future<Widget> Function();

enum RootBootPhase { booting, ready, error }

class BootCoordinator extends ChangeNotifier {
  RootBootPhase _phase = RootBootPhase.booting;
  Widget? _app;
  Object? _error;
  StackTrace? _stackTrace;
  BootAppFactory? _bootstrap;
  int _generation = 0;
  bool _started = false;
  bool _disposed = false;

  RootBootPhase get phase => _phase;
  Widget? get app => _app;
  Object? get error => _error;
  StackTrace? get stackTrace => _stackTrace;

  void start(BootAppFactory bootstrap) {
    if (_started) return;
    _started = true;
    _bootstrap = bootstrap;
    _run(bootstrap);
  }

  void retry() {
    final bootstrap = _bootstrap;
    if (bootstrap == null || _phase != RootBootPhase.error) return;
    _phase = RootBootPhase.booting;
    _app = null;
    _error = null;
    _stackTrace = null;
    _notifyIfAlive();
    _run(bootstrap);
  }

  void _run(BootAppFactory bootstrap) {
    final generation = ++_generation;
    unawaited(() async {
      try {
        await WidgetsBinding.instance.endOfFrame;
        if (_disposed || generation != _generation) return;
        final app = await bootstrap();
        if (_disposed || generation != _generation) return;
        _app = app;
        _error = null;
        _stackTrace = null;
        _phase = RootBootPhase.ready;
        _notifyIfAlive();
      } catch (error, stackTrace) {
        if (_disposed || generation != _generation) return;
        _app = null;
        _error = error;
        _stackTrace = stackTrace;
        _phase = RootBootPhase.error;
        _notifyIfAlive();
      }
    }());
  }

  void _notifyIfAlive() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class RootBootApp extends StatefulWidget {
  const RootBootApp({super.key, required this.coordinator, this.onReadyFrame});

  final BootCoordinator coordinator;
  final VoidCallback? onReadyFrame;

  @override
  State<RootBootApp> createState() => _RootBootAppState();
}

class _RootBootAppState extends State<RootBootApp> {
  Widget? _lastReadyApp;

  @override
  void initState() {
    super.initState();
    widget.coordinator.addListener(_handleCoordinatorChanged);
  }

  @override
  void didUpdateWidget(covariant RootBootApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coordinator == widget.coordinator) return;
    oldWidget.coordinator.removeListener(_handleCoordinatorChanged);
    widget.coordinator.addListener(_handleCoordinatorChanged);
    _lastReadyApp = null;
  }

  @override
  void dispose() {
    widget.coordinator.removeListener(_handleCoordinatorChanged);
    super.dispose();
  }

  void _handleCoordinatorChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _scheduleReadyFrameCallback(Widget app) {
    if (_lastReadyApp == app) return;
    _lastReadyApp = app;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lastReadyApp != app) return;
      widget.onReadyFrame?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.coordinator.phase) {
      case RootBootPhase.ready:
        final app = widget.coordinator.app;
        if (app == null) return const RootBootShell();
        _scheduleReadyFrameCallback(app);
        return app;
      case RootBootPhase.error:
        return RootBootErrorShell(
          error: widget.coordinator.error,
          onRetry: widget.coordinator.retry,
        );
      case RootBootPhase.booting:
        return const RootBootShell();
    }
  }
}

class RootBootShell extends StatelessWidget {
  const RootBootShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFF171518),
        body: SafeArea(
          child: Center(
            child: Text(
              'ḥꜣw',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFD4AF37),
                fontFamily: 'GentiumPlus',
                fontSize: 46,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RootBootErrorShell extends StatelessWidget {
  const RootBootErrorShell({super.key, required this.onRetry, this.error});

  final VoidCallback onRetry;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final visibleError = kDebugMode ? error?.toString() : null;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF171518),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Unable to start',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFD4AF37),
                      fontFamily: 'GentiumPlus',
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (visibleError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      visibleError,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
