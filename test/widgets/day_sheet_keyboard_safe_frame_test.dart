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
}
