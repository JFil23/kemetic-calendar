import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('universal keyboard architecture guard', () {
    test('raw viewport insets have exactly two production authorities', () {
      final owners =
          _dartSourcesUnder('lib')
              .where((file) => file.readAsStringSync().contains('viewInsets'))
              .map((file) => file.path)
              .toList()
            ..sort();

      expect(
        owners,
        equals(<String>[
          'lib/widgets/kemetic_keyboard.dart',
          'lib/widgets/keyboard_viewport_metrics.dart',
        ]),
      );
    });

    test('root host publishes geometry without rewriting MediaQuery', () {
      final source = File(
        'lib/widgets/kemetic_keyboard.dart',
      ).readAsStringSync();

      expect(source, contains('KemeticKeyboardScope('));
      expect(source, contains('visibleBottom: visibleBottom'));
      expect(source, isNot(contains('copyWith(viewInsets:')));
      expect(source, isNot(contains('effectiveViewInsets')));
      expect(source, isNot(contains('child: MediaQuery(')));
    });

    test('root host never performs app-wide focus scrolling', () {
      final source = File(
        'lib/widgets/kemetic_keyboard.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('Scrollable.ensureVisible')));
      expect(source, isNot(contains('Scrollable.maybeOf')));
      expect(source, isNot(contains('.animateTo(')));
      expect(source, isNot(contains('.jumpTo(')));
      expect(source, isNot(contains('_scheduleCustomKeyboardReveal')));
      expect(source, isNot(contains('_scheduleMultilineCaretReveal')));
      expect(source, isNot(contains('_revealFocusedEditable')));
    });

    test(
      'system input commands exist only for deliberate keyboard switching',
      () {
        final owners = <String>[];
        for (final file in _dartSourcesUnder('lib')) {
          if (file.readAsStringSync().contains('SystemChannels.textInput')) {
            owners.add(file.path);
          }
        }

        expect(owners, equals(<String>['lib/widgets/kemetic_keyboard.dart']));
        final source = File(owners.single).readAsStringSync();
        expect(
          RegExp(r"SystemChannels\.textInput").allMatches(source),
          hasLength(3),
        );
        expect(RegExp(r"TextInput\.hide").allMatches(source), hasLength(2));
        expect(RegExp(r"TextInput\.show").allMatches(source), hasLength(1));
        expect(source, contains('Future<void> _openCustomKeyboard()'));
        expect(source, contains('void _closeCustomAndRestoreSystem()'));
      },
    );

    test('ordinary material fields use Flutter scroll-padding defaults', () {
      final source = _dartSourcesUnder(
        'lib',
      ).map((file) => file.readAsStringSync()).join('\n');

      expect(source, isNot(contains('scrollPadding:')));
      expect(source, isNot(contains('keyboardManagedTextFieldScrollPadding')));
      expect(source, isNot(contains('fieldScrollPadding')));
      expect(source, isNot(contains('reminderFieldScrollPadding')));
    });

    test('one shared surface owns scoped focus correction', () {
      final owners = <String>[];
      for (final file in _dartSourcesUnder('lib')) {
        final source = file.readAsStringSync();
        if (source.contains('class KeyboardAwareEditableSurface')) {
          owners.add(file.path);
        }
      }

      expect(owners, equals(<String>['lib/widgets/keyboard_aware.dart']));
      final source = File(owners.single).readAsStringSync();
      expect(source, contains('FocusManager.instance.addListener'));
      expect(source, contains('Scrollable.maybeOf(focusedContext)'));
      expect(source, contains('position.jumpTo(target)'));
      expect(source, contains('if (!_customKeyboardIsVisible) return;'));
      expect(source, isNot(contains('TextEditingController')));
      expect(source, isNot(contains('EditableTextState')));
      expect(source, isNot(contains('SystemChannels.textInput')));
    });

    test('representative editable routes consume the shared surface', () {
      const paths = <String>[
        'lib/widgets/utility_sheet_route_scaffold.dart',
        'lib/widgets/day_sheet_components.dart',
        'lib/features/calendar/calendar_flow_studio_page.dart',
        'lib/features/calendar/the_reading_house/presentation/'
            'reading_house_detail_page.dart',
        'lib/features/calendar/the_reading_house/presentation/'
            'reading_house_sitting_editor.dart',
        'lib/features/nodes/node_link_picker_sheet.dart',
        'lib/features/profile/edit_profile_page.dart',
        'lib/features/profile/profile_search_page.dart',
        'lib/features/sharing/share_flow_sheet.dart',
      ];

      for (final path in paths) {
        expect(
          File(path).readAsStringSync(),
          contains('KeyboardAwareEditableSurface('),
          reason: path,
        );
      }
    });

    test('legacy keyboard bandaids cannot return', () {
      final source = _dartSourcesUnder(
        'lib',
      ).map((file) => file.readAsStringSync()).join('\n');

      expect(source, isNot(contains('KemeticKeyboardRevealScope')));
      expect(source, isNot(contains('KeyboardSafeViewport')));
      expect(source, isNot(contains('KemeticKeyboardViewportScope')));
      expect(source, isNot(contains('addKeyboardBottomInset')));
    });
  });
}

Iterable<File> _dartSourcesUnder(String root) {
  return Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
}
