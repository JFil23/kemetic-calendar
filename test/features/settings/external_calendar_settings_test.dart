import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/external_calendar_repository.dart';
import 'package:mobile/features/settings/external_calendar_panel.dart';
import 'package:mobile/features/settings/external_calendar_settings.dart';
import 'package:mobile/services/external_calendar_controller.dart';

import '../../support/maat_flow_visual_test_fonts.dart';

const _deniedNotice =
    'Google Calendar access wasn’t granted. You can try connecting again.';
const _mismatchNotice =
    'That Google account differs from your existing calendar connection. '
    'Reconnect the same account, or disconnect it before choosing another.';
const _reconnectNotice =
    'Google Calendar could not finish connecting. Please try again.';

void main() {
  setUpAll(loadMaatFlowVisualTestFonts);

  testWidgets(
    'projection failure retries reading without another import or consent',
    (tester) async {
      final controller = _FakeController()
        ..status = _status(connected: true)
        ..readFailure = _failure('offline');
      await tester.pumpWidget(
        _harness(ExternalCalendarSettings(controller: controller)),
      );
      await tester.pump();
      final retry = find.text('Retry loading events');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pump();
      expect(controller.readRetries, 1);
      expect(controller.refreshes, 0);
      expect(controller.connects, 0);
      expect(
        find.text(
          'Imported events could not be loaded. Any saved copies remain visible.',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'no selected sources remains setup even with a legacy success timestamp',
    (tester) async {
      final controller = _FakeController()
        ..status = ExternalCalendarStatus(
          connectionId: 'connection',
          connectionState: 'connected',
          automatic: true,
          lastSyncedAt: DateTime(2026, 10, 2),
          importedEventCount: 0,
        );
      await tester.pumpWidget(
        _harness(ExternalCalendarSettings(controller: controller)),
      );
      await tester.pump();
      expect(
        find.text(
          'Google is connected. Choose at least one calendar to start importing.',
        ),
        findsOneWidget,
      );
      expect(find.text('Import now'), findsNothing);
      expect(find.textContaining('Last updated'), findsNothing);
      await tester.tap(find.text('Choose calendars'));
      await tester.pump();
      expect(controller.calendarReads, 1);
      expect(controller.connects, 0);
    },
  );

  testWidgets('denial is delivered only after the calendar child mounts', (
    tester,
  ) async {
    final controller = _FakeController();
    final consumed = <String>[];
    var ready = false;
    late StateSetter update;
    await tester.pumpWidget(
      _harness(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return ready
                ? ExternalCalendarSettings(
                    controller: controller,
                    callbackResult: 'denied',
                    onCallbackConsumed: consumed.add,
                  )
                : const CircularProgressIndicator();
          },
        ),
      ),
    );
    expect(consumed, isEmpty);
    expect(controller.statusReads, 0);
    update(() => ready = true);
    await tester.pump();
    expect(consumed, ['denied']);
    expect(find.text(_deniedNotice), findsOneWidget);
    expect(controller.statusReads, 1);
    expect(controller.status!.connected, isFalse);
    expect(controller.connects, 0);
    expect(controller.disconnects, 0);
    expect(controller.saves, 0);
  });

  testWidgets(
    'account mismatch survives passive refresh without changing state',
    (tester) async {
      final controller = _FakeController()..status = _status(connected: true);
      final before = controller.status;
      await tester.pumpWidget(
        _harness(
          ExternalCalendarSettings(
            controller: controller,
            callbackResult: 'account_mismatch',
          ),
        ),
      );
      await tester.pump();
      expect(find.text(_mismatchNotice), findsOneWidget);
      controller.notifyListeners();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(controller.statusReads, 2);
      expect(find.text(_mismatchNotice), findsOneWidget);
      expect(controller.status, same(before));
      expect(controller.error, isNull);
      expect(controller.connects, 0);
      expect(controller.disconnects, 0);
      expect(controller.requestedAutomatic, isNull);
    },
  );

  testWidgets(
    'warm callback reloads status and repeated denial works after retry',
    (tester) async {
      final controller = _FakeController();
      final consumed = <String>[];
      Widget build(String? result) => _harness(
        ExternalCalendarSettings(
          controller: controller,
          callbackResult: result,
          onCallbackConsumed: consumed.add,
          launchAuthorization: (_) async => true,
        ),
      );
      await tester.pumpWidget(build(null));
      expect(controller.statusReads, 1);
      await tester.pumpWidget(build('denied'));
      expect(controller.statusReads, 2);
      expect(find.text(_deniedNotice), findsOneWidget);
      await tester.pumpWidget(build(null));
      expect(controller.statusReads, 2);
      expect(find.text(_deniedNotice), findsOneWidget);
      await tester.tap(find.text('Connect Google Calendar'));
      await tester.pump();
      expect(find.text(_deniedNotice), findsNothing);
      expect(controller.connects, 1);
      await tester.pumpWidget(build('denied'));
      expect(controller.statusReads, 3);
      expect(find.text(_deniedNotice), findsOneWidget);
      expect(consumed, ['denied', 'denied']);
      await tester.pumpWidget(build(null));
      await tester.ensureVisible(find.text('Dismiss'));
      await tester.tap(find.text('Dismiss'));
      await tester.pump();
      expect(find.text(_deniedNotice), findsNothing);
    },
  );

  testWidgets(
    'account switch clears a callback and does not replay the old query',
    (tester) async {
      final controller = _FakeController();
      Widget build(String? result) => _harness(
        ExternalCalendarSettings(
          controller: controller,
          callbackResult: result,
        ),
      );
      await tester.pumpWidget(build('account_mismatch'));
      expect(find.text(_mismatchNotice), findsOneWidget);
      controller.accountId = 'account-two';
      controller.notifyListeners();
      await tester.pump();
      expect(find.text(_mismatchNotice), findsNothing);
      await tester.pumpWidget(build('account_mismatch'));
      expect(find.text(_mismatchNotice), findsNothing);
      await tester.pumpWidget(build(null));
      await tester.pumpWidget(build('reconnect_required'));
      expect(find.text(_reconnectNotice), findsOneWidget);
      controller.accountId = null;
      controller.notifyListeners();
      await tester.pump();
      expect(find.text(_reconnectNotice), findsNothing);
    },
  );

  testWidgets(
    'connected query is navigation feedback, never connection proof',
    (tester) async {
      final controller = _FakeController();
      final consumed = <String>[];
      final before = controller.status;
      Widget build(String? result) => _harness(
        ExternalCalendarSettings(
          controller: controller,
          callbackResult: result,
          onCallbackConsumed: consumed.add,
        ),
      );
      await tester.pumpWidget(build('connected'));
      expect(controller.statusReads, 1);
      expect(controller.status, same(before));
      expect(controller.status!.connected, isFalse);
      expect(find.text('Connect Google Calendar'), findsOneWidget);
      expect(find.text('Dismiss'), findsNothing);
      expect(consumed, ['connected']);
      await tester.pumpWidget(build(null));
      await tester.pumpWidget(build('connected'));
      expect(controller.statusReads, 2);
      expect(controller.status, same(before));
      expect(controller.connects, 0);
      expect(controller.refreshes, 0);
      expect(controller.disconnects, 0);
      expect(controller.saves, 0);
    },
  );

  testWidgets(
    'unknown callback values are not displayed or treated as outcomes',
    (tester) async {
      final controller = _FakeController();
      final consumed = <String>[];
      Widget build(String? result) => _harness(
        ExternalCalendarSettings(
          controller: controller,
          callbackResult: result,
          onCallbackConsumed: consumed.add,
        ),
      );
      await tester.pumpWidget(build('arbitrary-secret'));
      expect(controller.statusReads, 1);
      expect(find.textContaining('arbitrary-secret'), findsNothing);
      expect(find.text('Dismiss'), findsNothing);
      expect(consumed, isEmpty);
      await tester.pumpWidget(build('another-unknown'));
      expect(controller.statusReads, 1);
      expect(controller.status!.connected, isFalse);
      expect(controller.connects, 0);
    },
  );

  testWidgets('callback notice fits portrait at 2x text and can be dismissed', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: RepaintBoundary(
          key: const ValueKey('callback-capture'),
          child: Scaffold(
            appBar: AppBar(title: const Text('Settings')),
            body: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: ExternalCalendarSettings(
                controller: _FakeController(),
                callbackResult: 'account_mismatch',
                showAppleAvailability: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Dismiss'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
    final notice = tester.getRect(find.text(_mismatchNotice));
    expect(notice.left, greaterThanOrEqualTo(16));
    expect(notice.right, lessThanOrEqualTo(374));
    expect(tester.widget<Text>(find.text(_mismatchNotice)).maxLines, isNull);
    if (const bool.fromEnvironment('CAPTURE_EXTERNAL_CALENDAR')) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('callback-capture')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          '/tmp/haw-fresh-calendar-visuals/callback-mismatch-portrait-2x.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.tap(find.text('Dismiss'));
    await tester.pump();
    expect(find.text(_mismatchNotice), findsNothing);
  });

  testWidgets(
    'mount, resume and remount refresh status without opening consent',
    (tester) async {
      final controller = _FakeController();
      var launches = 0;
      Widget build() => _harness(
        ExternalCalendarSettings(
          controller: controller,
          launchAuthorization: (_) async {
            launches++;
            return true;
          },
        ),
      );
      await tester.pumpWidget(build());
      await tester.pump();
      expect(controller.statusReads, 1);
      expect(controller.connects, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(controller.statusReads, 2);
      expect(controller.connects, 0);
      expect(launches, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(build());
      await tester.pump();
      expect(controller.statusReads, 3);
      expect(
        controller.wasDisposed,
        isFalse,
        reason: 'Settings is a subscriber, not the shared controller owner.',
      );
      expect(launches, 0);
    },
  );

  testWidgets(
    'explicit Connect opens only the separate calendar authorization',
    (tester) async {
      final controller = _FakeController();
      Uri? launched;
      await tester.pumpWidget(
        _harness(
          ExternalCalendarSettings(
            controller: controller,
            launchAuthorization: (uri) async {
              launched = uri;
              return true;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Connect Google Calendar'));
      await tester.pump();
      expect(controller.connects, 1);
      expect(launched, Uri.https('accounts.google.com', '/o/oauth2/v2/auth'));
      expect(controller.disconnects, 0);
    },
  );

  testWidgets(
    'failed browser launch offers a useful message without leaking URL',
    (tester) async {
      final controller = _FakeController();
      await tester.pumpWidget(
        _harness(
          ExternalCalendarSettings(
            controller: controller,
            launchAuthorization: (_) async => false,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Connect Google Calendar'));
      await tester.pump();
      expect(
        find.text('Could not open Google. Please try connecting again.'),
        findsOneWidget,
      );
      expect(find.textContaining('accounts.google.com'), findsNothing);
      expect(controller.disconnects, 0);
    },
  );

  testWidgets(
    'disconnect requires confirmation and cancelling performs no write',
    (tester) async {
      final controller = _FakeController()..status = _status(connected: true);
      await tester.pumpWidget(
        _harness(ExternalCalendarSettings(controller: controller)),
      );
      await tester.pump();
      await tester.tap(find.text('Disconnect Google'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Hꜣw-created events stay unchanged.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(controller.disconnects, 0);
      await tester.tap(find.text('Disconnect Google'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();
      expect(controller.disconnects, 1);
    },
  );

  testWidgets(
    'account change while disconnect dialog is open cannot remove another connection',
    (tester) async {
      final controller = _FakeController()..status = _status(connected: true);
      await tester.pumpWidget(
        _harness(ExternalCalendarSettings(controller: controller)),
      );
      await tester.pump();
      await tester.tap(find.text('Disconnect Google'));
      await tester.pumpAndSettle();
      controller.accountId = 'account-two';
      controller.generation++;
      controller.notifyListeners();
      await tester.pump();
      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();
      expect(controller.disconnects, 0);
    },
  );

  testWidgets('delayed consent from a replaced account cannot open a browser', (
    tester,
  ) async {
    final controller = _FakeController()..pendingConnect = Completer<Uri?>();
    var launches = 0;
    await tester.pumpWidget(
      _harness(
        ExternalCalendarSettings(
          controller: controller,
          launchAuthorization: (_) async {
            launches++;
            return true;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Connect Google Calendar'));
    controller.accountId = 'account-two';
    controller.generation++;
    controller.pendingConnect!.complete(
      Uri.https('accounts.google.com', '/auth'),
    );
    await tester.pump();
    expect(launches, 0);
  });

  testWidgets(
    'choosing calendars delegates draft selection and explicit Save',
    (tester) async {
      final controller = _FakeController()..status = _status(connected: true);
      await tester.pumpWidget(
        _harness(ExternalCalendarSettings(controller: controller)),
      );
      await tester.pump();
      await tester.tap(find.text('Choose calendars'));
      await tester.pump();
      expect(controller.calendarReads, 1);
      expect(find.text('Personal'), findsOneWidget);
      await tester.tap(find.text('Family'));
      await tester.pump();
      expect(controller.selectedSourceIds, {'personal', 'family'});
      expect(controller.saves, 0);
      await tester.tap(find.text('Import selected calendars'));
      await tester.pump();
      expect(controller.saves, 1);
    },
  );

  testWidgets(
    'cancel selection performs no save and leaves account state unchanged',
    (tester) async {
      final controller = _FakeController()..status = _status(connected: true);
      await tester.pumpWidget(
        _harness(ExternalCalendarSettings(controller: controller)),
      );
      await tester.pump();
      await tester.tap(find.text('Choose calendars'));
      await tester.pump();
      await tester.tap(find.text('Family'));
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(controller.saves, 0);
      expect(
        controller.status!.sources
            .where((source) => source.selected)
            .map((source) => source.id),
        ['personal'],
      );
    },
  );

  testWidgets('pause dispatches account preference and never disconnects', (
    tester,
  ) async {
    final controller = _FakeController()..status = _status(connected: true);
    await tester.pumpWidget(
      _harness(ExternalCalendarSettings(controller: controller)),
    );
    await tester.pump();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(controller.requestedAutomatic, isFalse);
    expect(controller.disconnects, 0);
    expect(controller.saves, 0);
    expect(
      tester
          .widget<ExternalCalendarPanel>(find.byType(ExternalCalendarPanel))
          .automaticImport,
      isTrue,
      reason:
          'The server-confirmed preference remains visible until acknowledgement.',
    );
  });

  testWidgets(
    'connected failure retries import while cold failure retries status',
    (tester) async {
      final controller = _FakeController()
        ..status = _status(connected: true)
        ..error = _failure('offline');
      await tester.pumpWidget(
        _harness(ExternalCalendarSettings(controller: controller)),
      );
      await tester.pump();
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(controller.refreshes, 1);
      expect(controller.statusReads, 1);
      controller.status = null;
      controller.notifyListeners();
      await tester.pump();
      expect(find.text('Disconnect Google'), findsNothing);
      expect(find.text('Choose calendars'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(controller.statusReads, 2);
      expect(controller.refreshes, 1);
    },
  );

  testWidgets(
    'reconnect-required preserves account copy and prompts only on tap',
    (tester) async {
      final controller = _FakeController()
        ..status = _status(connected: true, reconnect: true);
      await tester.pumpWidget(
        _harness(
          ExternalCalendarSettings(
            controller: controller,
            launchAuthorization: (_) async => true,
          ),
        ),
      );
      await tester.pump();
      expect(
        find.textContaining('Your saved events remain available.'),
        findsOneWidget,
      );
      expect(controller.connects, 0);
      await tester.tap(find.text('Reconnect Google Calendar'));
      await tester.pump();
      expect(controller.connects, 1);
    },
  );

  testWidgets(
    'selection revision conflict requires explicit inventory reload',
    (tester) async {
      final controller = _FakeController()
        ..status = _status(connected: true)
        ..choosingCalendars = true
        ..error = _failure('stale_attempt');
      await tester.pumpWidget(
        _harness(ExternalCalendarSettings(controller: controller)),
      );
      await tester.pump();
      expect(
        find.text(
          'Your calendar connection changed. Choose your calendars again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Import selected calendars'), findsNothing);
      await tester.tap(find.text('Choose calendars again'));
      await tester.pump();
      expect(controller.calendarReads, 1);
      expect(controller.saves, 0);
    },
  );

  testWidgets(
    'failed selection cannot silently discard the draft through import retry',
    (tester) async {
      final controller = _FakeController()
        ..status = _status(connected: true)
        ..choosingCalendars = true
        ..error = _failure('offline');
      await tester.pumpWidget(
        _harness(ExternalCalendarSettings(controller: controller)),
      );
      await tester.pump();
      expect(
        find.text(
          'Your calendar choices could not be confirmed. Choose your calendars again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsNothing);
      await tester.tap(find.text('Choose calendars again'));
      await tester.pump();
      expect(controller.calendarReads, 1);
      expect(controller.refreshes, 0);
      expect(controller.saves, 0);
    },
  );

  testWidgets('server import progress prevents another simultaneous import', (
    tester,
  ) async {
    final controller = _FakeController()
      ..status = const ExternalCalendarStatus(
        connectionId: 'google',
        connectionState: 'connected',
        syncing: true,
      );
    await tester.pumpWidget(
      _harness(ExternalCalendarSettings(controller: controller)),
    );
    await tester.pump();
    final panel = tester.widget<ExternalCalendarPanel>(
      find.byType(ExternalCalendarPanel),
    );
    expect(panel.state, ExternalCalendarPanelState.refreshing);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    expect(controller.refreshes, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('unconfigured state cannot offer an unusable connection', (
    tester,
  ) async {
    final controller = _FakeController()..status = _status(available: false);
    await tester.pumpWidget(
      _harness(ExternalCalendarSettings(controller: controller)),
    );
    await tester.pump();
    expect(find.text('Connect Google Calendar'), findsNothing);
    expect(
      find.text('Google Calendar connection is not available yet.'),
      findsOneWidget,
    );
    expect(controller.connects, 0);
  });

  testWidgets('late connection after Settings closes cannot open a browser', (
    tester,
  ) async {
    final controller = _FakeController()..pendingConnect = Completer<Uri?>();
    var launches = 0;
    await tester.pumpWidget(
      _harness(
        ExternalCalendarSettings(
          controller: controller,
          launchAuthorization: (_) async {
            launches++;
            return true;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Connect Google Calendar'));
    await tester.pumpWidget(const SizedBox.shrink());
    controller.pendingConnect!.complete(
      Uri.https('accounts.google.com', '/auth'),
    );
    await tester.pump();
    expect(launches, 0);
    expect(tester.takeException(), isNull);
    expect(controller.wasDisposed, isFalse);
  });
}

Widget _harness(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

ExternalCalendarStatus _status({
  bool available = true,
  bool connected = false,
  bool reconnect = false,
}) => ExternalCalendarStatus(
  available: available,
  connectionId: connected ? 'connection-one' : null,
  connectionState: reconnect
      ? 'reconnect_required'
      : (connected ? 'connected' : 'disconnected'),
  automatic: true,
  accountLabel: connected ? 'river@example.com' : null,
  lastSyncedAt: connected ? DateTime(2026, 10, 2, 9, 41) : null,
  sources: const [
    ExternalCalendarSource(id: 'personal', label: 'Personal', selected: true),
    ExternalCalendarSource(id: 'family', label: 'Family'),
  ],
);

ExternalCalendarFailure _failure(String code) =>
    ExternalCalendarFailure(code: code, retryable: true);

class _FakeController extends ChangeNotifier
    implements ExternalCalendarController {
  @override
  ExternalCalendarStatus? status = _status();
  @override
  String? accountId = 'account-one';
  @override
  int generation = 0;
  @override
  ExternalCalendarFailure? error;
  @override
  bool busy = false;
  @override
  bool choosingCalendars = false;
  @override
  Set<String> selectedSourceIds = {};
  int statusReads = 0;
  int connects = 0;
  int disconnects = 0;
  int calendarReads = 0;
  int refreshes = 0;
  int readRetries = 0;
  @override
  ExternalCalendarFailure? readFailure;
  @override
  Future<void> retryReads() async {
    readRetries++;
    readFailure = null;
    notifyListeners();
  }

  @override
  Future<void> finishConnection() async => loadStatus();
  int saves = 0;
  bool? requestedAutomatic;
  bool wasDisposed = false;
  Completer<Uri?>? pendingConnect;

  @override
  Future<void> loadStatus() async => statusReads++;
  @override
  Future<Uri?> connect() async {
    connects++;
    return pendingConnect == null
        ? Uri.https('accounts.google.com', '/o/oauth2/v2/auth')
        : pendingConnect!.future;
  }

  @override
  Future<void> chooseCalendars() async {
    calendarReads++;
    choosingCalendars = true;
    selectedSourceIds = status!.sources
        .where((source) => source.selected)
        .map((source) => source.id)
        .toSet();
    notifyListeners();
  }

  @override
  void setSourceSelected(String id, bool selected) {
    if (selected) {
      selectedSourceIds.add(id);
    } else {
      selectedSourceIds.remove(id);
    }
    notifyListeners();
  }

  @override
  void cancelSelection() {
    choosingCalendars = false;
    notifyListeners();
  }

  @override
  Future<void> saveSelection() async => saves++;
  @override
  Future<void> refresh() async => refreshes++;
  @override
  Future<void> setAutomatic(bool enabled) async => requestedAutomatic = enabled;
  @override
  Future<void> disconnect() async => disconnects++;
  @override
  void start() {}
  @override
  void stop() {}
  @override
  void dispose() {
    wasDisposed = true;
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected controller member: ${invocation.memberName}',
  );
}
