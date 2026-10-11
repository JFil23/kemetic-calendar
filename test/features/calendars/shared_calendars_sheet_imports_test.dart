import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/external_calendar_repository.dart';
import 'package:mobile/data/shared_calendar_models.dart';
import 'package:mobile/data/shared_calendars_repo.dart';
import 'package:mobile/features/calendars/shared_calendars_sheet.dart';
import 'package:mobile/services/device_calendar_bridge.dart';
import 'package:mobile/services/device_calendar_controller.dart';
import 'package:mobile/services/external_calendar_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'package:mobile/features/calendar/snapshot/calendar_snapshot_runtime.dart';

import '../../support/maat_flow_visual_test_fonts.dart';

const longName = 'Community gatherings and school volunteer commitments';
const googleStatus = ExternalCalendarStatus(
  connectionId: 'google',
  connectionState: 'connected',
  revision: 1,
  accountLabel: 'river@example.com',
  sources: [
    ExternalCalendarSource(
      id: 'work',
      label: 'Work',
      selected: true,
      color: '#5D9BE8',
    ),
    ExternalCalendarSource(
      id: 'empty',
      label: longName,
      selected: true,
      importedEventCount: 0,
    ),
    ExternalCalendarSource(id: 'unselected', label: 'Not imported'),
  ],
);
const deviceStatus = DeviceCalendarStatus(
  connectionId: 'phone',
  connectionState: 'paused',
  revision: 1,
  sources: [
    DeviceCalendarSource(
      id: 'family',
      nativeId: 'n1',
      label: 'Family',
      selected: true,
      accountLabel: 'iCloud',
      color: '#7BB661',
    ),
    DeviceCalendarSource(
      id: 'duplicate',
      nativeId: 'n2',
      label: 'Duplicate Google calendar',
      selected: true,
      ownedBy: 'google',
      googleSourceId: 'work',
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadMaatFlowVisualTestFonts();
    await Hive.openBox<String>(
      'calendar_snapshot_store_v1',
      bytes: Uint8List(0),
    );
    await calendarSnapshotStore.initialize();
  });
  tearDownAll(() async {
    await calendarSnapshotStore.dispose();
    await Hive.close();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final viewport in {
    'portrait': const Size(390, 844),
    'landscape': const Size(844, 390),
  }.entries) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('imports share the Calendars sheet at ${viewport.key} $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = viewport.value;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final harness = (await tester.runAsync(() async => Harness()))!;
        addTearDown(() => tester.runAsync(harness.dispose));
        await tester.pumpWidget(harness.widget());
        await tester.pumpAndSettle();
        expect(find.text('Work'), findsOneWidget);
        expect(find.text(longName), findsOneWidget);
        expect(find.text('Not imported'), findsNothing);
        expect(find.text('Duplicate Google calendar'), findsNothing);
        expect(
          find.text(
            'Create a family calendar, a friends calendar, or another shared space.',
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        final name = tester.widget<Text>(find.text(longName));
        expect(name.maxLines, isNull);
        expect(name.overflow, isNot(TextOverflow.ellipsis));
        await capture(tester, '${viewport.key}-${scale.toInt()}x');
        await tester.scrollUntilVisible(find.text('Family'), 250);
        await tester.pumpAndSettle();
        expect(find.text('Imported · Phone calendar · iCloud'), findsOneWidget);
        expect(
          tester
              .getSize(
                find.byKey(const ValueKey('delete-imported-calendar-family')),
              )
              .height,
          greaterThanOrEqualTo(48),
        );
        expect(tester.takeException(), isNull);
        await capture(tester, '${viewport.key}-${scale.toInt()}x-scrolled');
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  for (final id in ['work', 'family']) {
    testWidgets(
      '$id deletion waits for acknowledgement and preserves other imports',
      (tester) async {
        final h = (await tester.runAsync(() async => Harness()))!;
        addTearDown(() => tester.runAsync(h.dispose));
        await tester.pumpWidget(h.widget());
        await tester.pumpAndSettle();
        h.calls.clear();
        h.acknowledgement = Completer<void>();
        await tester.tap(find.byKey(ValueKey('delete-imported-calendar-$id')));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('The original calendar stays'),
          findsOneWidget,
        );
        expect(h.calls, isEmpty);
        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(ValueKey('imported-calendar-$id')), findsOneWidget);
        expect(h.calls, hasLength(1));
        expect(
          h.calls.single['action'],
          id == 'work' ? 'select_sources' : 'device_remove_source',
        );
        expect(h.calls.single['expected_revision'], 1);
        expect(h.calls.single.containsKey('device_id'), false);
        h.acknowledgement!.complete();
        // Cache pruning can finish real asynchronous I/O after the last frame.
        for (
          var attempt = 0;
          attempt < 100 && (h.google.busy || h.device.busy);
          attempt++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(h.google.busy || h.device.busy, false);
        expect(h.google.error, isNull);
        expect(h.device.errorCode, isNull);
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('imported-calendar-$id')), findsNothing);
        expect(
          find.byKey(
            ValueKey('imported-calendar-${id == 'work' ? 'family' : 'work'}'),
          ),
          findsOneWidget,
        );
        expect(find.text(longName), findsOneWidget);
        expect(
          h.calls,
          hasLength(1),
          reason: 'Removal needs no provider refresh or OS access.',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('cancel, failed deletion and retry keep confirmed rows', (
    tester,
  ) async {
    final h = (await tester.runAsync(() async => Harness()))!;
    addTearDown(() => tester.runAsync(h.dispose));
    await tester.pumpWidget(h.widget());
    await tester.pumpAndSettle();
    h.calls.clear();
    await tester.tap(
      find.byKey(const ValueKey('delete-imported-calendar-work')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(h.calls, isEmpty);
    h.fail = true;
    await tester.tap(
      find.byKey(const ValueKey('delete-imported-calendar-work')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Work'), findsOneWidget);
    expect(
      find.text('Could not delete “Work”. Refresh and try again.'),
      findsOneWidget,
    );
    h.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not delete “Work”. Refresh and try again.'),
      findsNothing,
    );
    expect(find.text('Work'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'account change while confirming cannot delete the old account import',
    (tester) async {
      final h = (await tester.runAsync(() async => Harness()))!;
      addTearDown(() => tester.runAsync(h.dispose));
      await tester.pumpWidget(h.widget());
      await tester.pumpAndSettle();
      h.calls.clear();
      await tester.tap(
        find.byKey(const ValueKey('delete-imported-calendar-work')),
      );
      await tester.pumpAndSettle();
      h.account = 'b';
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(h.calls, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final phone in [false, true]) {
    test(
      'removal preserves ${phone ? 'phone' : 'Google'} Settings draft',
      () async {
        final h = Harness();
        addTearDown(h.dispose);
        await h.google.loadStatus();
        await h.device.loadAccountStatus();
        h.calls.clear();
        h.google.choosingCalendars = true;
        h.google.selectedSourceIds = {'work', 'unselected'};
        h.device.choosing = true;
        h.device.selectedSources = {'family', 'draft-phone'};
        h.device.googleBindings = {'draft-phone': 'work'};
        final result = await (phone
            ? h.device.removeSource('family')
            : h.google.removeSource('work'));
        expect(result, true);
        expect(h.calls, hasLength(1));
        if (phone) {
          expect(h.device.choosing, true);
          expect(h.device.selectedSources, {'draft-phone'});
          expect(h.device.googleBindings, {'draft-phone': 'work'});
        } else {
          expect(h.google.choosingCalendars, true);
          expect(h.google.selectedSourceIds, {'unselected'});
        }
      },
    );
    test(
      'late ${phone ? 'phone' : 'Google'} removal response cannot publish across accounts',
      () async {
        final h = Harness();
        addTearDown(h.dispose);
        await h.google.loadStatus();
        await h.device.loadAccountStatus();
        h.calls.clear();
        h.acknowledgement = Completer<void>();
        final pending = phone
            ? h.device.removeSource('family')
            : h.google.removeSource('work');
        await Future<void>.delayed(Duration.zero);
        final competing = await (phone
            ? h.device.removeSource('family')
            : h.google.removeSource('work'));
        expect(competing, false);
        expect(h.calls, hasLength(1));
        h.account = 'b';
        h.acknowledgement!.complete();
        expect(await pending, false);
        expect(h.google.accountStatus, isNull);
        expect(h.device.accountStatus?.sources ?? [], isEmpty);
      },
    );
  }
  testWidgets('warm imports survive a failed status refresh and recover', (
    tester,
  ) async {
    final h = (await tester.runAsync(() async => Harness()))!;
    addTearDown(() => tester.runAsync(h.dispose));
    await h.google.loadStatus();
    await h.device.loadAccountStatus();
    h.failStatus = true;
    await tester.pumpWidget(h.widget());
    await tester.pumpAndSettle();
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
    expect(find.text('Could not update imported calendars.'), findsOneWidget);
    h.failStatus = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Could not update imported calendars.'), findsNothing);
    expect(find.text('Work'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('delete confirmation fits enlarged phone text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final h = (await tester.runAsync(() async => Harness()))!;
    addTearDown(() => tester.runAsync(h.dispose));
    await tester.pumpWidget(h.widget());
    await tester.pumpAndSettle();
    final remove = find.byKey(const ValueKey('delete-imported-calendar-empty'));
    await tester.scrollUntilVisible(remove, 250);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.widgetWithText(TextButton, 'Delete').hitTestable(),
      findsOneWidget,
    );
    await capture(tester, 'confirmation-portrait-2x');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'imported calendars remain usable while the authored list loads',
    (tester) async {
      final h = (await tester.runAsync(() async => Harness()))!;
      addTearDown(() => tester.runAsync(h.dispose));
      h.repo.pendingSnapshot = Completer<SharedCalendarsSnapshot>();
      await tester.pumpWidget(h.widget());
      await tester.pumpAndSettle();
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Family'), findsOneWidget);
      expect(find.text('Updating your calendars…'), findsOneWidget);
      await capture(tester, 'imports-while-authored-loading');
      expect(
        find
            .byKey(const ValueKey('delete-imported-calendar-work'))
            .hitTestable(),
        findsOneWidget,
      );
      h.repo.pendingSnapshot!.complete(
        SharedCalendarsSnapshot(
          calendars: const [],
          pendingInvites: const [],
          hiddenCalendarIds: const {},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Updating your calendars…'), findsNothing);
      expect(find.text('Work'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'route rebuilds keep the existing import owners and loaded rows',
    (tester) async {
      final h = (await tester.runAsync(() async => Harness()))!;
      addTearDown(() => tester.runAsync(h.dispose));
      await tester.pumpWidget(h.widget());
      await tester.pumpAndSettle();
      h.calls.clear();
      await tester.pumpWidget(
        h.widget(calendarRepo: FakeRepo(h.client, () => h.account)),
      );
      await tester.pumpAndSettle();
      expect(h.calls, isEmpty);
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Family'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class Harness {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  String? account = 'a';
  final selected = {'work', 'empty', 'family'};
  final calls = <Map<String, dynamic>>[];
  Completer<void>? acknowledgement;
  bool fail = false;
  bool failStatus = false;
  int revision = 1;
  late final repository = ExternalCalendarRepository(
    client,
    lane: 'staging',
    currentAccount: () => account,
    request: (body) async {
      calls.add(body);
      if (failStatus &&
          (body['action'] == 'status' || body['action'] == 'device_status')) {
        throw const ExternalCalendarFailure(code: 'unavailable');
      }
      if (body['action'] == 'select_sources' ||
          body['action'] == 'device_remove_source') {
        await acknowledgement?.future;
        if (fail) throw const ExternalCalendarFailure(code: 'stale_attempt');
        if (body['action'] == 'select_sources') {
          selected.removeAll(['work', 'empty']);
          selected.addAll(List<String>.from(body['source_ids'] as List));
        } else {
          selected.remove(body['source_id']);
        }
        revision++;
      }
      final device = (body['action'] as String).startsWith('device_');
      return {
        'available': true,
        'connection': {
          'id': device ? 'phone' : 'google',
          'status': 'paused',
          'revision': revision,
          'account_label': 'river@example.com',
        },
        'sources': device
            ? [
                for (final row in deviceStatus.sources)
                  {
                    'id': row.id,
                    'native_id': row.nativeId,
                    'label': row.label,
                    'selected':
                        selected.contains(row.id) || row.ownedBy == 'google',
                    'account_label': row.accountLabel,
                    'owned_by': row.ownedBy,
                    'google_source_id': row.googleSourceId,
                    'color': row.color,
                  },
              ]
            : [
                for (final row in googleStatus.sources)
                  {
                    'id': row.id,
                    'label': row.label,
                    'selected': selected.contains(row.id),
                    'color': row.color,
                    'imported_event_count': row.importedEventCount,
                  },
              ],
      };
    },
  );
  late final google = ExternalCalendarController(repository);
  late final device = DeviceCalendarController(
    repository: repository,
    bridge: _UnsupportedCalendarBridge(),
  );
  late final repo = FakeRepo(client, () => account);
  Widget widget({SharedCalendarsRepo? calendarRepo}) => MaterialApp(
    theme: AppTheme.dark,
    builder: (_, child) =>
        RepaintBoundary(key: const ValueKey('capture'), child: child!),
    home: Scaffold(
      body: SharedCalendarsSheet(
        repo: calendarRepo ?? repo,
        googleController: google,
        deviceController: device,
        routeMode: true,
        showCloseButton: false,
      ),
    ),
  );
  Future<void> dispose() async {
    google.dispose();
    device.dispose();
    await client.dispose();
  }
}

// Browser management must never touch an OS calendar API.
class _UnsupportedCalendarBridge implements DeviceCalendarBridge {
  @override
  bool get supported => false;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Native calendar access is unavailable');
}

class FakeRepo extends SharedCalendarsRepo {
  FakeRepo(super.client, this.account);
  final String? Function() account;
  Completer<SharedCalendarsSnapshot>? pendingSnapshot;
  @override
  String? get currentUserId => account();
  @override
  Future<SharedCalendarsSnapshot?> restoreCachedSnapshot() async => null;
  @override
  Future<SharedCalendarsSnapshot> loadSnapshot() async =>
      pendingSnapshot?.future ??
      SharedCalendarsSnapshot(
        calendars: const [],
        pendingInvites: const [],
        hiddenCalendarIds: const {},
      );
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_IMPORTED_SHEET')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('/tmp/haw-imported-sheet/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
