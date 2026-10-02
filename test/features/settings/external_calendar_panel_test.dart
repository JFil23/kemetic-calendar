import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/settings/external_calendar_panel.dart';

void main() {
  testWidgets('connect and retry dispatch only their own explicit callbacks', (
    tester,
  ) async {
    var connections = 0;
    var retries = 0;
    await tester.pumpWidget(
      _harness(
        ExternalCalendarPanel(
          state: ExternalCalendarPanelState.disconnected,
          onConnect: () => connections++,
          onRetry: () => retries++,
        ),
      ),
    );
    expect(connections, 0);
    await tester.tap(find.text('Connect Google Calendar'));
    expect(connections, 1);
    expect(retries, 0);
    await tester.pumpWidget(
      _harness(
        ExternalCalendarPanel(
          state: ExternalCalendarPanelState.offline,
          onConnect: () => connections++,
          onRetry: () => retries++,
        ),
      ),
    );
    expect(
      find.textContaining('Your saved events remain available.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    expect(connections, 1);
    expect(retries, 1);
  });

  testWidgets('selection is controlled and cannot save an empty choice', (
    tester,
  ) async {
    String? changedId;
    bool? changedSelection;
    var saves = 0;
    await tester.pumpWidget(
      _harness(
        ExternalCalendarPanel(
          state: ExternalCalendarPanelState.choosing,
          calendars: const [
            ExternalCalendarChoice(
              id: 'one',
              name: 'Personal',
              selected: false,
            ),
          ],
          onSelectionChanged: (id, selected) {
            changedId = id;
            changedSelection = selected;
          },
          onSaveSelection: () => saves++,
        ),
      ),
    );
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
    await tester.tap(find.text('Personal'));
    expect(changedId, 'one');
    expect(changedSelection, isTrue);
    expect(saves, 0);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
      reason: 'Account owner must acknowledge or supply new selection.',
    );
  });

  testWidgets('refreshing disables parallel changes and disconnect', (
    tester,
  ) async {
    var changes = 0;
    await tester.pumpWidget(
      _harness(
        ExternalCalendarPanel(
          state: ExternalCalendarPanelState.refreshing,
          onRefresh: () => changes++,
          onChooseCalendars: () => changes++,
          onDisconnect: () => changes++,
          onAutomaticChanged: (_) => changes++,
        ),
      ),
    );
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    for (final button in tester.widgetList<OutlinedButton>(
      find.byType(OutlinedButton),
    )) {
      expect(button.onPressed, isNull);
    }
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNull,
    );
    expect(changes, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'automatic setting delegates change without claiming persistence',
    (tester) async {
      bool? requested;
      await tester.pumpWidget(
        _harness(
          ExternalCalendarPanel(
            state: ExternalCalendarPanelState.paused,
            automaticImport: false,
            onAutomaticChanged: (value) => requested = value,
          ),
        ),
      );
      expect(
        find.textContaining('Keeps your selected calendars up to date.'),
        findsOneWidget,
      );
      await tester.tap(find.byType(Switch));
      expect(requested, isTrue);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
    },
  );

  testWidgets(
    'unconfigured and unavailable Apple states make no false promises',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          const ExternalCalendarPanel(
            state: ExternalCalendarPanelState.unconfigured,
          ),
        ),
      );
      expect(
        find.text('Google Calendar connection is not available yet.'),
        findsOneWidget,
      );
      expect(
        find.text('Apple Calendar import is not available in this build.'),
        findsOneWidget,
      );
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.text('Choose device calendars'), findsNothing);
    },
  );

  testWidgets('Apple action requires explicit verified native capability', (
    tester,
  ) async {
    var imports = 0;
    await tester.pumpWidget(
      _harness(
        ExternalCalendarPanel(
          state: ExternalCalendarPanelState.unconfigured,
          appleImportAvailable: true,
          onAppleImport: () => imports++,
        ),
      ),
    );
    expect(imports, 0);
    await tester.tap(find.text('Choose device calendars'));
    expect(imports, 1);
  });
}

Widget _harness(Widget panel) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(body: SingleChildScrollView(child: panel)),
);
