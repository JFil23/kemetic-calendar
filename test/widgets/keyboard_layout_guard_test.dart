import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('keyboard layout guard', () {
    test('flow post comments use one direct keyboard inset', () {
      final source = File(
        'lib/features/profile/flow_post_engagement_row.dart',
      ).readAsStringSync();

      expect(source, contains('final keyboardInset = media.viewInsets.bottom'));
      expect(
        source,
        contains('final heightFactor = keyboardInset > 0 ? 0.72 : 0.46'),
      );
      expect(
        source,
        contains('padding: EdgeInsets.only(bottom: keyboardInset)'),
      );
      expect(
        source,
        contains('scrollPadding: keyboardManagedTextFieldScrollPadding'),
      );
      expect(source, isNot(contains('AnimatedPadding(')));
      expect(source, isNot(contains('KeyboardSafeViewport(')));
    });

    test('embedded flow studio lets the day sheet own keyboard resizing', () {
      final source = File(
        'lib/features/calendar/calendar_flow_studio_page.dart',
      ).readAsStringSync();
      final calendarSource = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();

      expect(source, contains('final bodyPadding = EdgeInsets.fromLTRB('));
      expect(source, contains('AppBottomInsets.contentBottomPadding(context)'));
      expect(
        source,
        contains('body: ListView(\n        padding: bodyPadding,'),
      );
      expect(
        source,
        contains('resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset'),
      );
      expect(
        calendarSource,
        contains('resizeToAvoidBottomInset: persistOverlay'),
      );
      expect(source, isNot(contains('KeyboardSafeViewport(')));
      expect(
        source,
        contains('manageKeyboardInset: widget.resizeToAvoidBottomInset'),
      );
      expect(
        source,
        contains(
          'const fieldScrollPadding = keyboardManagedTextFieldScrollPadding;',
        ),
      );
      expect(source, isNot(contains('AnimatedPadding(')));
    });

    test('route-backed editors leave resizing to the utility sheet', () {
      final calendarSource = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final journalRouteSource = File('lib/main.dart').readAsStringSync();
      final journalSource = File(
        'lib/features/journal/journal_overlay.dart',
      ).readAsStringSync();

      expect(calendarSource, contains('resizeToAvoidBottomInset: false'));
      expect(journalRouteSource, contains('resizeToAvoidBottomInset: false'));
      expect(
        journalSource,
        contains('resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset'),
      );
    });

    test('day sheet repeats the planner scaffold and scroll approach', () {
      final source = File(
        'lib/widgets/day_sheet_components.dart',
      ).readAsStringSync();

      expect(source, contains('child: Scaffold('));
      expect(source, contains('resizeToAvoidBottomInset: true'));
      expect(source, contains('SingleChildScrollView('));
      expect(source, isNot(contains('return KeyboardSafeViewport(')));
    });

    test('quick add settles before focus and has one direct keyboard lift', () {
      final source = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final start = source.indexOf('class _QuickAddSheetState');
      final end = source.indexOf('enum MonthExpansionLevel', start);
      final quickAdd = source.substring(start, end);

      expect(quickAdd, contains('MediaQuery.viewInsetsOf(context).bottom'));
      expect(quickAdd, contains('autofocus: false'));
      expect(quickAdd, isNot(contains('_requestInitialFocus')));
      expect(quickAdd, isNot(contains('requestFocus()')));
      expect(quickAdd, isNot(contains('KeyboardSafeViewport(')));
      expect(quickAdd, isNot(contains('AnimatedPadding(')));
    });

    test('modal text editors wait for an explicit user focus', () {
      final calendarSource = File(
        'lib/features/calendars/shared_calendars_sheet.dart',
      ).readAsStringSync();
      final birthdayEditor = calendarSource.substring(
        calendarSource.indexOf('class _BirthdayEditorDialogState'),
        calendarSource.indexOf('class _CalendarEditorResult'),
      );
      final calendarEditor = calendarSource.substring(
        calendarSource.indexOf('class _CalendarEditorDialogState'),
      );

      final rhythmSource = File(
        'lib/features/rhythm/pages/todays_alignment_page.dart',
      ).readAsStringSync();
      final noteEditor = rhythmSource.substring(
        rhythmSource.indexOf('  Future<void> _editNote('),
        rhythmSource.indexOf('  Future<void> _deleteNote('),
      );

      for (final editor in [birthdayEditor, calendarEditor, noteEditor]) {
        expect(editor, contains('autofocus: false'));
        expect(editor, isNot(contains('autofocus: true')));
      }
    });

    test('editor sheets use direct non-animated keyboard ownership', () {
      const directInsetFiles = <String>[
        'lib/features/ai_generation/ai_flow_generation_modal.dart',
        'lib/features/calendar/calendar_flow_studio_page.dart',
        'lib/features/calendar/day_view.dart',
        'lib/features/calendar/reading_house_authoring_page.dart',
        'lib/features/nodes/node_link_picker_sheet.dart',
        'lib/features/nodes/node_user_insights_section.dart',
        'lib/features/profile/flow_post_engagement_row.dart',
        'lib/features/shared_practice/shared_practice_completion_sheet.dart',
        'lib/features/sharing/share_flow_sheet.dart',
      ];

      for (final path in directInsetFiles) {
        final source = File(path).readAsStringSync();
        expect(
          source.contains('viewInsets') || source.contains('keyboardInsetOf'),
          isTrue,
          reason: path,
        );
        expect(source, isNot(contains('KeyboardSafeViewport')), reason: path);
        expect(source, isNot(contains('AnimatedPadding(')), reason: path);
      }

      final calendarSource = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final dialogStart = calendarSource.indexOf(
        'Future<bool> _openCalendarScopedNoteDialog',
      );
      final dialogEnd = calendarSource.indexOf(
        'String? _normalizeCalendarId',
        dialogStart,
      );
      final scopedNoteDialog = calendarSource.substring(dialogStart, dialogEnd);
      expect(scopedNoteDialog, contains('return Dialog('));
      expect(scopedNoteDialog, isNot(contains('KeyboardSafeViewport')));
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

    test('material text fields repeat the shared scroll-padding approach', () {
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

    test('production has no field-level reveal scopes or legacy viewport', () {
      final source = _dartSourcesUnder(
        'lib',
      ).map((file) => file.readAsStringSync()).join('\n');

      expect(source, isNot(contains('KemeticKeyboardRevealScope')));
      expect(source, isNot(contains('keyboardAwareTextFieldScrollPadding')));
      expect(source, isNot(contains('addKeyboardBottomInset')));
      expect(source, isNot(contains('KeyboardSafeViewport')));
      expect(source, isNot(contains('KemeticKeyboardViewportScope')));
    });

    test('global host routes system edits only to multiline caret reveal', () {
      final source = File(
        'lib/widgets/kemetic_keyboard.dart',
      ).readAsStringSync();

      expect(source, contains('if (!textChanged && selectionChanged)'));
      expect(source, contains('if (textChanged || selectionChanged)'));
      expect(source, contains('_scheduleMultilineCaretReveal();'));
      expect(source, isNot(contains('_handleEditableValueChanged')));
      expect(source, isNot(contains('_syncEditableValueListener')));
    });

    test('global keyboard host never reveals in response to text changes', () {
      final source = File(
        'lib/widgets/kemetic_keyboard.dart',
      ).readAsStringSync();
      final innerCaretReveal = source.substring(
        source.indexOf('void _revealMultilineCaretInsideEditable()'),
        source.indexOf('void _revealFocusedEditableForCustomKeyboard()'),
      );

      expect(
        source,
        contains(
          'if (textChanged || selectionChanged) {\n'
          '      _scheduleMultilineCaretReveal();',
        ),
      );
      expect(
        innerCaretReveal,
        contains('final position = renderEditable.offset;'),
      );
      expect(innerCaretReveal, isNot(contains('Scrollable.maybeOf')));
      expect(innerCaretReveal, isNot(contains('animateTo')));
    });

    test('global host leaves system reveal to EditableText', () {
      final source = File(
        'lib/widgets/kemetic_keyboard.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('Scrollable.ensureVisible')));
      expect(source, isNot(contains('Duration(milliseconds: 140)')));
      expect(RegExp(r'\.animateTo\(').allMatches(source), hasLength(1));
      expect(source, contains('_scheduleCustomKeyboardReveal'));
      expect(source, contains('if (!_controller.shouldShowPanel) return;'));
      expect(source, contains('_scheduleMultilineCaretReveal'));
      expect(source, contains('position.jumpTo(targetPixels)'));
    });

    test('Follow Sky scroll shell has no keyboard ownership', () {
      final source = File(
        'lib/features/calendar/follow_the_sky/presentation/widgets/'
        'follow_sky_scroll_shell.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('keyboardInsetOf')));
      expect(source, isNot(contains('_restingHeroHeight')));
      expect(source, isNot(contains('viewInsets')));
    });

    test('Follow Sky reuses the Quick Add text-field positioning contract', () {
      final calendarSource = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final quickAddStart = calendarSource.indexOf('class _QuickAddSheetState');
      final quickAddEnd = calendarSource.indexOf(
        'enum MonthExpansionLevel',
        quickAddStart,
      );
      final quickAdd = calendarSource.substring(quickAddStart, quickAddEnd);

      final detailSource = File(
        'lib/features/calendar/follow_the_sky/presentation/'
        'follow_sky_detail_page.dart',
      ).readAsStringSync();
      final exampleSource = File(
        'lib/features/calendar/follow_the_sky/presentation/widgets/'
        'follow_sky_turning_example.dart',
      ).readAsStringSync();
      final mainSource = File('lib/main.dart').readAsStringSync();
      final metricsSource = File(
        'lib/widgets/keyboard_viewport_metrics.dart',
      ).readAsStringSync();

      // Quick Add ownership: one direct MediaQuery lift, no autofocus/requestFocus.
      expect(quickAdd, contains('MediaQuery.viewInsetsOf(context).bottom'));
      expect(quickAdd, contains('autofocus: false'));
      expect(quickAdd, isNot(contains('requestFocus()')));
      expect(quickAdd, isNot(contains('KeyboardSafeViewport(')));
      expect(quickAdd, isNot(contains('AnimatedPadding(')));

      // Follow Sky copies that same outer-container ownership.
      expect(
        detailSource,
        contains('final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;'),
      );
      expect(
        detailSource,
        contains('padding: EdgeInsets.only(bottom: keyboardInset)'),
      );
      expect(detailSource, contains('resizeToAvoidBottomInset: false'));
      expect(detailSource, isNot(contains('KeyboardSafeViewport(')));
      expect(detailSource, isNot(contains('AnimatedPadding(')));
      expect(detailSource, isNot(contains('ensureVisible')));

      // Field stays on the shared 20px scroll padding; no accessory/reveal math.
      expect(
        exampleSource,
        contains('scrollPadding: keyboardManagedTextFieldScrollPadding'),
      );
      expect(exampleSource, contains('autofocus: false'));
      expect(exampleSource, isNot(contains('requestFocus()')));
      expect(exampleSource, isNot(contains('_systemKeyboardAccessoryClearance')));
      expect(exampleSource, isNot(contains('copyWith(')));
      expect(exampleSource, isNot(contains('KeyboardSafeViewport(')));
      expect(exampleSource, isNot(contains('AnimatedPadding(')));

      // Floating Kemetic toggle stays above global overlays; layout-sized web
      // occlusions are published into viewInsets for Quick Add + the toggle.
      expect(
        mainSource,
        contains(
          'child: KemeticKeyboardHost(\n'
          '          child: _GlobalOverlayShell(',
        ),
      );
      expect(metricsSource, contains('bottomOcclusion'));
      expect(
        metricsSource,
        contains(
          'layoutViewInsetBottom: math.max(mediaInset, bottomOcclusion)',
        ),
      );
    });
  });
}

Iterable<File> _dartSourcesUnder(String root) {
  return Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
}
