import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/settings/device_calendar_panel.dart';
import 'package:mobile/shared/glossy_text.dart';

import '../../support/maat_flow_visual_test_fonts.dart';

const _choices = [
  DeviceCalendarChoice(
    id: 'one',
    name: 'Personal',
    sourceId: 'a',
    sourceName: 'iCloud',
    selected: true,
  ),
  DeviceCalendarChoice(
    id: 'two',
    name: 'Family',
    sourceId: 'a',
    sourceName: 'iCloud',
    selected: false,
  ),
  DeviceCalendarChoice(
    id: 'three',
    name: 'Work',
    sourceId: 'b',
    sourceName: 'river@example.com',
    selected: true,
    cloudSourceId: 'google-work',
  ),
];
const _cloud = [
  DeviceCalendarCloudChoice(
    id: 'google-work',
    name: 'Work',
    accountLabel: 'river@example.com',
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadMaatFlowVisualTestFonts);
  for (final viewport in <String, Size>{
    'portrait': const Size(390, 844),
    'landscape': const Size(844, 390),
  }.entries) {
    for (final scale in [1.0, 2.0]) {
      for (final state in DeviceCalendarPanelState.values) {
        testWidgets('${state.name} fits ${viewport.key} at $scale text', (
          tester,
        ) async {
          _configureViewport(tester, viewport.value, scale);
          await tester.pumpWidget(
            _harness(
              DeviceCalendarPanel(
                state: state,
                calendars: _choices,
                cloudCalendars: _cloud,
                lastUpdatedLabel: 'today at 9:41 AM',
                automaticImport: state != DeviceCalendarPanelState.paused,
                onConnect: () {},
                onRefresh: () {},
                onRetry: () {},
                onChooseCalendars: () {},
                onSelectionChanged: (_, _) {},
                onCloudBindingChanged: (_, _) {},
                onSaveSelection: () {},
                onCancelSelection: () {},
                onAutomaticChanged: (_) {},
                onDisconnect: () {},
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 250));
          expect(tester.takeException(), isNull);
          final panel = tester.getRect(
            find.byKey(const ValueKey('device-calendar-panel')),
          );
          expect(panel.left, 16);
          expect(panel.right, viewport.value.width - 16);
          final name = '${state.name}-${viewport.key}-${scale.toInt()}x';
          await _capture(tester, name);
          if (state == DeviceCalendarPanelState.choosing) {
            await tester.ensureVisible(find.text('Cancel'));
            await tester.pump(const Duration(milliseconds: 250));
            expect(tester.takeException(), isNull);
            final cancel = tester.getRect(find.text('Cancel'));
            expect(cancel.bottom, lessThanOrEqualTo(viewport.value.height));
            await _capture(tester, '$name-scrolled');
          }
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }

  testWidgets('selection starts empty and never infers provider from names', (
    tester,
  ) async {
    String? requested;
    await tester.pumpWidget(
      _harness(
        DeviceCalendarPanel(
          state: DeviceCalendarPanelState.choosing,
          calendars: const [
            DeviceCalendarChoice(
              id: 'one',
              name: 'Google Plans',
              sourceId: 'a',
              sourceName: 'A personal label',
              selected: false,
            ),
          ],
          cloudCalendars: _cloud,
          onSelectionChanged: (id, selected) {
            if (selected) requested = id;
          },
          onSaveSelection: () {},
        ),
      ),
    );
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    expect(
      find.byKey(const ValueKey('device-calendar-owner-one')),
      findsNothing,
    );
    await tester.tap(find.text('Google Plans'));
    expect(requested, 'one');
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
  });

  testWidgets('ownership choice explicitly delegates cloud binding', (
    tester,
  ) async {
    String? selectedId;
    String? cloudId;
    await tester.pumpWidget(
      _harness(
        DeviceCalendarPanel(
          state: DeviceCalendarPanelState.choosing,
          calendars: const [
            DeviceCalendarChoice(
              id: 'one',
              name: 'Personal',
              sourceId: 'a',
              sourceName: 'Device source',
              selected: true,
            ),
          ],
          cloudCalendars: _cloud,
          onSelectionChanged: (_, _) {},
          onCloudBindingChanged: (id, cloud) {
            selectedId = id;
            cloudId = cloud;
          },
        ),
      ),
    );
    await tester.tap(find.text('Import from this device'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Google · Work · river@example.com').last);
    await tester.pumpAndSettle();
    expect(selectedId, 'one');
    expect(cloudId, 'google-work');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'permission is requested only through the explicit recovery action',
    (tester) async {
      var requests = 0;
      await tester.pumpWidget(
        _harness(
          DeviceCalendarPanel(
            state: DeviceCalendarPanelState.permissionRequired,
            onConnect: () => requests++,
          ),
        ),
      );
      expect(requests, 0);
      expect(
        find.textContaining('Your saved events remain available.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Allow calendar access'));
      expect(requests, 1);
    },
  );

  testWidgets('ownership control fits long cloud labels with enlarged text', (
    tester,
  ) async {
    _configureViewport(tester, const Size(390, 844), 2);
    await tester.pumpWidget(
      _harness(
        DeviceCalendarPanel(
          state: DeviceCalendarPanelState.choosing,
          calendars: const [
            DeviceCalendarChoice(
              id: 'one',
              name: 'Community gatherings and family commitments',
              sourceId: 'a',
              sourceName: 'Shared household calendar',
              selected: true,
              cloudSourceId: 'google-work',
            ),
          ],
          cloudCalendars: const [
            DeviceCalendarCloudChoice(
              id: 'google-work',
              name: 'Community gatherings and family commitments',
              accountLabel: 'river@example.com',
            ),
          ],
          onCloudBindingChanged: (_, _) {},
          onSaveSelection: () {},
        ),
      ),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('device-calendar-owner-one')),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await _capture(tester, 'long-cloud-label-portrait-2x');
  });
  testWidgets(
    'removed Google connection requires an explicit new import owner',
    (tester) async {
      _configureViewport(tester, const Size(390, 844), 1);
      await tester.pumpWidget(
        _harness(
          DeviceCalendarPanel(
            state: DeviceCalendarPanelState.choosing,
            calendars: const [
              DeviceCalendarChoice(
                id: 'one',
                name: 'Work',
                sourceId: 'a',
                sourceName: 'Device account',
                selected: true,
                ownershipPending: true,
              ),
            ],
            onCloudBindingChanged: (_, _) {},
            onSaveSelection: () {},
          ),
        ),
      );
      expect(find.text('Choose import source'), findsOneWidget);
      expect(find.text('Import from this device'), findsNothing);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      await _capture(tester, 'ownership-pending-portrait-1x');
    },
  );

  testWidgets(
    'another device offers explicit ownership transfer without automatic takeover',
    (tester) async {
      var requests = 0;
      _configureViewport(tester, const Size(390, 844), 2);
      await tester.pumpWidget(
        _harness(
          DeviceCalendarPanel(
            state: DeviceCalendarPanelState.unavailable,
            availabilityMessage:
                'Your device calendars are managed by another device.',
            onUseThisDevice: () => requests++,
          ),
        ),
      );
      expect(requests, 0);
      await _capture(tester, 'another-device-portrait-2x');
      await tester.ensureVisible(find.text('Use this device'));
      await tester.tap(find.text('Use this device'));
      expect(requests, 1);
    },
  );
  testWidgets(
    'unavailable selected source stays visible and can be explicitly removed',
    (tester) async {
      bool? requested;
      await tester.pumpWidget(
        _harness(
          DeviceCalendarPanel(
            state: DeviceCalendarPanelState.choosing,
            calendars: const [
              DeviceCalendarChoice(
                id: 'one',
                name: 'Old work calendar',
                sourceId: 'a',
                sourceName: 'Device account',
                selected: true,
                available: false,
              ),
            ],
            onSelectionChanged: (_, selected) => requested = selected,
          ),
        ),
      );
      expect(find.text('Not available on this device'), findsOneWidget);
      await tester.tap(find.text('Old work calendar'));
      expect(requested, isFalse);
    },
  );
}

Widget _harness(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: RepaintBoundary(
    key: const ValueKey('device-calendar-capture'),
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: const BackButton(color: KemeticGold.base),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: child,
      ),
    ),
  ),
);

void _configureViewport(WidgetTester tester, Size size, double scale) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_DEVICE_CALENDAR')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('device-calendar-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('/tmp/haw-fresh-device-calendar-visuals/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
