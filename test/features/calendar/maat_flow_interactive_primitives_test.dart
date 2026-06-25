import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/maat_flow_interactive_primitives.dart';
import 'package:mobile/features/calendar/maat_flow_response_models.dart';

void main() {
  testWidgets('enrollment input enforces the 280 character limit', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(
        FlowEnrollmentInputField(
          controller: controller,
          label: 'Name one thing',
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'a' * 320);
    await tester.pump();

    expect(controller.text.length, kFlowEnrollmentInputMaxCharacters);
    expect(controller.text, 'a' * kFlowEnrollmentInputMaxCharacters);
  });

  testWidgets(
    'enrollment input is a single-sentence field, not a journal box',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          FlowEnrollmentInputField(
            controller: controller,
            hintText: 'One sentence',
          ),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLines, 1);
      expect(field.minLines, 1);
      expect(field.maxLength, kFlowEnrollmentInputMaxCharacters);
      expect(field.textInputAction, TextInputAction.done);
      expect(field.keyboardType, TextInputType.text);
      expect(
        field.inputFormatters,
        contains(isA<LengthLimitingTextInputFormatter>()),
      );
      expect(field.decoration?.counterText, '');
    },
  );

  testWidgets('carry banner renders quiet label/value and hides empty values', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const FlowCarryBanner(label: 'Carry', value: 'one clear act')),
    );

    expect(find.text('Carry'), findsOneWidget);
    expect(find.text('one clear act'), findsOneWidget);
    expect(find.byIcon(Icons.warning), findsNothing);
    expect(find.byIcon(Icons.error), findsNothing);

    final label = tester.widget<Text>(find.text('Carry'));
    final value = tester.widget<Text>(find.text('one clear act'));
    expect(label.style?.fontSize, lessThan(value.style?.fontSize ?? 0));
    expect(value.style?.fontWeight, isNot(FontWeight.w800));

    await tester.pumpWidget(_wrap(const FlowCarryBanner(value: null)));
    expect(find.text('Carrying'), findsNothing);

    await tester.pumpWidget(_wrap(const FlowCarryBanner(value: '   ')));
    expect(find.text('Carrying'), findsNothing);

    await tester.pumpWidget(_wrap(const FlowCarryBanner(value: 'skipped')));
    expect(find.text('Carrying'), findsNothing);
  });

  testWidgets('tap completion panel pulses only after successful write', (
    tester,
  ) async {
    final order = <String>[];
    final saveCompleter = Completer<FlowTapCompletionResult>();

    await tester.pumpWidget(
      _wrap(
        FlowTapCompletionPanel(
          currentStatus: CompletionStatus.none,
          onSave: (status) async {
            order.add('save:${status.wireName}:start');
            final result = await saveCompleter.future;
            order.add('save:end');
            return result;
          },
          onCanonicalCompletionPulse: (status) {
            order.add('pulse:${status.wireName}');
          },
        ),
      ),
    );

    await tester.tap(find.text('Observed'));
    await tester.pump();

    expect(order, <String>['save:observed:start']);

    saveCompleter.complete(const FlowTapCompletionResult.saved());
    await tester.pumpAndSettle();

    expect(order, <String>[
      'save:observed:start',
      'save:end',
      'pulse:observed',
    ]);
  });

  testWidgets(
    'tap completion panel does not pulse on failure, load, rebuild, or unchanged state',
    (tester) async {
      final savedStatuses = <CompletionStatus>[];
      final pulses = <CompletionStatus>[];

      await tester.pumpWidget(
        _wrap(
          FlowTapCompletionPanel(
            currentStatus: CompletionStatus.observed,
            onSave: (status) async {
              savedStatuses.add(status);
              return const FlowTapCompletionResult.saved();
            },
            onCanonicalCompletionPulse: pulses.add,
          ),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(
        _wrap(
          FlowTapCompletionPanel(
            currentStatus: CompletionStatus.observed,
            onSave: (status) async {
              savedStatuses.add(status);
              return const FlowTapCompletionResult.saved();
            },
            onCanonicalCompletionPulse: pulses.add,
          ),
        ),
      );
      await tester.pump();

      expect(pulses, isEmpty);

      await tester.tap(find.text('Observed'));
      await tester.pumpAndSettle();

      expect(savedStatuses, isEmpty);
      expect(pulses, isEmpty);

      await tester.tap(find.text('Partly'));
      await tester.pumpAndSettle();

      expect(savedStatuses, <CompletionStatus>[CompletionStatus.partial]);
      expect(pulses, <CompletionStatus>[CompletionStatus.partial]);
    },
  );

  testWidgets(
    'tap completion panel does not pulse on failed write, missing prerequisite, loading, or unchanged result',
    (tester) async {
      final savedStatuses = <CompletionStatus>[];
      final pulses = <CompletionStatus>[];

      await tester.pumpWidget(
        _wrap(
          FlowTapCompletionPanel(
            currentStatus: CompletionStatus.none,
            onSave: (status) async {
              savedStatuses.add(status);
              return const FlowTapCompletionResult.failed();
            },
            onCanonicalCompletionPulse: pulses.add,
          ),
        ),
      );

      await tester.tap(find.text('Observed'));
      await tester.pumpAndSettle();

      expect(savedStatuses, <CompletionStatus>[CompletionStatus.observed]);
      expect(pulses, isEmpty);

      savedStatuses.clear();
      await tester.pumpWidget(
        _wrap(
          FlowTapCompletionPanel(
            currentStatus: CompletionStatus.none,
            canSave: (_) async => false,
            onSave: (status) async {
              savedStatuses.add(status);
              return const FlowTapCompletionResult.saved();
            },
            onCanonicalCompletionPulse: pulses.add,
          ),
        ),
      );

      await tester.tap(find.text('Observed'));
      await tester.pumpAndSettle();

      expect(savedStatuses, isEmpty);
      expect(pulses, isEmpty);

      await tester.pumpWidget(
        _wrap(
          FlowTapCompletionPanel(
            currentStatus: CompletionStatus.none,
            loading: true,
            onSave: (status) async {
              savedStatuses.add(status);
              return const FlowTapCompletionResult.saved();
            },
            onCanonicalCompletionPulse: pulses.add,
          ),
        ),
      );

      await tester.tap(find.text('Observed'));
      await tester.pumpAndSettle();

      expect(savedStatuses, isEmpty);
      expect(pulses, isEmpty);

      await tester.pumpWidget(
        _wrap(
          FlowTapCompletionPanel(
            currentStatus: CompletionStatus.none,
            onSave: (status) async {
              savedStatuses.add(status);
              return const FlowTapCompletionResult.unchanged();
            },
            onCanonicalCompletionPulse: pulses.add,
          ),
        ),
      );

      await tester.tap(find.text('Observed'));
      await tester.pumpAndSettle();

      expect(savedStatuses, <CompletionStatus>[CompletionStatus.observed]);
      expect(pulses, isEmpty);
    },
  );

  testWidgets('tracked item list stays compact and local-only', (tester) async {
    final changed = <String>[];

    await tester.pumpWidget(
      _wrap(
        FlowTrackedItemList(
          items: const <FlowTrackedItem>[
            FlowTrackedItem(
              id: 'name',
              label: 'Return to the name',
              detail: 'Day 7',
            ),
          ],
          onChanged: (item) => changed.add(item.id),
        ),
      ),
    );

    expect(find.text('Return to the name'), findsOneWidget);
    expect(find.text('Day 7'), findsOneWidget);

    final label = tester.widget<Text>(find.text('Return to the name'));
    expect(label.maxLines, 1);
    expect(label.overflow, TextOverflow.ellipsis);

    await tester.tap(find.text('Return to the name'));
    await tester.pump();
    expect(changed, <String>['name']);
  });

  testWidgets('response section renders nothing for empty specs', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const MaatFlowResponseSection(specs: <MaatFlowResponseSpec>[])),
    );

    expect(find.byKey(kMaatFlowResponseSectionKey), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('response section supports fixture text and choice specs', (
    tester,
  ) async {
    final changes = <MaatFlowResponseValue>[];

    await tester.pumpWidget(
      _wrap(
        MaatFlowResponseSection(
          specs: const <MaatFlowResponseSpec>[
            MaatFlowResponseSpec(
              id: 'note',
              flowKey: 'fixture-flow',
              surface: MaatFlowResponseSurface.calendarSheet,
              kind: MaatFlowResponseKind.multiline,
              label: 'Note',
              placeholder: 'Write one line',
            ),
            MaatFlowResponseSpec(
              id: 'state',
              flowKey: 'fixture-flow',
              surface: MaatFlowResponseSurface.calendarSheet,
              kind: MaatFlowResponseKind.choice,
              label: 'State',
              options: <MaatFlowResponseOption>[
                MaatFlowResponseOption(id: 'inside', label: 'Inside'),
                MaatFlowResponseOption(id: 'outside', label: 'Outside'),
              ],
            ),
          ],
          onChanged: changes.add,
        ),
      ),
    );

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);
    expect(find.text('State'), findsOneWidget);

    await tester.enterText(
      find.byKey(maatFlowResponseFieldKey('note')),
      'A clear response.',
    );
    await tester.pump();
    await tester.tap(find.byKey(maatFlowResponseFieldKey('state:inside')));
    await tester.pump();

    expect(changes, hasLength(2));
    expect(changes.first.specId, 'note');
    expect(changes.first.text, 'A clear response.');
    expect(changes.last.specId, 'state');
    expect(changes.last.optionIds, <String>['inside']);
  });

  test('interactive primitives avoid obvious sensitive-output hooks', () {
    final source = File(
      'lib/features/calendar/maat_flow_interactive_primitives.dart',
    ).readAsStringSync();

    for (final forbidden in <String>[
      'Events.',
      'trackIfAuthed',
      'debugPrint',
      'print(',
      'Supabase',
      'UserEventsRepo',
      'GoRouter',
      'Notification',
      'notification',
      'shareFlow',
      'deepLink',
      'deep link',
      'Uri(',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test(
    'interactive primitives import without circular feature dependencies',
    () {
      final source = File(
        'lib/features/calendar/maat_flow_interactive_primitives.dart',
      ).readAsStringSync();
      final imports = RegExp(
        r"^import '([^']+)';",
        multiLine: true,
      ).allMatches(source).map((match) => match.group(1)!).toList();

      expect(imports, contains('package:flutter/material.dart'));
      expect(imports, contains('package:flutter/services.dart'));
      expect(imports, contains('package:mobile/core/completion_status.dart'));
      expect(imports, contains('calendar_completion.dart'));
      expect(imports, contains('maat_flow_response_models.dart'));
      expect(imports, isNot(contains('calendar_page.dart')));
      expect(imports, isNot(contains('day_view.dart')));
      expect(imports, isNot(contains('calendar_maat_flows.dart')));
    },
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: const Color(0xFF101010),
      body: Center(child: SizedBox(width: 360, child: child)),
    ),
  );
}
