import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/day_view.dart';

void main() {
  group('DayViewGrid overlapping event gestures', () {
    testWidgets('a short event card can start the horizontal overlap scroll', (
      tester,
    ) async {
      await _setPhoneViewport(tester);

      await tester.pumpWidget(
        _DayViewHarness(
          notes: [
            _timedNote(
              title: 'Kung Fu Practice',
              startHour: 10,
              startMinute: 0,
              endHour: 10,
              endMinute: 30,
              flowId: 1,
            ),
            _timedNote(
              title: 'Writing Block',
              startHour: 10,
              startMinute: 0,
              endHour: 11,
              endMinute: 0,
              flowId: 2,
            ),
            _timedNote(
              title: 'Deep Work',
              startHour: 10,
              startMinute: 0,
              endHour: 12,
              endMinute: 0,
              flowId: 3,
            ),
            _timedNote(
              title: 'Fourth Event',
              startHour: 10,
              startMinute: 0,
              endHour: 13,
              endMinute: 0,
              flowId: 4,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final fourthEvent = find.text('Fourth Event');
      final before = tester.getRect(fourthEvent);
      expect(before.left, greaterThan(390));

      await tester.dragFrom(
        tester.getCenter(find.text('Kung Fu Practice')),
        const Offset(-260, 0),
      );
      await tester.pumpAndSettle();

      final after = tester.getRect(fourthEvent);
      expect(after.left, lessThan(before.left));
      expect(after.left, lessThan(390));
    });

    testWidgets(
      'a short event card inherits the tallest hit height in its overlap row',
      (tester) async {
        await _setPhoneViewport(tester);

        await tester.pumpWidget(
          _DayViewHarness(
            notes: [
              _timedNote(
                title: 'Kung Fu Practice',
                startHour: 10,
                startMinute: 0,
                endHour: 10,
                endMinute: 30,
                flowId: 1,
              ),
              _timedNote(
                title: 'Tax Day',
                startHour: 10,
                startMinute: 0,
                endHour: 13,
                endMinute: 0,
                flowId: 2,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final ancestorBoxes = tester.widgetList<SizedBox>(
          find.ancestor(
            of: find.text('Kung Fu Practice'),
            matching: find.byType(SizedBox),
          ),
        );

        expect(ancestorBoxes.any((box) => box.height == 182), isTrue);
      },
    );

    testWidgets(
      'new event preview stays single while crossing into the next hour',
      (tester) async {
        await _setPhoneViewport(tester);

        await tester.pumpWidget(const _DayViewHarness(notes: []));
        await tester.pumpAndSettle();

        final gesture = await tester.startGesture(const Offset(200, 450));
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

        expect(find.text('New Event'), findsOneWidget);
        expect(find.text('4:30 PM'), findsOneWidget);

        await gesture.moveBy(const Offset(0, 45));
        await tester.pump();

        expect(find.text('New Event'), findsOneWidget);
        expect(find.text('5:15 PM'), findsOneWidget);

        await gesture.up();
        await tester.pumpAndSettle();
      },
    );
  });

  group('DayViewGrid detail sheet refresh', () {
    testWidgets(
      'detail sheet refreshes stale event data before showing time and share actions',
      (tester) async {
        await _setPhoneViewport(tester);

        final notes = ValueNotifier<List<NoteData>>([
          _timedNote(
            title: 'Focus Block',
            startHour: 10,
            startMinute: 0,
            endHour: 11,
            endMinute: 0,
            clientEventId: 'cid-focus',
          ),
        ]);
        final dataVersion = ValueNotifier<int>(0);
        EventItem? sharedEvent;

        addTearDown(() {
          notes.dispose();
          dataVersion.dispose();
        });

        await tester.pumpWidget(
          _MutableDayViewHarness(
            notes: notes,
            dataVersion: dataVersion,
            onShareNote: (event) async {
              sharedEvent = event;
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Focus Block'));
        await tester.pumpAndSettle();

        expect(find.text('10:00 AM – 11:00 AM'), findsOneWidget);

        notes.value = [
          _timedNote(
            id: 'evt-focus',
            clientEventId: 'cid-focus',
            title: 'Focus Block',
            startHour: 13,
            startMinute: 0,
            endHour: 14,
            endMinute: 0,
          ),
        ];
        dataVersion.value++;
        await tester.pumpAndSettle();

        expect(find.text('1:00 PM – 2:00 PM'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Invite People'));
        await tester.pumpAndSettle();

        expect(sharedEvent, isNotNull);
        expect(sharedEvent!.id, 'evt-focus');
        expect(sharedEvent!.clientEventId, 'cid-focus');
        expect(sharedEvent!.startMin, 13 * 60);
        expect(sharedEvent!.endMin, 14 * 60);
      },
    );

    testWidgets(
      'detail sheet survives source grid disposal and notifier rebuilds',
      (tester) async {
        await _setPhoneViewport(tester);

        final showGrid = ValueNotifier<bool>(true);
        final dataVersion = ValueNotifier<int>(0);

        addTearDown(() {
          showGrid.dispose();
          dataVersion.dispose();
        });

        await tester.pumpWidget(
          _SheetPersistenceHarness(
            showGrid: showGrid,
            dataVersion: dataVersion,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Flow Block'));
        await tester.pumpAndSettle();

        expect(find.text('End Flow'), findsOneWidget);

        showGrid.value = false;
        await tester.pump();

        dataVersion.value++;
        await tester.pump();
        expect(tester.takeException(), isNull);

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('End Flow'), findsOneWidget);
      },
    );
  });
}

Future<void> _setPhoneViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

NoteData _timedNote({
  String? id,
  String? clientEventId,
  required String title,
  required int startHour,
  required int startMinute,
  required int endHour,
  required int endMinute,
  int? flowId,
}) {
  return NoteData(
    id: id,
    clientEventId: clientEventId,
    title: title,
    allDay: false,
    start: TimeOfDay(hour: startHour, minute: startMinute),
    end: TimeOfDay(hour: endHour, minute: endMinute),
    flowId: flowId,
  );
}

class _DayViewHarness extends StatelessWidget {
  const _DayViewHarness({required this.notes});

  final List<NoteData> notes;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: DayViewGrid(
          ky: 1,
          km: 1,
          kd: 1,
          notes: notes,
          showGregorian: false,
          flowIndex: const {
            1: FlowData(
              id: 1,
              name: 'Practice',
              color: Colors.green,
              active: true,
            ),
            2: FlowData(id: 2, name: 'Focus', color: Colors.red, active: true),
            3: FlowData(id: 3, name: 'Taxes', color: Colors.blue, active: true),
            4: FlowData(
              id: 4,
              name: 'Overflow',
              color: Colors.purple,
              active: true,
            ),
          },
          initialScrollOffset: 9 * 60,
        ),
      ),
    );
  }
}

class _MutableDayViewHarness extends StatelessWidget {
  const _MutableDayViewHarness({
    required this.notes,
    required this.dataVersion,
    this.onShareNote,
  });

  final ValueNotifier<List<NoteData>> notes;
  final ValueNotifier<int> dataVersion;
  final Future<void> Function(EventItem event)? onShareNote;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<int>(
          valueListenable: dataVersion,
          builder: (context, _, child) {
            return DayViewGrid(
              ky: 1,
              km: 1,
              kd: 1,
              notes: notes.value,
              dataVersion: dataVersion,
              showGregorian: false,
              flowIndex: const {},
              initialScrollOffset: 9 * 60,
              onShareNote: onShareNote,
              resolveCurrentEventTarget: (target) {
                for (final note in notes.value) {
                  final sameId =
                      target.event.id != null &&
                      target.event.id!.isNotEmpty &&
                      note.id == target.event.id;
                  final sameClientId =
                      target.event.clientEventId != null &&
                      target.event.clientEventId!.isNotEmpty &&
                      note.clientEventId == target.event.clientEventId;
                  if (!sameId && !sameClientId) continue;
                  return DayViewSheetEventTarget(
                    ky: target.ky,
                    km: target.km,
                    kd: target.kd,
                    event: _eventFromNote(note),
                  );
                }
                return target;
              },
            );
          },
        ),
      ),
    );
  }
}

class _SheetPersistenceHarness extends StatelessWidget {
  const _SheetPersistenceHarness({
    required this.showGrid,
    required this.dataVersion,
  });

  final ValueNotifier<bool> showGrid;
  final ValueNotifier<int> dataVersion;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: showGrid,
          builder: (context, isVisible, _) {
            if (!isVisible) {
              return const SizedBox.expand();
            }

            return DayViewGrid(
              ky: 1,
              km: 1,
              kd: 1,
              notes: [
                _timedNote(
                  title: 'Flow Block',
                  startHour: 10,
                  startMinute: 0,
                  endHour: 11,
                  endMinute: 0,
                  flowId: 1,
                ),
              ],
              dataVersion: dataVersion,
              showGregorian: false,
              flowIndex: const {
                1: FlowData(
                  id: 1,
                  name: 'Practice',
                  color: Colors.green,
                  active: true,
                ),
              },
              initialScrollOffset: 9 * 60,
            );
          },
        ),
      ),
    );
  }
}

EventItem _eventFromNote(NoteData note) {
  final startMin = (note.start?.hour ?? 9) * 60 + (note.start?.minute ?? 0);
  final endMin = (note.end?.hour ?? 17) * 60 + (note.end?.minute ?? 0);
  return EventItem(
    id: note.id,
    clientEventId: note.clientEventId,
    title: note.title,
    detail: note.detail,
    location: note.location,
    startMin: startMin,
    endMin: endMin,
    flowId: note.flowId,
    color: note.manualColor ?? Colors.blue,
    manualColor: note.manualColor,
    allDay: note.allDay,
    category: note.category,
    isReminder: note.isReminder,
    reminderId: note.reminderId,
  );
}
