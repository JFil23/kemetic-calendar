import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/day_view.dart';

void main() {
  group('DayViewGrid overlapping event gestures', () {
    testWidgets(
      'a short event card can start the horizontal overlap scroll',
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
      },
    );

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

        expect(
          ancestorBoxes.any((box) => box.height == 182),
          isTrue,
        );
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
  required String title,
  required int startHour,
  required int startMinute,
  required int endHour,
  required int endMinute,
  required int flowId,
}) {
  return NoteData(
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
            2: FlowData(
              id: 2,
              name: 'Focus',
              color: Colors.red,
              active: true,
            ),
            3: FlowData(
              id: 3,
              name: 'Taxes',
              color: Colors.blue,
              active: true,
            ),
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
