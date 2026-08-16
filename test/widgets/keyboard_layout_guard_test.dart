import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('keyboard layout guard', () {
    test(
      'flow post comments sheet uses the shared viewport and field rule',
      () {
        final source = File(
          'lib/features/profile/flow_post_engagement_row.dart',
        ).readAsStringSync();

        expect(source, contains('return KeyboardSafeViewport('));
        expect(source, contains('closedHeightFactor: 0.46'));
        expect(source, contains('openHeightFactor: 0.72'));
        expect(
          source,
          contains('scrollPadding: keyboardManagedTextFieldScrollPadding'),
        );
        expect(source, isNot(contains('AnimatedPadding(')));
        expect(source, isNot(contains('FractionallySizedBox')));
      },
    );

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
      expect(source, contains('return KeyboardSafeViewport('));
      expect(
        source,
        contains(
          'const fieldScrollPadding = keyboardManagedTextFieldScrollPadding;',
        ),
      );
      expect(source, isNot(contains('AnimatedPadding(')));
    });

    test('today planner lets the surrounding viewport own keyboard geometry', () {
      final source = File(
        'lib/features/rhythm/pages/todays_alignment_page.dart',
      ).readAsStringSync();

      expect(source, contains('child: content'));
      expect(
        source,
        contains(
          'final listBottomPadding = bottomPaddingAboveGlobalChrome(context, 32);',
        ),
      );
      expect(source, contains('bottomPadding: listBottomPadding'));
      expect(source, isNot(contains('effectiveListBottomPadding')));
      expect(source, isNot(contains('KemeticKeyboardRevealScope')));
      expect(
        source,
        contains('scrollPadding: keyboardManagedTextFieldScrollPadding'),
      );
    });

    test('every production material text field uses the universal padding', () {
      final violations = <String>[];
      for (final file in _dartSourcesUnder('lib')) {
        final source = file.readAsStringSync();
        final fieldCount = RegExp(
          r'\b(?:TextField|TextFormField)\s*\(',
        ).allMatches(source).length;
        if (fieldCount == 0) continue;
        final managedPaddingCount = RegExp(
          r'scrollPadding:\s*(?:keyboardManagedTextFieldScrollPadding|fieldScrollPadding|reminderFieldScrollPadding|scrollPadding)',
        ).allMatches(source).length;
        if (managedPaddingCount < fieldCount) {
          violations.add(
            '${file.path}: $fieldCount fields, '
            '$managedPaddingCount managed paddings',
          );
        }
      }

      expect(violations, isEmpty);
    });

    test(
      'production has no field-level reveal scopes or legacy inset helpers',
      () {
        final source = _dartSourcesUnder(
          'lib',
        ).map((file) => file.readAsStringSync()).join('\n');

        expect(source, isNot(contains('KemeticKeyboardRevealScope')));
        expect(source, isNot(contains('keyboardAwareTextFieldScrollPadding')));
        expect(source, isNot(contains('addKeyboardBottomInset')));
      },
    );

    test('global keyboard host never reveals in response to text changes', () {
      final source = File(
        'lib/widgets/kemetic_keyboard.dart',
      ).readAsStringSync();

      expect(source, contains('KemeticKeyboardViewportScope.isManagedFor'));
      expect(source, contains('if (textChanged || !selectionChanged) return;'));
      expect(source, isNot(contains('_handleEditableValueChanged')));
      expect(source, isNot(contains('_syncEditableValueListener')));
    });
  });
}

Iterable<File> _dartSourcesUnder(String root) {
  return Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
}
