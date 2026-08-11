import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/day_sheet_components.dart';
import 'package:mobile/widgets/keyboard_aware.dart';

void main() {
  testWidgets(
    'day sheet frame respects keyboard viewInsets and keeps fields scrollable',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final titleController = TextEditingController();
      final detailsController = TextEditingController();
      addTearDown(() {
        titleController.dispose();
        detailsController.dispose();
      });

      const keyboardInset = 320.0;
      const titleKey = ValueKey<String>('event-create-title-field');
      const detailsKey = ValueKey<String>('event-create-details-field');

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(bottom: 34),
              viewInsets: EdgeInsets.only(bottom: keyboardInset),
            ),
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              body: Align(
                alignment: Alignment.bottomCenter,
                child: DaySheetKeyboardSafeFrame(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DaySheetTextField(
                        key: titleKey,
                        controller: titleController,
                        scrollPadding: keyboardManagedTextFieldScrollPadding,
                        hint: 'Title',
                      ),
                      const SizedBox(height: 420),
                      DaySheetTextField(
                        key: detailsKey,
                        controller: detailsController,
                        scrollPadding: keyboardManagedTextFieldScrollPadding,
                        hint: 'Details (optional)',
                        minLines: 4,
                        maxLines: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final keyboardTop = 844 - keyboardInset;
      expect(
        tester.getRect(find.byKey(daySheetKeyboardSafeFrameKey)).bottom,
        lessThanOrEqualTo(keyboardTop),
      );

      await tester.tap(find.byKey(titleKey));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(titleKey)).bottom,
        lessThan(keyboardTop),
      );

      await tester.ensureVisible(find.byKey(detailsKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(detailsKey));
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.byKey(detailsKey)).bottom,
        lessThan(keyboardTop),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('live data rebuild preserves draft tab and scroll position', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final dataVersion = ValueNotifier<int>(0);
    final controller = TextEditingController();
    addTearDown(() {
      dataVersion.dispose();
      controller.dispose();
    });

    await tester.pumpWidget(
      _LiveDaySheetHarness(dataVersion: dataVersion, controller: controller),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('live-draft')),
      'unfinished note',
    );
    await tester.tap(find.byKey(const ValueKey('live-tab-toggle')));
    await tester.pump();
    await tester.drag(
      find.byKey(daySheetKeyboardSafeScrollViewKey),
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();
    final scrollable = find
        .descendant(
          of: find.byKey(daySheetKeyboardSafeScrollViewKey),
          matching: find.byType(Scrollable),
        )
        .first;
    final before = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(before, greaterThan(0));

    dataVersion.value = 1;
    await tester.pump();

    expect(controller.text, 'unfinished note');
    expect(find.text('Reminders'), findsOneWidget);
    expect(find.text('server row 1'), findsOneWidget);
    final after = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(after, closeTo(before, 0.01));
    expect(tester.takeException(), isNull);
  });
}

class _LiveDaySheetHarness extends StatelessWidget {
  const _LiveDaySheetHarness({
    required this.dataVersion,
    required this.controller,
  });

  final ValueNotifier<int> dataVersion;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    var remindersSelected = false;
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: DaySheetLiveDataBuilder(
            key: const ValueKey('calendar-day-sheet-live-content'),
            dataVersion: dataVersion,
            builder: (context, setSheetState) => DaySheetKeyboardSafeFrame(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    key: const ValueKey('live-tab-toggle'),
                    onPressed: () => setSheetState(
                      () => remindersSelected = !remindersSelected,
                    ),
                    child: Text(remindersSelected ? 'Reminders' : 'Notes'),
                  ),
                  TextField(
                    key: const ValueKey('live-draft'),
                    controller: controller,
                  ),
                  Text('server row ${dataVersion.value}'),
                  const SizedBox(height: 900),
                  const Text('bottom'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
