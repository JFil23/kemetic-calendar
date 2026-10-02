import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/settings/external_calendar_panel.dart';
import 'package:mobile/shared/glossy_text.dart';

import '../../support/maat_flow_visual_test_fonts.dart';

const _choices = [
  ExternalCalendarChoice(
    id: 'personal',
    name: 'Personal',
    detail: 'Primary calendar',
    selected: true,
  ),
  ExternalCalendarChoice(id: 'family', name: 'Family', selected: true),
  ExternalCalendarChoice(
    id: 'holidays',
    name: 'Holidays in the United States',
    selected: false,
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
      for (final state in ExternalCalendarPanelState.values) {
        testWidgets('${state.name} fits ${viewport.key} at $scale text', (
          tester,
        ) async {
          _configureViewport(tester, viewport.value, scale);
          await tester.pumpWidget(
            _harness(
              ExternalCalendarPanel(
                state: state,
                accountLabel:
                    state == ExternalCalendarPanelState.disconnected ||
                        state == ExternalCalendarPanelState.unconfigured
                    ? null
                    : 'river@example.com',
                lastUpdatedLabel: 'today at 9:41 AM',
                calendars: _choices,
                automaticImport: state != ExternalCalendarPanelState.paused,
                onConnect: () {},
                onRefresh: () {},
                onRetry: () {},
                onChooseCalendars: () {},
                onSelectionChanged: (_, _) {},
                onSaveSelection: () {},
                onCancelSelection: () {},
                onAutomaticChanged: (_) {},
                onDisconnect: () {},
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 250));
          expect(tester.takeException(), isNull);
          expect(find.text('Calendar Import'), findsOneWidget);
          expect(find.text('Apple Calendar'), findsOneWidget);
          expect(find.text('Choose device calendars'), findsNothing);
          final panel = tester.getRect(
            find.byKey(const ValueKey('external-calendar-panel')),
          );
          expect(panel.left, 16);
          expect(panel.right, viewport.value.width - 16);
          for (final text in tester.widgetList<Text>(find.byType(Text))) {
            expect(text.maxLines, isNull, reason: text.data);
            expect(
              text.overflow,
              isNot(TextOverflow.ellipsis),
              reason: text.data,
            );
          }
          final captureName = '${state.name}-${viewport.key}-${scale.toInt()}x';
          await _capture(tester, captureName);
          await tester.ensureVisible(
            find.text('Apple Calendar import is not available in this build.'),
          );
          await tester.pump(const Duration(milliseconds: 250));
          expect(tester.takeException(), isNull);
          final appleRect = tester.getRect(
            find.text('Apple Calendar import is not available in this build.'),
          );
          expect(appleRect.bottom, lessThanOrEqualTo(viewport.value.height));
          expect(appleRect.left, greaterThanOrEqualTo(34));
          expect(appleRect.right, lessThanOrEqualTo(viewport.value.width - 34));
          if (state == ExternalCalendarPanelState.choosing ||
              state == ExternalCalendarPanelState.connected) {
            await _capture(tester, '$captureName-scrolled');
          }
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }

  testWidgets('preserves existing Settings card and action geometry', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        ExternalCalendarPanel(
          state: ExternalCalendarPanelState.disconnected,
          onConnect: () {},
        ),
      ),
    );
    final card = tester.widget<Container>(
      find.byKey(const ValueKey('external-calendar-panel')),
    );
    expect(card.padding, const EdgeInsets.all(18));
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFF0C0C0C));
    expect(decoration.borderRadius, BorderRadius.circular(20));
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.style!.backgroundColor!.resolve({}), KemeticGold.base);
    expect(button.style!.foregroundColor!.resolve({}), Colors.black);
    expect(
      tester.getSize(find.byType(ElevatedButton)).height,
      greaterThanOrEqualTo(kMinInteractiveDimension),
    );
  });

  testWidgets('selection preserves full long calendar names at enlarged text', (
    tester,
  ) async {
    _configureViewport(tester, const Size(390, 844), 2);
    await tester.pumpWidget(
      _harness(
        ExternalCalendarPanel(
          state: ExternalCalendarPanelState.choosing,
          calendars: const [
            ExternalCalendarChoice(
              id: 'long',
              name: 'Community gatherings and school volunteer commitments',
              detail: 'A shared calendar for the whole household',
              selected: true,
            ),
          ],
          onSelectionChanged: (_, _) {},
          onSaveSelection: () {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final title = tester.getRect(
      find.text('Community gatherings and school volunteer commitments'),
    );
    expect(title.height, greaterThan(60));
    expect(title.right, lessThanOrEqualTo(356));
    await _capture(tester, 'long-calendar-name-portrait-2x');
  });
  testWidgets(
    'unconfirmed selection recovery remains readable at enlarged text',
    (tester) async {
      _configureViewport(tester, const Size(390, 844), 2);
      await tester.pumpWidget(
        _harness(
          ExternalCalendarPanel(
            state: ExternalCalendarPanelState.selectionChanged,
            selectionRecoveryMessage:
                'Your calendar choices could not be confirmed. Choose your calendars again.',
            onChooseCalendars: () {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await _capture(tester, 'unconfirmed-selection-portrait-2x');
      await tester.ensureVisible(find.text('Choose calendars again'));
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _harness(Widget panel) => MaterialApp(
  theme: AppTheme.dark,
  home: RepaintBoundary(
    key: const ValueKey('external-calendar-capture'),
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: const BackButton(color: KemeticGold.base),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: panel,
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
  if (!const bool.fromEnvironment('CAPTURE_EXTERNAL_CALENDAR')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('external-calendar-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('/tmp/haw-fresh-calendar-visuals/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
