import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('universal keyboard architecture guard', () {
    test('raw viewInsets stay in resolver and publisher, not extra owners', () {
      final owners =
          _dartSourcesUnder('lib')
              .where(
                (file) =>
                    file.readAsStringSync().contains('media.viewInsets.bottom'),
              )
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

    test('editable modal routes consume remaining occlusion once', () {
      final source = File('lib/widgets/keyboard_aware.dart').readAsStringSync();

      expect(source, contains('showEditableModalBottomSheet<T>'));
      expect(source, contains('showEditableDialog<T>'));
      expect(source, contains('class KeyboardInsetBoundary'));
      expect(source, contains('remainingSystemKeyboardInsetOf'));
      expect(source, contains('remainingCustomKeyboardInsetOf'));
      expect(source, contains('math.max(remainingSystem, remainingCustom)'));
      expect(source, contains('media.removeViewInsets(removeBottom: true)'));
      expect(source, isNot(contains('if (editable)')));
      expect(
        RegExp(r'class KeyboardInsetBoundary').allMatches(source),
        hasLength(1),
      );
    });

    test('instrument host receives constrained geometry without inset math', () {
      final source = File(
        'lib/features/calendar/presentation/instrument_event_presentation_frame.dart',
      ).readAsStringSync();
      final host = source
          .split('class InstrumentEventSheetHost')
          .last
          .split('class InstrumentEventSheetGeometry')
          .first;
      expect(host, isNot(contains('editable')));
      expect(host, isNot(contains('KeyboardInsetConsumption.apply')));
      expect(host, isNot(contains('remainingSystemKeyboardInsetOf')));
      expect(host, isNot(contains('remainingCustomKeyboardInsetOf')));
      expect(host, isNot(contains('keyboardInsetOf')));
      expect(host, contains('KeyboardAwareEditableSurface('));

      final route = source
          .split('Future<T?> showCalendarEventDetailSheetModal<T>')
          .last
          .split('class CalendarEventDetailSheetCoordinator')
          .first;
      expect(route, contains('showEditableModalBottomSheet<T>'));
      expect(route, isNot(contains('editable')));
    });

    test('Kꜣr capture uses the shared boundary instead of a local strip', () {
      final source = File(
        'lib/features/calendar/the_kar/presentation/kar_day_behavior_surface.dart',
      ).readAsStringSync();
      expect(source, contains('KeyboardInsetBoundary('));
      expect(source, isNot(contains('removeViewInsets')));
    });

    test('root host publishes geometry without rewriting MediaQuery', () {
      final source = File(
        'lib/widgets/kemetic_keyboard.dart',
      ).readAsStringSync();

      expect(source, contains('KemeticKeyboardScope('));
      expect(source, contains('visibleBottom: visibleBottom'));
      expect(source, isNot(contains('final double keyboardInset;')));
      expect(source, isNot(contains('keyboardInset: effectiveKeyboardInset')));
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

    test('Offering Day V8 does not scroll before requesting focus', () {
      final source = File(
        'lib/features/calendar/the_offering_table/presentation/'
        'offering_table_day_v8_presentation.dart',
      ).readAsStringSync();
      final focusWord = source
          .split('void _focusWord(String id)')
          .last
          .split('void _resetDay()')
          .first;

      expect(focusWord, isNot(contains('Scrollable.ensureVisible')));
      expect(focusWord, contains('_wordFocusNodes[id]?.requestFocus()'));
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

    test('Day Sheet does not reserve a second keyboard clearance band', () {
      final source = File(
        'lib/widgets/day_sheet_components.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('scrollBottomPadding')));
      expect(source, contains('KeyboardAwareEditableSurface('));
    });

    test('keyboard regressions do not pre-scroll focused fields in tests', () {
      const paths = <String>[
        'test/widgets/day_sheet_keyboard_safe_frame_test.dart',
        'test/features/calendar/authored_event_block_day_view_test.dart',
        'test/features/calendar/offering_table_detail_page_test.dart',
      ];

      for (final path in paths) {
        final source = File(path).readAsStringSync();
        expect(
          source,
          isNot(contains('tester.ensureVisible(field)')),
          reason: path,
        );
      }
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
      final surface = File(
        owners.single,
      ).readAsStringSync().split('class KeyboardAwareEditableSurface').last;
      expect(surface, contains('FocusManager.instance.addListener'));
      expect(surface, contains('Scrollable.maybeOf(focusedContext)'));
      expect(surface, contains('position.jumpTo(target)'));
      expect(surface, contains('if (!_customKeyboardIsVisible) return;'));
      expect(surface, isNot(contains('TextEditingController')));
      expect(surface, isNot(contains('EditableTextState')));
      expect(surface, isNot(contains('SystemChannels.textInput')));
      expect(surface, isNot(contains('manageSystemKeyboardInset')));
      expect(
        surface,
        isNot(contains('remainingSystemKeyboardInsetOf(context)')),
      );
    });

    test('all named editable route families consume the shared surface', () {
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
        'lib/features/calendar/the_offering_table/presentation/'
            'offering_table_preview_day_sheet.dart',
        'lib/features/calendar/the_offering_table/presentation/'
            'offering_table_detail_page.dart',
        'lib/features/calendar/the_kar/presentation/'
            'kar_day_behavior_surface.dart',
        'lib/features/journal/journal_overlay.dart',
        'lib/features/calendar/day_view.dart',
      ];

      for (final path in paths) {
        expect(
          File(path).readAsStringSync(),
          contains('KeyboardAwareEditableSurface('),
          reason: path,
        );
      }
    });

    test('all named editable modal families use the shared route boundary', () {
      const paths = <String>[
        'lib/features/calendar/the_reading_house/presentation/'
            'reading_house_detail_page.dart',
        'lib/features/calendar/the_reading_house/presentation/'
            'reading_house_sitting_editor.dart',
        'lib/features/nodes/node_link_picker_sheet.dart',
        'lib/features/nodes/node_user_insights_section.dart',
        'lib/features/calendars/shared_calendars_sheet.dart',
        'lib/features/shared_practice/shared_practice_completion_sheet.dart',
        'lib/features/profile/flow_post_engagement_row.dart',
        'lib/features/inbox/presentation/reading_house_room_sheet.dart',
        'lib/features/calendar/follow_the_sky/presentation/widgets/'
            'follow_sky_turning_sheet.dart',
        'lib/features/calendar/calendar_page.dart',
        'lib/features/calendar/calendar_flow_pages.dart',
        'lib/features/calendar/calendar_flow_studio_page.dart',
        'lib/features/calendar/presentation/'
            'instrument_event_presentation_frame.dart',
        'lib/features/calendar/the_offering_table/presentation/'
            'offering_table_preview_day_sheet.dart',
      ];

      for (final path in paths) {
        final source = File(path).readAsStringSync();
        expect(source, contains('showEditableModalBottomSheet'), reason: path);
        expect(
          source,
          isNot(contains('manageSystemKeyboardInset')),
          reason: path,
        );
      }
    });

    test('all named editable dialog families use the shared boundary', () {
      const paths = <String>[
        'lib/features/calendars/shared_calendars_sheet.dart',
        'lib/features/calendar/calendar_page.dart',
        'lib/features/profile/profile_page.dart',
        'lib/features/rhythm/pages/todays_alignment_page.dart',
      ];

      for (final path in paths) {
        expect(
          File(path).readAsStringSync(),
          contains('showEditableDialog'),
          reason: path,
        );
      }
    });

    test('feature code cannot own keyboard inset arithmetic', () {
      final offenders = <String>[];
      for (final file in _dartSourcesUnder('lib')) {
        if (file.path == 'lib/widgets/keyboard_aware.dart') continue;
        final source = file.readAsStringSync();
        if (source.contains('keyboardInsetOf(') ||
            source.contains('remainingSystemKeyboardInsetOf(') ||
            source.contains('remainingCustomKeyboardInsetOf(') ||
            source.contains('KeyboardInsetConsumption.apply(')) {
          offenders.add(file.path);
        }
      }
      expect(offenders, isEmpty);
    });

    test(
      'removed system-inset switches and test scroll cheats stay absent',
      () {
        final production = _dartSourcesUnder(
          'lib',
        ).map((file) => file.readAsStringSync()).join('\n');
        expect(production, isNot(contains('manageSystemKeyboardInset')));
        expect(production, isNot(contains('keyboardInsetOf(')));
        expect(production, isNot(contains('final double keyboardInset;')));

        final offeringDetail = File(
          'test/features/calendar/offering_table_detail_page_test.dart',
        ).readAsStringSync();
        final offeringAfterKeyboard = offeringDetail
            .split(
              'tester.view.viewInsets = const FakeViewPadding(bottom: 300);',
            )
            .last
            .split("testWidgets(")
            .first;
        expect(offeringAfterKeyboard, isNot(contains('ensureVisible(field)')));

        final readingHouse = File(
          'test/features/calendar/reading_house_detail_page_test.dart',
        ).readAsStringSync();
        final readingKeyboardCase = readingHouse
            .split(
              "tester.view.viewInsets = const FakeViewPadding(bottom: 300)",
            )
            .last
            .split("tester.view.viewInsets = FakeViewPadding.zero")
            .first;
        expect(readingKeyboardCase, isNot(contains('ensureVisible(hostNote)')));
      },
    );

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
