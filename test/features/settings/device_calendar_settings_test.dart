import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/external_calendar_repository.dart';
import 'package:mobile/features/settings/device_calendar_panel.dart';
import 'package:mobile/features/settings/device_calendar_settings.dart';
import 'package:mobile/services/device_calendar_controller.dart';
import 'package:mobile/services/external_calendar_controller.dart';

void main() {
  testWidgets(
    'mount and resume read status without asking for calendar permission',
    (tester) async {
      final device = _Device();
      await tester.pumpWidget(_harness(device));
      await tester.pump();
      expect(device.reads, 1);
      expect(device.connections, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(device.reads, 2);
      expect(device.connections, isEmpty);
      await tester.tap(find.text('Choose device calendars'));
      await tester.pump();
      expect(device.connections, [false]);
    },
  );

  testWidgets('selection is preserved across resume and Settings remount', (
    tester,
  ) async {
    final device = _Device()
      ..status = _connected()
      ..choosing = true;
    await tester.pumpWidget(_harness(device));
    await tester.pump();
    expect(device.reads, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(device.reads, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_harness(device));
    await tester.pump();
    expect(device.reads, 0);
    expect(device.disposed, isFalse);
  });

  testWidgets('device transfer is explicit and cancel performs no takeover', (
    tester,
  ) async {
    final device = _Device()
      ..status = _connected()
      ..isOwner = false;
    await tester.pumpWidget(_harness(device));
    await tester.pump();
    await tester.tap(find.text('Use this device'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('The previous device will stop importing.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(device.connections, isEmpty);
    await tester.tap(find.text('Use this device'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this device').last);
    await tester.pumpAndSettle();
    expect(device.connections, [true]);
  });

  testWidgets(
    'account switch during confirmation cannot disconnect another account',
    (tester) async {
      final device = _Device()..status = _connected();
      await tester.pumpWidget(_harness(device));
      await tester.pump();
      await tester.tap(find.text('Disconnect device calendars'));
      await tester.pumpAndSettle();
      device.accountId = 'account-two';
      device.generation++;
      device.notifyListeners();
      await tester.pump();
      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();
      expect(device.disconnects, 0);
    },
  );

  testWidgets(
    'confirmed disconnect preserves the distinction from authored and Google events',
    (tester) async {
      final device = _Device()..status = _connected();
      await tester.pumpWidget(_harness(device));
      await tester.pump();
      await tester.tap(find.text('Disconnect device calendars'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Google imports, and Hꜣw-created events stay unchanged.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();
      expect(device.disconnects, 1);
    },
  );

  testWidgets('permission recovery requests access only on tap', (
    tester,
  ) async {
    final device = _Device()
      ..status = _connected()
      ..errorCode = 'permission_denied';
    await tester.pumpWidget(_harness(device));
    await tester.pump();
    expect(device.connections, isEmpty);
    await tester.tap(find.text('Retry calendar access'));
    await tester.pump();
    expect(device.connections, [false]);
  });

  testWidgets('stale selection must be deliberately chosen again', (
    tester,
  ) async {
    final device = _Device()
      ..status = _connected()
      ..choosing = true
      ..errorCode = 'stale_attempt';
    await tester.pumpWidget(_harness(device));
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
    expect(device.choices, 1);
    expect(device.saves, 0);
  });

  testWidgets(
    'failed native selection requires explicit review instead of unrelated import retry',
    (tester) async {
      final device = _Device()
        ..status = _connected()
        ..choosing = true
        ..errorCode = 'offline';
      await tester.pumpWidget(_harness(device));
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
      expect(device.choices, 1);
      expect(device.refreshes, 0);
      expect(device.saves, 0);
    },
  );

  testWidgets(
    'only selected Google calendars are offered as alternate owners',
    (tester) async {
      final device = _Device()
        ..status = _connected()
        ..choosing = true;
      await tester.pumpWidget(_harness(device));
      await tester.pump();
      final panel = tester.widget<DeviceCalendarPanel>(
        find.byType(DeviceCalendarPanel),
      );
      expect(panel.cloudCalendars.map((calendar) => calendar.id), [
        'google-work',
      ]);
      expect(panel.calendars.single.sourceName, 'Device account');
      expect(panel.calendars.single.selected, isTrue);
    },
  );
}

Widget _harness(_Device device) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(
    body: SingleChildScrollView(
      child: DeviceCalendarSettings(
        controller: device,
        googleController: _Google(),
      ),
    ),
  ),
);

DeviceCalendarStatus _connected() => const DeviceCalendarStatus(
  connectionId: 'device-connection',
  connectionState: 'connected',
  ownerDeviceId: 'device-one',
  automatic: true,
  sources: [
    DeviceCalendarSource(
      id: 'device-source',
      nativeId: 'native-one',
      label: 'Work',
      accountLabel: 'Device account',
      selected: true,
    ),
  ],
);

class _Device extends ChangeNotifier implements DeviceCalendarController {
  @override
  bool supported = true;
  @override
  bool busy = false;
  @override
  bool choosing = false;
  @override
  String? errorCode;
  @override
  DeviceCalendarStatus status = const DeviceCalendarStatus();
  @override
  String? accountId = 'account-one';
  @override
  int generation = 0;
  @override
  bool isOwner = true;
  @override
  Set<String> selectedSources = {'device-source'};
  @override
  Map<String, String> googleBindings = {};
  @override
  Set<String> unresolvedCloudSources = {};
  int reads = 0, refreshes = 0, choices = 0, saves = 0, disconnects = 0;
  bool disposed = false;
  final List<bool> connections = [];
  @override
  Future<void> refreshStatus() async => reads++;
  @override
  Future<void> connect({bool replaceDevice = false}) async =>
      connections.add(replaceDevice);
  @override
  Future<void> chooseCalendars() async => choices++;
  @override
  void selectSource(String id, bool selected) {}
  @override
  void bindCloudSource(String id, String? googleSourceId) {}
  @override
  Future<void> saveSelection() async => saves++;
  @override
  void cancelSelection() {}
  @override
  Future<void> refresh() async => refreshes++;
  @override
  Future<void> setAutomatic(bool enabled) async {}
  @override
  Future<void> disconnect() async => disconnects++;
  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected device member: ${invocation.memberName}',
  );
}

class _Google extends ChangeNotifier implements ExternalCalendarController {
  @override
  ExternalCalendarStatus? get status => const ExternalCalendarStatus(
    connectionId: 'google-connection',
    connectionState: 'connected',
    accountLabel: 'river@example.com',
    sources: [
      ExternalCalendarSource(id: 'google-work', label: 'Work', selected: true),
      ExternalCalendarSource(
        id: 'google-family',
        label: 'Family',
        selected: false,
      ),
    ],
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected Google member: ${invocation.memberName}',
  );
}
