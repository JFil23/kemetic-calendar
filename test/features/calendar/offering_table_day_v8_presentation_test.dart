import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/presentation/instrument_event_presentation_frame.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_day_contract.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_day_instrument.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_day_state.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_day_v8_presentation.dart';

import '../../support/maat_flow_visual_goldens.dart';

const _viewport = Size(390, 844);
final _clock = DateTime(2026, 9, 4, 7, 15);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the v8 contract accounts for all thirty authored days and moves', () {
    expect(kOfferingTableDayViewContracts, hasLength(30));
    expect(
      kOfferingTableDayViewContracts
          .expand((contract) => contract.moves)
          .length,
      90,
    );
    for (var index = 0; index < 30; index++) {
      final contract = kOfferingTableDayViewContracts[index];
      expect(contract.day, index + 1);
      expect(contract.title.trim(), isNotEmpty, reason: 'day ${index + 1}');
      expect(contract.prompt.trim(), isNotEmpty, reason: 'day ${index + 1}');
      expect(
        contract.orientation.trim(),
        isNotEmpty,
        reason: 'day ${index + 1}',
      );
      expect(
        contract.instruction.trim(),
        isNotEmpty,
        reason: 'day ${index + 1}',
      );
      expect(contract.context.trim(), isNotEmpty, reason: 'day ${index + 1}');
      expect(contract.moves, isNotEmpty, reason: 'day ${index + 1}');
    }
    expect(
      offeringTableDayViewContract(30).moves.map((move) => move.id),
      <String>[
        'truth1',
        'truth2',
        'truth3',
        'truth4',
        'truth5',
        'shortfall',
        'surprise',
        'drink',
        'breath',
        'share',
      ],
    );
  });

  testWidgets('all thirty days use one fixed hero and one shared scroll owner', (
    tester,
  ) async {
    for (final contract in kOfferingTableDayViewContracts) {
      await _pumpPresentation(tester, contract: contract);

      final frame = tester.widget<InstrumentEventPresentationFrame>(
        find.byType(InstrumentEventPresentationFrame),
      );
      expect(
        frame.initialLowerSheetPeek,
        isNull,
        reason: 'day ${contract.day}',
      );
      expect(frame.fixedHeroHeight, isNull, reason: 'day ${contract.day}');
      expect(frame.fixedInstrumentHeight, 420, reason: 'day ${contract.day}');
      expect(frame.instrumentFooterHeight, 0, reason: 'day ${contract.day}');
      expect(
        find.byKey(const ValueKey<String>('offering-table-fixed-hero')),
        findsOneWidget,
        reason: 'day ${contract.day}',
      );
      expect(
        find.byKey(
          ValueKey<String>(
            'offering-table-day-${contract.day.toString().padLeft(2, '0')}-instrument',
          ),
        ),
        findsOneWidget,
        reason: 'day ${contract.day}',
      );
      expect(
        find.byKey(const ValueKey<String>('offering-table-presentation-body')),
        findsOneWidget,
        reason: 'day ${contract.day}',
      );
      for (final move in contract.moves) {
        expect(
          find.byKey(
            ValueKey<String>(
              'offering-table-day-${contract.day.toString().padLeft(2, '0')}-move-${move.id}',
            ),
          ),
          findsOneWidget,
          reason: 'day ${contract.day}, move ${move.id}',
        );
      }
      expect(tester.takeException(), isNull, reason: 'day ${contract.day}');
    }
  });

  testWidgets('mapped fields and action state drive the day instrument', (
    tester,
  ) async {
    final saves = <OfferingTableDayViewState>[];
    final contract = offeringTableDayViewContract(8);
    await _pumpPresentation(
      tester,
      contract: contract,
      presentationHeight: 700,
      onSave: (state) async => saves.add(state),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('offering-table-day-08-move-portion')),
    );
    final hunger = find.byKey(
      const ValueKey<String>('offering-table-field-hunger'),
    );
    await tester.ensureVisible(hunger);
    await tester.enterText(hunger, 'quiet');
    await tester.pump(const Duration(milliseconds: 400));

    expect(saves, isNotEmpty);
    expect(saves.last.words['hunger'], 'quiet');
    expect(saves.last.actions['portion'], isTrue);
    expect(saves.last.actions['schedule'], isNot(isTrue));
    expect(saves.last.dayComplete(contract, now: _clock), isTrue);
    expect(
      tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .any((paint) => paint.painter is OfferingTableDayInstrumentPainter),
      isTrue,
    );
  });

  test('the authored alternate completion rules remain exact', () {
    final day8 = offeringTableDayViewContract(8);
    final hungerOnly = OfferingTableDayViewState(
      words: <String, String>{'hunger': 'quiet'},
    );
    expect(hungerOnly.dayComplete(day8, now: _clock), isFalse);
    hungerOnly.actions['schedule'] = true;
    expect(hungerOnly.dayComplete(day8, now: _clock), isTrue);

    final day23 = offeringTableDayViewContract(23);
    final delayed = OfferingTableDayViewState(
      words: <String, String>{'delayed': 'reply'},
      actions: <String, bool>{'truth': true},
    );
    expect(delayed.dayComplete(day23, now: _clock), isTrue);
    delayed.actions['truth'] = false;
    expect(delayed.dayComplete(day23, now: _clock), isFalse);
  });

  test('all thirty day-state transitions satisfy their authored moves', () {
    for (final contract in kOfferingTableDayViewContracts) {
      final state = OfferingTableDayViewState();
      for (final move in contract.moves) {
        switch (move.kind) {
          case OfferingTableMoveKind.name:
            state.words[move.slot ?? move.id] = 'authored value';
          case OfferingTableMoveKind.pick:
            state.picks[move.id] = move.options.first;
          case OfferingTableMoveKind.timer:
            state.timers[move.id] = OfferingTableTimerState(
              elapsedMilliseconds: move.completeUnderTarget
                  ? 1000
                  : (move.targetSeconds ?? 0) * 1000,
            );
          case OfferingTableMoveKind.tap:
          case OfferingTableMoveKind.drink:
          case OfferingTableMoveKind.truth:
            state.actions[move.id] = true;
        }
        expect(
          state.moveDone(move, now: _clock),
          isTrue,
          reason: 'day ${contract.day}, move ${move.id}',
        );
      }
      expect(
        state.dayComplete(contract, now: _clock),
        isTrue,
        reason: 'day ${contract.day}',
      );
    }
  });

  testWidgets('reduced motion preserves the full static presentation', (
    tester,
  ) async {
    await _pumpPresentation(
      tester,
      contract: offeringTableDayViewContract(30),
      mediaQueryData: const MediaQueryData(disableAnimations: true),
    );
    expect(
      find.byKey(const ValueKey<String>('offering-table-practice-returned')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('all thirty blank instruments match the contact sheet', (
    tester,
  ) async {
    await _loadFonts();
    const size = Size(780, 2100);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: const ValueKey<String>(
            'offering-table-instrument-contact-sheet',
          ),
          child: ColoredBox(
            color: const Color(0xFF080604),
            child: Wrap(
              children: <Widget>[
                for (final contract in kOfferingTableDayViewContracts)
                  SizedBox(
                    width: 260,
                    height: 210,
                    child: Column(
                      children: <Widget>[
                        const SizedBox(height: 8),
                        Text(
                          'DAY ${contract.day.toString().padLeft(2, '0')} · ${contract.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFC99A3D),
                            fontFamily: 'GentiumPlus',
                            fontSize: 11,
                            letterSpacing: .5,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: OfferingTableDayInstrument(
                              contract: contract,
                              state: OfferingTableDayViewState(),
                              now: _clock,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byKey(
        const ValueKey<String>('offering-table-instrument-contact-sheet'),
      ),
      matchesGoldenFile(
        '$maatFlowVisualGoldenRoot/offering-table-day-v8-instruments-30-780x2100.png',
      ),
    );
  });

  testWidgets('all thirty completed instruments match the contact sheet', (
    tester,
  ) async {
    await _loadFonts();
    const size = Size(780, 2100);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final states = <int, OfferingTableDayViewState>{
      for (final contract in kOfferingTableDayViewContracts)
        contract.day: _completedState(contract),
    };

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: const ValueKey<String>(
            'offering-table-instrument-complete-contact-sheet',
          ),
          child: ColoredBox(
            color: const Color(0xFF080604),
            child: Wrap(
              children: <Widget>[
                for (final contract in kOfferingTableDayViewContracts)
                  SizedBox(
                    width: 260,
                    height: 210,
                    child: Column(
                      children: <Widget>[
                        const SizedBox(height: 8),
                        Text(
                          'DAY ${contract.day.toString().padLeft(2, '0')} · ${contract.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFC99A3D),
                            fontFamily: 'GentiumPlus',
                            fontSize: 11,
                            letterSpacing: .5,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: OfferingTableDayInstrument(
                              contract: contract,
                              state: states[contract.day]!,
                              now: _clock,
                              courseStates: states,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byKey(
        const ValueKey<String>(
          'offering-table-instrument-complete-contact-sheet',
        ),
      ),
      matchesGoldenFile(
        '$maatFlowVisualGoldenRoot/offering-table-day-v8-instruments-30-complete-780x2100.png',
      ),
    );
  });
}

OfferingTableDayViewState _completedState(OfferingTableDayContract contract) {
  final state = OfferingTableDayViewState();
  for (final move in contract.moves) {
    if (contract.day == 8 && move.id == 'schedule') continue;
    switch (move.kind) {
      case OfferingTableMoveKind.name:
        state.words[move.slot ?? move.id] =
            move.fieldLabel?.toLowerCase() ?? 'authored value';
      case OfferingTableMoveKind.pick:
        state.picks[move.id] = move.options.first;
      case OfferingTableMoveKind.timer:
        state.timers[move.id] = OfferingTableTimerState(
          elapsedMilliseconds: move.completeUnderTarget
              ? 1000
              : (move.targetSeconds ?? 0) * 1000,
        );
      case OfferingTableMoveKind.tap:
      case OfferingTableMoveKind.drink:
      case OfferingTableMoveKind.truth:
        state.actions[move.id] = true;
    }
  }
  return state;
}

Future<void> _pumpPresentation(
  WidgetTester tester, {
  required OfferingTableDayContract contract,
  Future<void> Function(OfferingTableDayViewState state)? onSave,
  MediaQueryData mediaQueryData = const MediaQueryData(),
  double presentationHeight = 470,
}) async {
  tester.view.physicalSize = _viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: mediaQueryData.copyWith(size: _viewport),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: 370,
              height: presentationHeight,
              child: OfferingTableDayV8Presentation(
                contract: contract,
                localDate: DateTime(
                  2026,
                  9,
                  4,
                ).add(Duration(days: contract.day - 1)),
                startMinute: 7 * 60 + 30,
                initialState: OfferingTableDayViewState(),
                completionPanel: const SizedBox(
                  height: 40,
                  child: Text('Observed · Partly · Skipped'),
                ),
                onSaveState: onSave ?? (_) async {},
                clock: () => _clock,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _loadFonts() async {
  final gentium = FontLoader('GentiumPlus')
    ..addFont(rootBundle.load('ios/Runner/Fonts/GentiumPlus-Regular.ttf'));
  final cormorant = FontLoader(
    'CormorantGaramond',
  )..addFont(rootBundle.load('ios/Runner/Fonts/CormorantGaramond-Regular.ttf'));
  await Future.wait(<Future<void>>[gentium.load(), cormorant.load()]);
}
