// Launch surfaces restored from a65e1972; shared by startup and route restoration.
import 'dart:async';

import 'package:flutter/material.dart';

import 'shared/glossy_text.dart';
import 'core/boot_diagnostics.dart';

typedef BootAppFactory = Future<Widget> Function(BootAttempt attempt);

enum RootBootPhase { booting, ready, error }

class BootFailure implements Exception {
  const BootFailure(this.stage, this.cause);

  final String stage;
  final Object cause;

  String get diagnostic =>
      'Stage: ${bootStageLabel(stage)}\n'
      'Operation: ${cause is BootStorageFailure ? (cause as BootStorageFailure).operation.name : 'bootstrap'}\n'
      'Error: ${bootErrorCategory(cause)}';

  @override
  String toString() => diagnostic;
}

/// A deadline stops this startup sequence, not the browser's underlying I/O.
/// Never retry a partially initialized auth singleton in the same process.
class BootAttempt {
  bool _active = true;
  String _stage = 'first frame';

  String get stage => _stage;

  void ensureActive() {
    if (!_active) throw BootFailure(_stage, StateError('Startup ended'));
  }

  /// Label synchronous startup work without adding awaits or changing ordering.
  void enterStage(String stage) {
    ensureActive();
    _stage = stage;
  }

  Future<T> run<T>(
    String stage,
    FutureOr<T> Function() operation, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    ensureActive();
    _stage = stage;
    try {
      final result = await Future<T>.sync(operation).timeout(timeout);
      ensureActive();
      return result;
    } catch (error) {
      _active = false;
      if (error is BootFailure) rethrow;
      throw BootFailure(stage, error);
    }
  }

  void _cancel() => _active = false;
}

class BootCoordinator extends ChangeNotifier {
  BootCoordinator({this.timeout = const Duration(seconds: 60), this.onFailure});

  final Duration timeout;
  final void Function(BootFailure failure)? onFailure;
  final BootAttempt _attempt = BootAttempt();
  RootBootPhase _phase = RootBootPhase.booting;
  Widget? _app;
  BootFailure? _error;
  StackTrace? _stackTrace;
  bool _started = false;
  bool _disposed = false;

  RootBootPhase get phase => _phase;
  Widget? get app => _app;
  BootFailure? get error => _error;
  StackTrace? get stackTrace => _stackTrace;

  void start(BootAppFactory bootstrap) {
    if (_started || _disposed) return;
    _started = true;
    unawaited(_run(bootstrap));
  }

  Future<void> _run(BootAppFactory bootstrap) async {
    try {
      // Paint the independent shell before touching plugins, storage or auth.
      await WidgetsBinding.instance.endOfFrame;
      if (_disposed) return;
      final app = await bootstrap(_attempt).timeout(
        timeout,
        onTimeout: () {
          _attempt._cancel();
          throw BootFailure(
            _attempt.stage,
            TimeoutException('Startup deadline'),
          );
        },
      );
      if (_disposed) return;
      _attempt.ensureActive();
      _app = app;
      _phase = RootBootPhase.ready;
    } catch (error, stackTrace) {
      _attempt._cancel();
      if (_disposed) return;
      _error = error is BootFailure
          ? error
          : BootFailure(_attempt.stage, error);
      _stackTrace = stackTrace;
      _phase = RootBootPhase.error;
      try {
        onFailure?.call(_error!);
      } catch (_) {
        // Diagnostics must never prevent the recovery surface from rendering.
      }
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _attempt._cancel();
    super.dispose();
  }
}

// Restored from a65e1972. Recovery is now a full reload instead of running a
// second bootstrap against an auth singleton that may still be initializing.
class RootBootApp extends StatefulWidget {
  const RootBootApp({
    super.key,
    required this.coordinator,
    this.onReadyFrame,
    this.onRetry,
  });

  final BootCoordinator coordinator;
  final VoidCallback? onReadyFrame;
  final VoidCallback? onRetry;

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
    if (mounted) setState(() {});
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
        final app = widget.coordinator.app!;
        _scheduleReadyFrameCallback(app);
        return app;
      case RootBootPhase.error:
        return RootBootErrorShell(
          error: widget.coordinator.error,
          onRetry: widget.onRetry,
        );
      case RootBootPhase.booting:
        return const RootBootShell();
    }
  }
}

const Color launchSurfaceBackdrop = Color(0xFF171518);

class LaunchWordSurface extends StatelessWidget {
  const LaunchWordSurface({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: launchSurfaceBackdrop,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ShimmeringLaunchWord(),
          ),
        ),
      ),
    );
  }
}

class ShimmeringLaunchWord extends StatefulWidget {
  const ShimmeringLaunchWord({super.key});

  @override
  State<ShimmeringLaunchWord> createState() => _ShimmeringLaunchWordState();
}

class _ShimmeringLaunchWordState extends State<ShimmeringLaunchWord>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final shimmerOffset = (_controller.value * 2.6) - 1.3;
        final shimmerGradient = LinearGradient(
          begin: Alignment(-1.6 + shimmerOffset, 0),
          end: Alignment(1.6 + shimmerOffset, 0),
          colors: const [
            goldDeep,
            gold,
            goldLight,
            Color(0xFFFFF8DD),
            goldLight,
            gold,
            goldDeep,
          ],
          stops: const [0.0, 0.2, 0.38, 0.5, 0.62, 0.8, 1.0],
        );

        return GlossyText(
          text: 'ḥꜣw',
          gradient: shimmerGradient,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 42,
            fontWeight: FontWeight.w500,
            fontFamily: 'GentiumPlus',
            fontFamilyFallback: ['NotoSans', 'Roboto', 'Arial', 'sans-serif'],
            shadows: [
              Shadow(
                color: Color(0x552C1A00),
                blurRadius: 18,
                offset: Offset(0, 4),
              ),
            ],
          ),
        );
      },
    );
  }
}

class RootBootShell extends StatelessWidget {
  const RootBootShell({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // A boot surface has no navigation authority. Using home here would
      // publish '/' before the app reads its OAuth callback or deep link.
      builder: (context, child) => const Scaffold(
        backgroundColor: launchSurfaceBackdrop,
        body: LaunchWordSurface(),
      ),
    );
  }
}

class RootBootErrorShell extends StatelessWidget {
  const RootBootErrorShell({super.key, this.onRetry, this.error});

  final VoidCallback? onRetry;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final failure = error;
    final visibleError = failure is BootFailure ? failure.diagnostic : null;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => Scaffold(
        backgroundColor: const Color(0xFF171518),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
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
                      key: const ValueKey('boot-diagnostic'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Release: $bootDiagnosticRelease',
                      key: ValueKey('boot-release'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (onRetry != null)
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: gold),
                      onPressed: onRetry,
                      child: const Text('Retry'),
                    )
                  else
                    const Text(
                      'Close and reopen the app to try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
