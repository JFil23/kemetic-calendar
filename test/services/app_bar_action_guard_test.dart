import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> _ensureSupabaseInitialized() async {
  try {
    Supabase.instance.client;
    return;
  } catch (_) {}

  await Supabase.initialize(
    url: 'https://example.supabase.co',
    anonKey: 'anon-key-0123456789012345678901234567890123456789',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await _ensureSupabaseInitialized();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('app bar action guard', () {
    testWidgets('detached menu buttons close and dispatch in every path', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final navigations = <String>[];
      final launchedSheets = <String>[];
      var closeCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CalendarPage.buildDetachedActionsMenuPanel(
                context,
                includeNewNote: true,
                onNavigate: navigations.add,
                onOpenCalendars: () async => launchedSheets.add('Calendars'),
                onOpenFlowStudio: () async => launchedSheets.add('Flow Studio'),
                onOpenNewNote: () async => launchedSheets.add('New note'),
                closeMenu: () async {
                  closeCount += 1;
                },
              ),
            ),
          ),
        ),
      );

      const expectedRoutes = <String, String>{
        'Journal': '/journal',
        'Planner': '/rhythm/today',
        'Inbox': '/inbox',
        'Reflections': '/reflections',
        'Library': '/nodes',
        'Settings': '/settings',
        'Home': '/',
      };

      for (final entry in expectedRoutes.entries) {
        await tester.tap(find.text(entry.key));
        await tester.pump();
        expect(
          navigations.last,
          entry.value,
          reason: '${entry.key} should route to ${entry.value}',
        );
      }
      expect(navigations, expectedRoutes.values.toList(growable: false));

      const sheetActions = <String>['Calendars', 'Flow Studio', 'New note'];
      for (final label in sheetActions) {
        await tester.tap(find.text(label));
        await tester.pump();
        expect(
          launchedSheets.last,
          label,
          reason: '$label should dispatch its sheet/action callback',
        );
      }

      expect(closeCount, expectedRoutes.length + sheetActions.length);
      expect(launchedSheets, sheetActions);
    });

    testWidgets('detached Home dispatches before close animation completes', (
      tester,
    ) async {
      final navigations = <String>[];
      var closeStarted = false;
      final closeCompleter = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CalendarPage.buildDetachedActionsMenuPanel(
                context,
                includeNewNote: false,
                onNavigate: navigations.add,
                closeMenu: () async {
                  closeStarted = true;
                  await closeCompleter.future;
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Home'));
      await tester.pump();

      expect(navigations, <String>['/']);
      expect(closeStarted, isTrue);

      closeCompleter.complete();
      await tester.pump();
    });

    testWidgets('detached sheet actions close before dispatching sheets', (
      tester,
    ) async {
      final launchedSheets = <String>[];
      var closeFinished = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CalendarPage.buildDetachedActionsMenuPanel(
                context,
                includeNewNote: true,
                onOpenCalendars: () async {
                  if (closeFinished) launchedSheets.add('Calendars');
                },
                closeMenu: () async {
                  closeFinished = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Calendars'));
      await tester.pump();

      expect(closeFinished, isTrue);
      expect(launchedSheets, <String>['Calendars']);
    });

    test('calendar-host menu buttons keep expected handlers', () async {
      final source = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final actions = _sourceBetween(
        source,
        'List<_CalendarAction> _calendarActions(',
        'Future<void> _showActionsMenu(',
      );

      _expectCalendarMenuAction(actions, 'Journal', '_openJournalFromAppBar');
      _expectCalendarMenuAction(actions, 'Planner', '_openPlannerPage');
      _expectCalendarMenuAction(actions, 'Inbox', '_openInboxFromMenu');
      _expectCalendarMenuAction(
        actions,
        'Calendars',
        '_openSharedCalendarsSheet',
      );
      _expectCalendarMenuAction(
        actions,
        'Reflections',
        '_openReflectionsFromMenu',
      );
      _expectCalendarMenuAction(actions, 'Library', '_openKemeticNodes');
      _expectCalendarMenuAction(actions, 'Settings', '_openSettingsFromMenu');
      _expectCalendarMenuAction(actions, 'Home', "context.go('/')");
      _expectCalendarMenuAction(
        actions,
        'Flow Studio',
        '_getFlowStudioCallback',
      );
      _expectCalendarMenuAction(actions, 'New note', '_openQuickAddSheet');
    });

    test('main calendar app bar actions keep expected handlers', () async {
      final source = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final appBar = _sourceBetween(
        source,
        'return AppBar(\n      backgroundColor: Colors.black,\n      elevation: 0.5,\n      centerTitle: false,',
        'Future<void> _openProfile(',
      );

      _expectTooltipAction(appBar, 'New note', <String>[
        'onPressed: _openQuickAddSheet',
      ]);
      _expectTooltipAction(appBar, 'Search notes', <String>[
        'KemeticAppBarSearchIcon',
        'onPressed: _openSearch',
      ]);
      _expectTooltipAction(appBar, 'Today', <String>[
        'KemeticAppBarTodayIcon',
        '_handleCalendarAppBarToday',
      ]);
      _expectTooltipAction(appBar, 'My Profile', <String>[
        'KemeticAppBarProfileIcon',
        '_openProfile(context)',
      ]);
    });

    test('planner app bar actions keep expected handlers', () async {
      final source = await File(
        'lib/features/rhythm/pages/todays_alignment_page.dart',
      ).readAsString();
      final appBar = _sourceBetween(
        source,
        'PreferredSizeWidget _buildAppBar()',
        '@override\n  Widget build(BuildContext context)',
      );

      _expectTooltipAction(appBar, 'New note', <String>[
        '_openCalendarQuickAdd()',
      ]);
      _expectTooltipAction(appBar, 'Search notes', <String>[
        'KemeticAppBarSearchIcon',
        'CalendarPage.openSearchFromAnyContext(context)',
      ]);
      _expectTooltipAction(appBar, 'Today', <String>[
        'KemeticAppBarTodayIcon',
        'CalendarPage.openMainCalendarAtToday(context)',
      ]);
      _expectTooltipAction(appBar, 'My Profile', <String>[
        'KemeticAppBarProfileIcon',
        '_openProfilePage',
      ]);
    });

    test('profile app bar actions keep expected handlers', () async {
      final source = await File(
        'lib/features/profile/profile_page.dart',
      ).readAsString();
      final appBar = _sourceBetween(source, 'appBar: AppBar(', 'body: Stack(');

      expect(appBar, isNot(contains("tooltip: 'Menu'")));
      expect(appBar, isNot(contains('_openCalendarMenu')));
      expect(appBar, contains("popOrGo(context, '/')"));
      _expectTooltipAction(appBar, 'New note', <String>[
        '_openCalendarQuickAdd()',
      ]);
      _expectTooltipAction(appBar, 'Search notes', <String>[
        'KemeticAppBarSearchIcon',
        'CalendarPage.openSearchFromAnyContext(context)',
      ]);
      _expectTooltipAction(appBar, 'Today', <String>[
        'KemeticAppBarTodayIcon',
        'CalendarPage.openMainCalendarAtToday(context)',
      ]);
      _expectTooltipAction(appBar, 'Profile', <String>['_closeFeed()']);
      _expectTooltipAction(appBar, 'My Profile', <String>[
        'KemeticAppBarProfileIcon',
        '_openMyProfileAction',
      ]);
    });

    test(
      'global bottom menu is available on profile and feed routes',
      () async {
        final source = await File('lib/main.dart').readAsString();
        final shell = _sourceBetween(
          source,
          'class _GlobalFloatingMenuShellState',
          'class _GlobalMenuBarrier',
        );

        expect(shell, contains('CalendarPage.buildDetachedActionsMenuPanel'));
        expect(shell, contains('if (supabase.auth.currentSession == null'));
        expect(shell, isNot(contains('_usesProfileAppBarMenu')));
        expect(shell, isNot(contains("segments.first != 'profile'")));
        expect(shell, isNot(contains("segments.first == 'profile'")));
      },
    );

    test('inbox app bars keep expected handlers', () async {
      final inbox = await File(
        'lib/features/inbox/inbox_page.dart',
      ).readAsString();
      final inboxAppBar = _sourceBetween(
        inbox,
        'appBar: AppBar(',
        'body: _buildBody()',
      );

      expect(inboxAppBar, contains("popOrGo(context, '/')"));
      _expectTooltipAction(inboxAppBar, 'Search people', <String>[
        'KemeticAppBarSearchIcon',
        '_openUserSearch',
      ]);
      expect(inboxAppBar, isNot(contains("tooltip: 'New message'")));
      expect(inboxAppBar, isNot(contains('Icons.person_search')));
      expect(inbox, contains("'?select=conversation'"));
      expect(inbox, contains('Search people to message'));

      final conversation = await File(
        'lib/features/inbox/inbox_conversation_page.dart',
      ).readAsString();
      final conversationAppBar = _sourceBetween(
        conversation,
        'appBar: AppBar(',
        'body: SafeArea(',
      );

      expect(conversationAppBar, contains("popOrGo(context, '/inbox')"));
      _expectTooltipAction(conversationAppBar, 'View profile', <String>[
        'context.go(',
        "'/profile/",
        'Uri.encodeComponent(widget.otherUserId)',
      ]);
    });

    test(
      'page navigation uses replacement routes, not page stack pushes',
      () async {
        final offenders = <String>[];

        await for (final entity in Directory('lib').list(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;

          final path = _normalizePath(entity.path);
          final source = await entity.readAsString();
          final lines = source.split('\n');
          for (var index = 0; index < lines.length; index += 1) {
            final line = lines[index];
            if (!line.contains('context.push')) continue;
            final isExplicitPicker =
                path.endsWith(
                  'lib/features/calendars/shared_calendars_sheet.dart',
                ) &&
                source.contains('&select=picker');
            if (!isExplicitPicker) {
              offenders.add('$path:${index + 1}: ${line.trim()}');
            }
          }
        }

        expect(offenders, isEmpty);
      },
    );

    test('popOrGo always routes to its explicit fallback', () async {
      final source = await File(
        'lib/core/navigation_fallback.dart',
      ).readAsString();

      expect(source, contains('context.go(fallbackLocation)'));
      expect(source, isNot(contains('.canPop()')));
      expect(source, isNot(contains('.pop(result)')));
    });

    test(
      'top-level close and row actions do not use previous-route history',
      () async {
        final sharePreview = await File(
          'lib/features/sharing/share_preview_page.dart',
        ).readAsString();
        final closePreview = _sourceBetween(
          sharePreview,
          'void _closePreview()',
          'Map<String, dynamic>? _resolvedFlowData()',
        );
        expect(closePreview, contains("context.go('/')"));
        expect(closePreview, isNot(contains('canPop')));
        expect(closePreview, isNot(contains('.pop()')));

        final followList = await File(
          'lib/features/profile/follow_list_page.dart',
        ).readAsString();
        final rowTap = _sourceBetween(
          followList,
          'trailing: KemeticGold.icon(Icons.chevron_right),',
          ');',
        );
        expect(rowTap, contains("context.go('/profile/"));
        expect(rowTap, isNot(contains('canPop')));
        expect(rowTap, isNot(contains('.pop(')));
      },
    );

    test(
      'top-level app bar close buttons route to explicit fallbacks',
      () async {
        const expectedFallbacks = <String, List<String>>{
          'lib/features/settings/settings_page.dart': ["popOrGo(context, '/')"],
          'lib/features/profile/profile_page.dart': ["popOrGo(context, '/')"],
          'lib/features/inbox/inbox_page.dart': ["popOrGo(context, '/')"],
          'lib/features/inbox/inbox_conversation_page.dart': [
            "popOrGo(context, '/inbox')",
          ],
          'lib/features/invites/event_invite_details_page.dart': [
            "popOrGo(context, '/inbox')",
          ],
          'lib/features/reflections/decan_reflection_archive_page.dart': [
            "popOrGo(context, '/')",
          ],
          'lib/features/reflections/decan_reflection_detail_page.dart': [
            "popOrGo(context, '/reflections')",
          ],
          'lib/features/journal/journal_entry_detail_page.dart': [
            "popOrGo(context, '/journal')",
          ],
          'lib/features/profile/profile_search_page.dart': [
            'popOrGo(context, widget.fallbackLocation)',
          ],
          'lib/features/profile/edit_profile_page.dart': [
            "popOrGo(context, '/profile/me')",
          ],
          'lib/features/profile/follow_list_page.dart': ['popOrGo('],
          'lib/features/profile/flow_post_picker_page.dart': [
            "popOrGo(context, '/profile/me')",
          ],
          'lib/features/profile/insight_post_picker_page.dart': [
            "popOrGo(context, '/profile/me')",
          ],
          'lib/features/rhythm/pages/commitment_tracker_page.dart': [
            "popOrGo(context, '/rhythm/today')",
          ],
          'lib/features/rhythm/pages/my_cycle_page.dart': [
            "popOrGo(context, '/rhythm/today')",
          ],
          'lib/features/rhythm/pages/rhythm_editors.dart': [
            "popOrGo(context, '/rhythm/mycycle')",
          ],
          'lib/features/inbox/shared_flow_details_page.dart': [
            'popOrGo(context, widget.fallbackLocation)',
          ],
          'lib/features/sharing/share_preview_page.dart': ["context.go('/')"],
        };

        for (final entry in expectedFallbacks.entries) {
          final source = await File(entry.key).readAsString();
          for (final expected in entry.value) {
            expect(source, contains(expected), reason: entry.key);
          }
        }
      },
    );

    test('day view chrome action row keeps expected handlers', () async {
      final source = await File(
        'lib/features/calendar/day_view_chrome.dart',
      ).readAsString();
      final header = _sourceBetween(
        source,
        'child: Row(',
        'SizedBox(\n              height: miniCalendarHeight,',
      );

      expect(header, contains('onPressed: onClose ?? () {}'));
      _expectTooltipAction(header, 'New note', <String>[
        'await onOpenQuickAdd!(btnCtx)',
      ]);
      _expectTooltipAction(header, 'Search notes', <String>[
        'KemeticAppBarSearchIcon',
        'await onOpenSearch!(context)',
      ]);
      _expectTooltipAction(header, 'Today', <String>[
        'KemeticAppBarTodayIcon',
        'onPressed: onJumpToToday ?? () {}',
      ]);
      _expectTooltipAction(header, 'My Profile', <String>[
        'KemeticAppBarProfileIcon',
        'await onOpenProfile!(context)',
      ]);

      final dayView = await File(
        'lib/features/calendar/day_view.dart',
      ).readAsString();
      expect(
        dayView,
        contains(
          'final Future<void> Function(BuildContext context)? onOpenSearch;',
        ),
      );
      expect(
        dayView,
        contains('await CalendarPage.openSearchFromAnyContext(btnCtx);'),
      );

      final calendarPage = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      expect(
        calendarPage,
        contains('onOpenSearch: (ctx) async => _openSearchForContext(ctx),'),
      );
    });

    test('shared app bar search actions never route home', () async {
      final files = <String>[
        'lib/features/calendar/calendar_page.dart',
        'lib/features/calendar/day_view_chrome.dart',
        'lib/features/rhythm/pages/todays_alignment_page.dart',
        'lib/features/profile/profile_page.dart',
      ];

      for (final path in files) {
        final source = await File(path).readAsString();
        for (final action in _tooltipActions(source, 'Search notes')) {
          expect(
            action,
            isNot(contains('openMainCalendarAtToday')),
            reason: '$path search action must not behave like Today/Home',
          );
          expect(
            action,
            isNot(contains("popOrGo(context, '/')")),
            reason: '$path search action must not route home',
          );
          expect(
            action,
            anyOf(
              contains('openSearchFromAnyContext'),
              contains('onPressed: _openSearch'),
              contains('onOpenSearch'),
            ),
            reason: '$path search action must open search',
          );
        }
      }
    });

    test('every app bar button declares an enabled handler', () async {
      final offenders = <String>[];
      var appBarCount = 0;
      var buttonCount = 0;

      await for (final entity in Directory('lib').list(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;

        final path = _normalizePath(entity.path);
        final source = await entity.readAsString();
        var appBarIndex = 0;
        for (final appBar in _callBlocks(source, 'AppBar(')) {
          appBarIndex += 1;
          appBarCount += 1;

          for (final marker in <String>[
            'IconButton(',
            'KemeticAppBarAction(',
          ]) {
            for (final button in _callBlocks(appBar, marker)) {
              buttonCount += 1;
              final label = '$path AppBar#$appBarIndex ${marker.trim()}';
              if (!button.contains('onPressed:')) {
                offenders.add('$label is missing onPressed');
              }
              if (RegExp(r'onPressed:\s*null\b').hasMatch(button)) {
                offenders.add('$label has disabled onPressed:null');
              }
            }
          }
        }
      }

      expect(appBarCount, greaterThan(0));
      expect(buttonCount, greaterThan(0));
      expect(offenders, isEmpty);
    });
  });
}

void _expectTooltipAction(
  String source,
  String tooltip,
  List<String> expectedNeedles,
) {
  final matches = _tooltipActions(source, tooltip);
  expect(matches, isNotEmpty, reason: 'Missing app bar tooltip "$tooltip"');
  expect(
    matches.any((match) => expectedNeedles.every(match.contains)),
    isTrue,
    reason:
        'No "$tooltip" action contained all expected markers: '
        '${expectedNeedles.join(', ')}',
  );
}

void _expectCalendarMenuAction(
  String source,
  String label,
  String expectedNeedle,
) {
  final labelIndex = source.indexOf("label: '$label'");
  expect(labelIndex, isNot(-1), reason: 'Missing menu action "$label"');

  final actionStart = source.lastIndexOf('_CalendarAction(', labelIndex);
  expect(actionStart, isNot(-1), reason: 'Missing action block for "$label"');
  final nextActionStart = source.indexOf(
    '_CalendarAction(',
    labelIndex + label.length,
  );
  final block = source.substring(
    actionStart,
    nextActionStart == -1 ? source.length : nextActionStart,
  );

  expect(
    block,
    contains(expectedNeedle),
    reason: 'Menu action "$label" must keep expected handler',
  );
}

List<String> _tooltipActions(String source, String tooltip) {
  final needle = "tooltip: '$tooltip'";
  final matches = <String>[];
  var searchStart = 0;
  while (true) {
    final tooltipIndex = source.indexOf(needle, searchStart);
    if (tooltipIndex == -1) break;
    final actionStart = source.lastIndexOf('IconButton(', tooltipIndex);
    final kemeticStart = source.lastIndexOf(
      'KemeticAppBarAction(',
      tooltipIndex,
    );
    final start = actionStart > kemeticStart ? actionStart : kemeticStart;
    final safeStart = start == -1 ? tooltipIndex : start;
    matches.add(
      source.substring(
        safeStart,
        _nextActionStart(source, tooltipIndex + needle.length),
      ),
    );
    searchStart = tooltipIndex + needle.length;
  }
  return matches;
}

int _nextActionStart(String source, int searchStart) {
  final candidates = <int>[
    source.indexOf('KemeticAppBarAction(', searchStart),
    source.indexOf('IconButton(', searchStart),
  ].where((index) => index != -1).toList();
  if (candidates.isEmpty) {
    return source.length;
  }
  candidates.sort();
  return candidates.first;
}

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNot(-1), reason: 'Missing source marker: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNot(-1), reason: 'Missing source marker: $end');
  return source.substring(startIndex, endIndex);
}

List<String> _callBlocks(String source, String marker) {
  final blocks = <String>[];
  var searchStart = 0;
  while (true) {
    final start = source.indexOf(marker, searchStart);
    if (start == -1) break;
    final openParen = source.indexOf('(', start);
    final end = _matchingParen(source, openParen);
    if (end == -1) {
      searchStart = start + marker.length;
      continue;
    }
    blocks.add(source.substring(start, end + 1));
    searchStart = end + 1;
  }
  return blocks;
}

int _matchingParen(String source, int openParen) {
  var depth = 0;
  for (var i = openParen; i < source.length; i += 1) {
    final char = source.codeUnitAt(i);
    if (char == 0x28) {
      depth += 1;
    } else if (char == 0x29) {
      depth -= 1;
      if (depth == 0) return i;
    }
  }
  return -1;
}

String _normalizePath(String path) => path.replaceAll('\\', '/');
