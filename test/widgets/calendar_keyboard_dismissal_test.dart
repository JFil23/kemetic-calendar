import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/calendar_floating_shortcuts.dart';
import 'package:mobile/widgets/kemetic_keyboard.dart';
import 'package:mobile/widgets/keyboard_aware.dart';
import 'package:mobile/widgets/keyboard_viewport_metrics.dart';

void main() {
  for (final size in [const Size(1180, 820), const Size(390, 844)]) {
    for (final exit in [
      'cancel',
      'failed save',
      'photo picker return',
      'rotation',
    ]) {
      testWidgets('Calendar controls return after $exit at $size', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        WebKeyboardViewportSnapshot? viewport;
        final actions = <String>[];
        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigatorKey,
            builder: (context, child) => KemeticKeyboardHost(
              viewportMetricsResolver: (media, {required hasFocusedEditable}) =>
                  KeyboardViewportMetrics.resolve(
                    media: media,
                    hasFocusedEditable: hasFocusedEditable,
                    webViewport: viewport,
                  ),
              child: child!,
            ),
            home: CalendarFloatingShortcutsLayer(
              onTodayPressed: () => actions.add('today'),
              onCalendarsPressed: () => actions.add('calendars'),
              onInboxPressed: () => actions.add('inbox'),
              child: const Scaffold(body: SizedBox.expand()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(calendarFloatingShortcutsKey), findsOneWidget);
        final fieldFocus = FocusNode();
        addTearDown(fieldFocus.dispose);
        final draft = TextEditingController();
        addTearDown(draft.dispose);
        void openEditor() => unawaited(
          showEditableModalBottomSheet<void>(
            context: navigatorKey.currentContext!,
            builder: (_) => SizedBox(
              height: 300,
              child: TextField(
                key: const ValueKey('flow-editor-field'),
                focusNode: fieldFocus,
                controller: draft,
              ),
            ),
          ),
        );
        openEditor();
        await tester.pumpAndSettle();
        final field = find.byKey(const ValueKey('flow-editor-field'));
        await tester.tap(field);
        await tester.pump();
        await tester.enterText(field, 'Retained flow draft');
        viewport = (
          height: size.height - 300,
          layoutHeight: size.height,
          offsetTop: 0,
        );
        tester.binding.handleMetricsChanged();
        await tester.pump();
        expect(fieldFocus.hasFocus, isTrue);
        expect(find.byKey(calendarFloatingShortcutsKey), findsNothing);
        expect(find.byKey(calendarFloatingTodaySurfaceKey), findsNothing);

        if (exit == 'failed save') {
          ScaffoldMessenger.of(tester.element(field)).showSnackBar(
            const SnackBar(content: Text('Save could not be confirmed')),
          );
          await tester.pump();
          expect(find.text('Save could not be confirmed'), findsOneWidget);
          expect(fieldFocus.hasFocus, isTrue);
        } else if (exit == 'photo picker return') {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          await tester.pump();
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();
          expect(fieldFocus.hasFocus, isTrue);
          expect(find.byKey(calendarFloatingShortcutsKey), findsNothing);
        } else if (exit == 'rotation') {
          final rotated = Size(size.height, size.width);
          viewport = (
            height: rotated.height - 300,
            layoutHeight: rotated.height,
            offsetTop: 0,
          );
          tester.view.physicalSize = rotated;
          await tester.pump();
          expect(fieldFocus.hasFocus, isTrue);
          expect(find.byKey(calendarFloatingShortcutsKey), findsNothing);
          expect(
            tester.getRect(field).bottom,
            lessThanOrEqualTo(viewport.height),
          );
        }

        // iOS can retain a smaller visual viewport after text editing ends,
        // including after a Photos picker or an orientation change. No new
        // Flutter metrics event is required when the editor route is removed.
        navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        expect(fieldFocus.hasFocus, isFalse);
        expect(find.byKey(calendarFloatingTodaySurfaceKey), findsOneWidget);
        expect(find.byKey(calendarFloatingShortcutsKey), findsOneWidget);
        await tester.tap(find.byKey(calendarFloatingTodayButtonKey));
        await tester.tap(find.byKey(calendarFloatingCalendarsButtonKey));
        await tester.tap(find.byKey(calendarFloatingInboxButtonKey));
        expect(actions, ['today', 'calendars', 'inbox']);

        // Reopening with the same browser snapshot must not leave the scope
        // permanently hidden or suppress valid keyboard geometry next time.
        openEditor();
        await tester.pumpAndSettle();
        expect(find.byKey(calendarFloatingShortcutsKey), findsOneWidget);
        await tester.tap(field);
        await tester.pump();
        expect(fieldFocus.hasFocus, isTrue);
        expect(draft.text, 'Retained flow draft');
        expect(find.byKey(calendarFloatingShortcutsKey), findsNothing);
        expect(
          tester.getRect(field).bottom,
          lessThanOrEqualTo(viewport.height),
        );
        navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.byKey(calendarFloatingTodaySurfaceKey), findsOneWidget);
        expect(find.byKey(calendarFloatingShortcutsKey), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
