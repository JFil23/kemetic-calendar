import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/calendar/the_reading_house/presentation/reading_house_sitting_editor.dart';
import '../features/calendar/the_reading_house/presentation/reading_house_detail_page.dart';
import '../features/calendar/the_reading_house_flow.dart';
import '../features/calendar/track_sky_flow.dart';
import '../widgets/keyboard_aware.dart';
import '../widgets/keyboard_viewport_metrics.dart';
import 'modal_keyboard_diagnostic_browser.dart';

const String modalKeyboardDiagnosticRoute = '/debug/modal-keyboard';

const ValueKey<String> modalKeyboardCaseESystemInsetOwnerKey = ValueKey<String>(
  'modal-keyboard-case-e-system-inset-owner',
);
const ValueKey<String> modalKeyboardCaseEContentKey = ValueKey<String>(
  'modal-keyboard-case-e-content',
);

class ModalKeyboardDiagnosticPage extends StatefulWidget {
  const ModalKeyboardDiagnosticPage({super.key, required this.buildLabel});

  final String buildLabel;

  @override
  State<ModalKeyboardDiagnosticPage> createState() =>
      _ModalKeyboardDiagnosticPageState();
}

class _ModalKeyboardDiagnosticPageState
    extends State<ModalKeyboardDiagnosticPage>
    with WidgetsBindingObserver {
  final List<String> _entries = <String>[];
  BrowserViewportSubscription? _browserSubscription;
  BrowserViewportSnapshot? _browserSnapshot;
  GlobalKey<_KeyboardGeometryProbeState>? _activeProbeKey;
  Timer? _settledFocusTimer;
  bool? _lastSystemKeyboardVisible;
  int _sequence = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_handleFocusChanged);
    _browserSubscription = observeBrowserViewport(_handleBrowserViewportEvent);
  }

  @override
  void dispose() {
    _settledFocusTimer?.cancel();
    _browserSubscription?.dispose();
    FocusManager.instance.removeListener(_handleFocusChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _capture('flutter.metrics.immediate');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _capture('flutter.metrics.postFrame');
    });
  }

  void _handleBrowserViewportEvent(
    String event,
    BrowserViewportSnapshot snapshot,
  ) {
    _browserSnapshot = snapshot;
    _capture(event);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _capture('$event.postFrame');
    });
  }

  void _handleFocusChanged() {
    final probe = _activeProbeKey?.currentState;
    if (probe == null || !probe.ownsPrimaryFocus) return;
    _capture('focus.immediate');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _capture('focus.postFrame');
    });
    _settledFocusTimer?.cancel();
    _settledFocusTimer = Timer(const Duration(milliseconds: 750), () {
      _capture('focus.keyboardSettled');
    });
  }

  void _capture(String phase) {
    if (!mounted) return;
    final probe = _activeProbeKey?.currentState;
    final measurement = probe?.measure(phase: phase, browser: _browserSnapshot);
    final keyboardVisible = measurement?.systemKeyboardVisible;
    final transition =
        keyboardVisible != null &&
            _lastSystemKeyboardVisible != null &&
            keyboardVisible != _lastSystemKeyboardVisible
        ? keyboardVisible
              ? ' [SYSTEM KEYBOARD OPENED]'
              : ' [SYSTEM KEYBOARD CLOSED]'
        : '';
    if (keyboardVisible != null) {
      _lastSystemKeyboardVisible = keyboardVisible;
    }

    final body =
        measurement?.report ??
        '${_browserLine(_browserSnapshot)}\nmodal=not-mounted';
    final entry =
        '#${++_sequence} ${DateTime.now().toIso8601String()} '
        'phase=$phase$transition\n$body';
    setState(() {
      _entries.add(entry);
      if (_entries.length > 240) {
        _entries.removeRange(0, _entries.length - 240);
      }
    });
  }

  void _recordFieldMatrix(String report) {
    if (!mounted) return;
    final entry =
        '#${++_sequence} ${DateTime.now().toIso8601String()}\n$report';
    setState(() {
      _entries.add(entry);
      if (_entries.length > 240) {
        _entries.removeRange(0, _entries.length - 240);
      }
    });
  }

  Future<void> _openFieldMatrixBase({required bool currentField}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _FieldMatrixBasePage(
          currentField: currentField,
          onDiagnostic: _recordFieldMatrix,
        ),
      ),
    );
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _openReadingHouseFieldMatrix() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ReadingHouseDetailPage(
          timezone: TrackSkyTimeZone.pacific,
          initialStartDate: DateTime(2026, 9, 14),
          showBackButton: true,
          diagnosticScrollObserver: (sample) =>
              _recordFieldMatrix(sample.toReport()),
        ),
      ),
    );
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _showBaseline({
    required String caseName,
    required bool useSharedSurface,
    bool sharedSurfaceOwnsSystemInset = false,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final probeKey = GlobalKey<_KeyboardGeometryProbeState>();
    _activeProbeKey = probeKey;
    _lastSystemKeyboardVisible = null;

    final future = showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      requestFocus: true,
      builder: (_) {
        const content = _ThreeFieldBaseline();
        final child = useSharedSurface
            ? KeyboardAwareEditableSurface(
                manageSystemKeyboardInset: sharedSurfaceOwnsSystemInset,
                child: content,
              )
            : content;
        return _KeyboardGeometryProbe(
          key: probeKey,
          caseName: caseName,
          child: child,
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _capture('$caseName.beforeFocus');
    });
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (mounted && identical(_activeProbeKey, probeKey)) {
          _capture('$caseName.beforeFocus.settled');
        }
      }),
    );
    await future;
    if (!mounted) return;
    _activeProbeKey = null;
    _lastSystemKeyboardVisible = null;
    _capture('$caseName.modalClosed');
  }

  Future<void> _showSingleSystemInsetOwnerProof() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final probeKey = GlobalKey<_KeyboardGeometryProbeState>();
    final contentKey = GlobalKey();
    _activeProbeKey = probeKey;
    _lastSystemKeyboardVisible = null;
    const caseName = 'E.singleRouteSystemInsetOwner';

    final future = showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      requestFocus: true,
      builder: (_) => _KeyboardGeometryProbe(
        key: probeKey,
        caseName: caseName,
        contentGeometryKey: contentKey,
        child: _DiagnosticSystemInsetOwner(
          contentKey: contentKey,
          child: const _ThreeFieldBaseline(),
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _capture('$caseName.beforeFocus');
    });
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (mounted && identical(_activeProbeKey, probeKey)) {
          _capture('$caseName.beforeFocus.settled');
        }
      }),
    );
    await future;
    if (!mounted) return;
    _activeProbeKey = null;
    _lastSystemKeyboardVisible = null;
    _capture('$caseName.modalClosed');
  }

  Future<void> _showReadingHouseCase() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final probeKey = GlobalKey<_KeyboardGeometryProbeState>();
    _activeProbeKey = probeKey;
    _lastSystemKeyboardVisible = null;
    final initialDate = DateUtils.dateOnly(DateTime.now());

    final future = showModalBottomSheet<ReadingHouseSitting>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      requestFocus: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _KeyboardGeometryProbe(
        key: probeKey,
        caseName: 'C.readingHouseSittingEditor',
        child: ReadingHouseSittingEditorSheet(
          sitting: kReadingHouseSittings.first,
          initialDate: initialDate,
          initialTime: const TimeOfDay(hour: 19, minute: 0),
          flowDayForDate: (_) => 1,
          accentColor: const Color(0xFF7FD9BC),
          borderColor: const Color(0x667FD9BC),
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _capture('C.readingHouseSittingEditor.beforeFocus');
    });
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (mounted && identical(_activeProbeKey, probeKey)) {
          _capture('C.readingHouseSittingEditor.beforeFocus.settled');
        }
      }),
    );
    await future;
    if (!mounted) return;
    _activeProbeKey = null;
    _lastSystemKeyboardVisible = null;
    _capture('C.readingHouseSittingEditor.modalClosed');
  }

  Future<void> _copyReport() async {
    final report = <String>[
      'Modal keyboard diagnostic',
      'build=${widget.buildLabel}',
      ..._entries,
    ].join('\n\n');
    await Clipboard.setData(ClipboardData(text: report));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Diagnostic report copied')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modal keyboard isolation')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Build ${widget.buildLabel}',
              key: const ValueKey<String>('modal-keyboard-build-label'),
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Run E first on the installed iOS PWA. Focus its top, middle, '
              'and bottom fields. The sheet content must remain entirely '
              'above the system keyboard. A, B, and C remain as controls.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey<String>('modal-keyboard-case-a'),
              onPressed: () => _showBaseline(
                caseName: 'A.pureFlutter',
                useSharedSurface: false,
              ),
              child: const Text('A — Pure Flutter modal'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey<String>('modal-keyboard-case-b'),
              onPressed: () => _showBaseline(
                caseName: 'B.sharedNativeOwner',
                useSharedSurface: true,
              ),
              child: const Text('B — Shared sheet, native system inset'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const ValueKey<String>('modal-keyboard-case-b-owned'),
              onPressed: () => _showBaseline(
                caseName: 'B.probeSharedSystemOwner',
                useSharedSurface: true,
                sharedSurfaceOwnsSystemInset: true,
              ),
              child: const Text('Probe — shared sheet owns system inset'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              key: const ValueKey<String>('modal-keyboard-case-e'),
              onPressed: _showSingleSystemInsetOwnerProof,
              child: const Text('E — One route-level system-inset owner'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey<String>('modal-keyboard-case-c'),
              onPressed: _showReadingHouseCase,
              child: const Text('C — Actual Reading House sitting editor'),
            ),
            const SizedBox(height: 24),
            Text(
              'Text-field 2 × 2 matrix',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const ValueKey<String>('text-field-matrix-a'),
              onPressed: () => _openFieldMatrixBase(currentField: false),
              child: const Text('A — Base field + base environment'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const ValueKey<String>('text-field-matrix-c'),
              onPressed: () => _openFieldMatrixBase(currentField: true),
              child: const Text('C — Current Hꜣw field + base environment'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const ValueKey<String>('text-field-matrix-bd'),
              onPressed: _openReadingHouseFieldMatrix,
              child: const Text('B + D — Actual Reading House environment'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _entries.isEmpty ? null : _copyReport,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy report'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _entries.isEmpty
                        ? null
                        : () => setState(_entries.clear),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Clear'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              _entries.isEmpty
                  ? 'No geometry captured yet.'
                  : _entries.reversed.join('\n\n'),
              key: const ValueKey<String>('modal-keyboard-report'),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldMatrixBasePage extends StatefulWidget {
  const _FieldMatrixBasePage({
    required this.currentField,
    required this.onDiagnostic,
  });

  final bool currentField;
  final ValueChanged<String> onDiagnostic;

  @override
  State<_FieldMatrixBasePage> createState() => _FieldMatrixBasePageState();
}

class _FieldMatrixBasePageState extends State<_FieldMatrixBasePage>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final List<TextEditingController> _controllers = List.generate(
    3,
    (_) => TextEditingController(),
  );
  Timer? _keyboardSettle;
  String _lastTrigger = 'page-ready';

  String get _caseName => widget.currentField
      ? 'C.currentFieldBaseEnvironment'
      : 'A.baseFieldBaseEnvironment';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_handleFocusChanged);
    _scrollController.addListener(_handleScrollChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _emit('page.ready', source: 'initial-layout');
    });
  }

  @override
  void dispose() {
    _keyboardSettle?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    FocusManager.instance.removeListener(_handleFocusChanged);
    _scrollController.removeListener(_handleScrollChanged);
    _scrollController.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _lastTrigger = 'keyboard-metrics';
    _emit('keyboard.metrics.immediate', source: 'platform-metrics');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _emit('keyboard.metrics.postFrame', source: 'platform-metrics');
    });
    _keyboardSettle?.cancel();
    _keyboardSettle = Timer(const Duration(milliseconds: 750), () {
      _emit('keyboard.metrics.settled', source: 'platform-metrics');
    });
  }

  void _handleFocusChanged() {
    if (!_ownsPrimaryFocus) return;
    _lastTrigger = 'focus-change';
    _emit('focus.immediate', source: 'focus-manager');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _emit('focus.postFrame', source: 'focus-manager');
    });
  }

  void _handleScrollChanged() {
    _emit('scroll.offset', source: 'framework-or-user-after-$_lastTrigger');
  }

  bool get _ownsPrimaryFocus {
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    if (focusedContext == null) return false;
    var owns = false;
    focusedContext.visitAncestorElements((element) {
      if (identical(element, context)) {
        owns = true;
        return false;
      }
      return true;
    });
    return owns;
  }

  void _emit(String phase, {required String source}) {
    if (!mounted) return;
    final position = _scrollController.hasClients
        ? _scrollController.position
        : null;
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    final rect = _editableTextRect(focusedContext);
    final media = keyboardMediaGeometryOf(context);
    final viewport = keyboardViewportMetricsOf(context);
    widget.onDiagnostic(
      '$_caseName phase=$phase source=$source '
      'offset=${_number(position?.pixels ?? 0)} '
      'min=${_number(position?.minScrollExtent ?? 0)} '
      'max=${_number(position?.maxScrollExtent ?? 0)} '
      'fieldTop=${_number(rect?.top)} fieldBottom=${_number(rect?.bottom)} '
      'mediaHeight=${_number(media.size.height)} '
      'viewInsetBottom=${_number(media.viewInsetBottom)} '
      'systemKeyboardVisible=${viewport.systemKeyboardVisible}',
    );
  }

  Widget _field(int index) {
    final key = ValueKey<String>('text-field-matrix-${index + 1}');
    if (!widget.currentField) {
      return TextField(
        key: key,
        controller: _controllers[index],
        decoration: const InputDecoration(labelText: 'Baseline'),
      );
    }
    return ReadingHouseDetailPage.buildSetupFieldDiagnostic(
      label: 'CURRENT HꜣW FIELD ${index + 1}',
      hintText: 'Current Reading House field',
      controller: _controllers[index],
      fieldKey: key,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_caseName)),
      body: ListView(
        controller: _scrollController,
        children: [
          _field(0),
          const SizedBox(height: 420),
          _field(1),
          const SizedBox(height: 420),
          _field(2),
          const SizedBox(height: 220),
        ],
      ),
    );
  }
}

class _ThreeFieldBaseline extends StatelessWidget {
  const _ThreeFieldBaseline();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          TextField(
            key: ValueKey<String>('modal-keyboard-field-1'),
            decoration: InputDecoration(labelText: 'First field'),
          ),
          TextField(
            key: ValueKey<String>('modal-keyboard-field-2'),
            decoration: InputDecoration(labelText: 'Middle field'),
          ),
          TextField(
            key: ValueKey<String>('modal-keyboard-field-3'),
            decoration: InputDecoration(labelText: 'Last field'),
          ),
        ],
      ),
    );
  }
}

/// Diagnostic-only proof of one system-inset owner at the modal-content root.
///
/// The owner consumes the system keyboard inset exactly once, then removes it
/// from the descendant MediaQuery so the stock fields cannot consume it again.
/// This stays private until Case E proves the boundary on the installed iOS
/// PWA; it is not the shared production modal implementation.
class _DiagnosticSystemInsetOwner extends StatelessWidget {
  const _DiagnosticSystemInsetOwner({
    required this.contentKey,
    required this.child,
  });

  final GlobalKey contentKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      key: modalKeyboardCaseESystemInsetOwnerKey,
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: MediaQuery(
        data: media.removeViewInsets(removeBottom: true),
        child: KeyedSubtree(
          key: contentKey,
          child: KeyedSubtree(key: modalKeyboardCaseEContentKey, child: child),
        ),
      ),
    );
  }
}

class _KeyboardGeometryProbe extends StatefulWidget {
  const _KeyboardGeometryProbe({
    super.key,
    required this.caseName,
    required this.child,
    this.contentGeometryKey,
  });

  final String caseName;
  final Widget child;
  final GlobalKey? contentGeometryKey;

  @override
  State<_KeyboardGeometryProbe> createState() => _KeyboardGeometryProbeState();
}

class _KeyboardGeometryProbeState extends State<_KeyboardGeometryProbe> {
  bool get ownsPrimaryFocus {
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    if (focusedContext == null) return false;
    if (identical(focusedContext, context)) return true;
    var owns = false;
    focusedContext.visitAncestorElements((element) {
      if (identical(element, context)) {
        owns = true;
        return false;
      }
      return true;
    });
    return owns;
  }

  _GeometryMeasurement measure({
    required String phase,
    required BrowserViewportSnapshot? browser,
  }) {
    final media = keyboardMediaGeometryOf(context);
    final resolved = keyboardViewportMetricsOf(context);
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    final focusedRect = _editableTextRect(focusedContext);
    final scrollable = focusedContext == null
        ? null
        : Scrollable.maybeOf(focusedContext);
    final position = scrollable?.position;

    Element? modalElement;
    context.visitAncestorElements((element) {
      if (element.widget is BottomSheet) {
        modalElement = element;
        return false;
      }
      return true;
    });

    final report = <String>[
      'case=${widget.caseName}',
      _browserLine(browser),
      'media.size=${_size(media.size)} '
          'view'
          'Insets.bottom=${_number(media.viewInsetBottom)} '
          'viewPadding.bottom=${_number(media.viewPaddingBottom)} '
          'padding.top=${_number(media.paddingTop)}',
      'resolved.visibleTop=${_number(resolved.visibleTop)} '
          'visibleBottom=${_number(resolved.visibleBottom)} '
          'layoutViewInsetBottom=${_number(resolved.layoutViewInsetBottom)} '
          'systemVisible=${resolved.systemKeyboardVisible} '
          'hawKeyboardInset=${_number(keyboardInsetOf(context))}',
      'modalRouteRect=${_rect(_rectForRenderObject(modalElement?.findRenderObject()))}',
      'sheetContentRect=${_rect(_rectForRenderObject(widget.contentGeometryKey?.currentContext?.findRenderObject() ?? context.findRenderObject()))}',
      'focusedEditableRect=${_rect(focusedRect)}',
      position == null
          ? 'nearestScrollable=none'
          : 'nearestScrollable.offset=${_number(position.pixels)} '
                'min=${_number(position.minScrollExtent)} '
                'max=${_number(position.maxScrollExtent)} '
                'axis=${position.axisDirection.name}',
    ].join('\n');
    return _GeometryMeasurement(
      report: report,
      systemKeyboardVisible: resolved.systemKeyboardVisible,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _GeometryMeasurement {
  const _GeometryMeasurement({
    required this.report,
    required this.systemKeyboardVisible,
  });

  final String report;
  final bool systemKeyboardVisible;
}

Rect? _rectForRenderObject(RenderObject? renderObject) {
  if (renderObject is! RenderBox || !renderObject.hasSize) return null;
  return renderObject.localToGlobal(Offset.zero) & renderObject.size;
}

Rect? _editableTextRect(BuildContext? focusedContext) {
  if (focusedContext == null) return null;
  Element? editableElement;
  if (focusedContext is Element && focusedContext.widget is EditableText) {
    editableElement = focusedContext;
  } else {
    focusedContext.visitAncestorElements((element) {
      if (element.widget is EditableText) {
        editableElement = element;
        return false;
      }
      return true;
    });
  }
  return _rectForRenderObject(editableElement?.findRenderObject());
}

String _number(double? value) =>
    value == null ? 'n/a' : value.toStringAsFixed(1);

String _size(Size value) =>
    '${value.width.toStringAsFixed(1)}x${value.height.toStringAsFixed(1)}';

String _rect(Rect? value) {
  if (value == null) return 'n/a';
  return 'top=${_number(value.top)} bottom=${_number(value.bottom)} '
      'height=${_number(value.height)} left=${_number(value.left)} '
      'right=${_number(value.right)}';
}

String _browserLine(BrowserViewportSnapshot? browser) {
  return 'browser.innerHeight=${_number(browser?.innerHeight)} '
      'visualViewport.height=${_number(browser?.visualViewportHeight)} '
      'offsetTop=${_number(browser?.visualViewportOffsetTop)} '
      'pageTop=${_number(browser?.visualViewportPageTop)}';
}
