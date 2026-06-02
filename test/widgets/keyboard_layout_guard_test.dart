import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('keyboard layout guard', () {
    test('flow post comments sheet uses managed text field padding', () {
      final source = File(
        'lib/features/profile/flow_post_engagement_row.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('final keyboardInset = keyboardInsetOf(context);'),
      );
      expect(
        source,
        contains('scrollPadding: keyboardManagedTextFieldScrollPadding'),
      );
      expect(source, isNot(contains('keyboardAwareTextFieldScrollPadding')));
      expect(source, isNot(contains('FractionallySizedBox')));
    });

    test('flow studio avoids stacked scaffold and manual keyboard padding', () {
      final source = File(
        'lib/features/calendar/calendar_flow_studio_page.dart',
      ).readAsStringSync();

      expect(source, contains('final bodyPadding = EdgeInsets.fromLTRB('));
      expect(source, contains('AppBottomInsets.contentBottomPadding(context)'));
      expect(
        source,
        contains('body: ListView(\n        padding: bodyPadding,'),
      );
      expect(source, contains('resizeToAvoidBottomInset: true'));
      expect(
        source,
        contains(
          'const fieldScrollPadding = keyboardManagedTextFieldScrollPadding;',
        ),
      );
      expect(source, isNot(contains('addKeyboardBottomInset')));
      expect(
        source,
        isNot(contains('keyboardAwareTextFieldScrollPadding(context)')),
      );
    });

    test('today planner avoids stacked keyboard reveal and padding', () {
      final source = File(
        'lib/features/rhythm/pages/todays_alignment_page.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('KemeticKeyboardRevealScope(enabled: false, child: content)'),
      );
      expect(source, contains('final listBottomPadding = embedded'));
      expect(source, contains('? bottomPaddingAboveGlobalMenu(context, 32)'));
      expect(source, contains(': 32.0'));
      expect(
        source,
        contains('scrollPadding: keyboardManagedTextFieldScrollPadding'),
      );
      expect(source, isNot(contains('keyboardAwareTextFieldScrollPadding')));
      expect(
        source,
        isNot(contains('+\n            keyboardInsetOf(context)')),
      );
    });

    test(
      'production fields do not use legacy keyboard-aware scroll padding',
      () {
        final violations = _dartSourcesUnder('lib')
            .where((file) => file.path != 'lib/widgets/keyboard_aware.dart')
            .where(
              (file) => file.readAsStringSync().contains(
                'keyboardAwareTextFieldScrollPadding',
              ),
            )
            .map((file) => file.path)
            .toList();

        expect(violations, isEmpty);
      },
    );

    test('production surfaces do not add keyboard inset to scroll padding', () {
      final violations = _dartSourcesUnder('lib')
          .where((file) => file.path != 'lib/widgets/keyboard_aware.dart')
          .where(
            (file) =>
                file.readAsStringSync().contains('addKeyboardBottomInset'),
          )
          .map((file) => file.path)
          .toList();

      expect(violations, isEmpty);
    });
  });
}

Iterable<File> _dartSourcesUnder(String root) {
  return Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
}
