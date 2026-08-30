import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/profile_repo.dart';
import 'package:mobile/data/shared_calendar_models.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_thirty_day_calendar.dart';
import 'package:mobile/features/calendar/the_reading_house/reading_house_authority.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_detail_page.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_sitting_editor.dart';
import 'package:mobile/features/calendar/the_reading_house_flow.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';

const _captureVisualCheckpoint = bool.fromEnvironment(
  'CAPTURE_READING_HOUSE_VISUAL_CHECKPOINT',
);
const _captureSurfaceKey = ValueKey<String>(
  'reading-house-visual-capture-surface',
);

void main() {
  Future<_FakeReadingHouseAuthority> pumpHouse(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    _FakeReadingHouseAuthority? authority,
    int? initialFlowId,
  }) async {
    final fake = authority ?? _FakeReadingHouseAuthority();
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: _captureSurfaceKey,
          child: ReadingHouseDetailPage(
            key: ValueKey<Size>(size),
            timezone: TrackSkyTimeZone.pacific,
            initialStartDate: DateTime(2026, 9, 14),
            initialFlowId: initialFlowId,
            initiallyHeld: initialFlowId != null,
            authority: fake,
            resolvePersonalCalendarId: () async => 'personal-calendar',
          ),
        ),
      ),
    );
    await tester.pump();
    Object? heroLoadError;
    await tester.runAsync(
      () => precacheImage(
        const AssetImage(ReadingHouseDetailTokens.heroAsset),
        tester.element(find.byType(ReadingHouseDetailPage)),
        onError: (exception, stackTrace) => heroLoadError = exception,
      ),
    );
    expect(heroLoadError, isNull);
    await tester.pumpAndSettle();
    return fake;
  }

  Finder houseScrollable() => find
      .descendant(
        of: find.byKey(const ValueKey<String>('reading-house-scroll')),
        matching: find.byType(Scrollable),
      )
      .first;

  Future<void> jumpHouseScroll(WidgetTester tester, double offset) async {
    final position = tester.state<ScrollableState>(houseScrollable()).position;
    position.jumpTo(offset.clamp(0, position.maxScrollExtent).toDouble());
    await tester.pumpAndSettle();
  }

  testWidgets('uses the shared detail architecture and revised visual copy', (
    tester,
  ) async {
    await pumpHouse(tester);

    expect(find.byType(MaatFlowDetailShell), findsOneWidget);
    expect(find.byType(MaatFlowDetailHero), findsOneWidget);
    expect(find.byType(MaatFlowDetailDock), findsOneWidget);
    expect(find.byType(MaatFlowThirtyDayCalendar), findsOneWidget);
    final heroImage = tester.widget<Image>(
      find.byKey(const ValueKey<String>('reading-house-hero-image')),
    );
    expect(heroImage.image, isA<AssetImage>());
    expect(
      (heroImage.image as AssetImage).assetName,
      ReadingHouseDetailTokens.heroAsset,
    );
    expect(heroImage.fit, BoxFit.cover);
    expect(heroImage.alignment, ReadingHouseDetailTokens.heroImageAlignment);
    expect(find.text('The Reading\nHouse'), findsOneWidget);
    expect(find.text('A house kept around one book.'), findsOneWidget);
    expect(find.text('BEFORE THE CALENDAR'), findsOneWidget);
    expect(find.text('Set the house'), findsNothing);
    expect(find.text('No invites yet'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Hold this house'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('reading-house-thirty-day-calendar')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('reading-house-hold')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('reading-house-held')),
      findsOneWidget,
    );
    expect(find.text('Held in your flows'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('solo, doors, and reader invite use the real authority seam', (
    tester,
  ) async {
    final authority = await pumpHouse(tester);
    await jumpHouseScroll(tester, 650);
    await tester.tap(find.text('Solo study'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('reading-house-readers')),
      findsNothing,
    );

    await tester.tap(find.text('With readers'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('reading-house-readers')),
      findsOneWidget,
    );

    await jumpHouseScroll(tester, 820);
    await tester.tap(find.text('Open · Commons'));
    await tester.pumpAndSettle();
    expect(
      find.text('Community members can discover this house in the Commons.'),
      findsOneWidget,
    );

    final invite = find.byKey(
      const ValueKey<String>('reading-house-invite-reader'),
    );
    await jumpHouseScroll(tester, 1050);
    await tester.tap(invite);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('reading-house-invite-sheet')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('reading-house-reader-search')),
      'Amina',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Amina Reed'));
    await tester.pumpAndSettle();
    expect(find.text('Amina Reed'), findsOneWidget);
    expect(find.text('1 invite pending'), findsOneWidget);
    expect(authority.inviteCount, 1);
    expect(authority.lastSnapshot?.openDoors, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'sittings use the shared editor with real date and time pickers',
    (tester) async {
      await pumpHouse(tester);
      final firstSitting = find.byKey(
        const ValueKey<String>('reading-house-sitting-1'),
      );
      await jumpHouseScroll(tester, 2000);
      await tester.tap(firstSitting);
      await tester.pumpAndSettle();

      expect(find.byType(ReadingHouseSittingEditorSheet), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('reading_house_sitting_date_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('reading_house_sitting_time_button')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('reading_house_sitting_save_button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('NOT PLACED'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('hold is idempotent and placement is the event boundary', (
    tester,
  ) async {
    final authority = await pumpHouse(tester);

    await tester.tap(find.byKey(const ValueKey<String>('reading-house-hold')));
    await tester.pumpAndSettle();
    expect(authority.ensureCount, 1);
    expect(authority.lastSnapshot?.isScheduled, isFalse);
    expect(authority.lastSnapshot?.flowId, authority.flowId);
    expect(authority.lastSnapshot?.plan.state, kReadingHouseHeldState);

    await tester.tap(find.byKey(const ValueKey<String>('reading-house-held')));
    await tester.pumpAndSettle();
    expect(authority.ensureCount, 1);

    await jumpHouseScroll(tester, 1500);
    final placeReading = find.byKey(
      const ValueKey<String>('reading-house-place-reading'),
    );
    await tester.ensureVisible(placeReading);
    await tester.pumpAndSettle();
    await tester.tap(placeReading);
    await tester.pumpAndSettle();
    expect(authority.ensureCount, 2);
    expect(authority.lastSnapshot?.sittings, hasLength(3));
    expect(
      authority.lastSnapshot?.sittings.every(
        (sitting) => sitting.scheduledDate != null,
      ),
      isTrue,
    );
  });

  testWidgets('partial setup persists progressively and restores on reopen', (
    tester,
  ) async {
    final authority = await pumpHouse(tester);
    await tester.tap(find.byKey(const ValueKey<String>('reading-house-hold')));
    await tester.pumpAndSettle();
    await jumpHouseScroll(tester, 700);
    await tester.enterText(
      find.byKey(const ValueKey<String>('reading-house-book')),
      'The Odyssey',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('reading-house-question')),
      'What does homecoming require?',
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('reading-house-reading-frame')),
        matching: find.text('What does homecoming require?'),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(authority.lastSnapshot?.plan.bookTitle, 'The Odyssey');
    expect(
      authority.lastSnapshot?.plan.houseQuestion,
      'What does homecoming require?',
    );

    await pumpHouse(
      tester,
      authority: authority,
      initialFlowId: authority.flowId,
    );
    await jumpHouseScroll(tester, 700);
    final book = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('reading-house-book')),
    );
    expect(book.controller?.text, 'The Odyssey');
    final question = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('reading-house-question')),
    );
    expect(question.controller?.text, 'What does homecoming require?');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('reading-house-reading-frame')),
        matching: find.text('What does homecoming require?'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('blank House Question uses the canonical frame fallback', (
    tester,
  ) async {
    await pumpHouse(tester);
    await jumpHouseScroll(tester, 700);
    final question = find.byKey(
      const ValueKey<String>('reading-house-question'),
    );
    await tester.enterText(question, 'A question for this house');
    await tester.pump();
    await tester.enterText(question, '');
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('reading-house-reading-frame')),
        matching: find.text(kReadingHouseDefaultQuestion),
      ),
      findsOneWidget,
    );
  });

  testWidgets('all setup and invite inputs obtain system text focus', (
    tester,
  ) async {
    await pumpHouse(tester);
    for (final key in const <String>[
      'reading-house-book',
      'reading-house-edition',
      'reading-house-question',
    ]) {
      final finder = find.byKey(ValueKey<String>(key));
      await Scrollable.ensureVisible(
        tester.element(finder),
        alignment: 0.42,
        duration: const Duration(milliseconds: 1),
      );
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: finder, matching: find.byType(EditableText)),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(tester.testTextInput.isVisible, isTrue);
    }

    await jumpHouseScroll(tester, 1050);
    await tester.tap(
      find.byKey(const ValueKey<String>('reading-house-invite-reader')),
    );
    await tester.pumpAndSettle();
    final search = find.byKey(
      const ValueKey<String>('reading-house-reader-search'),
    );
    expect(tester.widget<TextField>(search).focusNode?.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets(
    'sitting editor keeps every field above the keyboard and clears modal focus',
    (tester) async {
      await pumpHouse(tester);
      await jumpHouseScroll(tester, 2000);
      await tester.tap(
        find.byKey(const ValueKey<String>('reading-house-sitting-1')),
      );
      await tester.pumpAndSettle();

      const fieldKeys = <String>[
        'reading_house_sitting_title_field',
        'reading_house_sitting_section_field',
        'reading_house_sitting_theme_field',
        'reading_house_sitting_private_prompt_field',
        'reading_house_sitting_host_note_field',
      ];
      for (final key in fieldKeys) {
        final field = find.byKey(ValueKey<String>(key));
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(field).focusNode?.hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
      }

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(() => tester.view.viewInsets = FakeViewPadding.zero);
      await tester.pumpAndSettle();
      final hostNote = find.byKey(
        const ValueKey<String>('reading_house_sitting_host_note_field'),
      );
      await tester.ensureVisible(hostNote);
      await tester.tap(hostNote);
      await tester.pumpAndSettle();
      final surfaceHeight = tester.getSize(find.byType(Scaffold).first).height;
      expect(tester.getRect(hostNote).bottom, lessThan(surfaceHeight - 300));

      final dateButton = find.byKey(
        const ValueKey<String>('reading_house_sitting_date_button'),
      );
      await tester.ensureVisible(dateButton);
      await tester.tap(dateButton);
      await tester.pumpAndSettle();
      for (final key in fieldKeys) {
        expect(
          tester
              .widget<TextField>(find.byKey(ValueKey<String>(key)))
              .focusNode
              ?.hasFocus,
          isFalse,
        );
      }
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();

      final timeButton = find.byKey(
        const ValueKey<String>('reading_house_sitting_time_button'),
      );
      await tester.ensureVisible(timeButton);
      await tester.tap(timeButton);
      await tester.pumpAndSettle();
      for (final key in fieldKeys) {
        expect(
          tester
              .widget<TextField>(find.byKey(ValueKey<String>(key)))
              .focusNode
              ?.hasFocus,
          isFalse,
        );
      }
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      await tester.tap(hostNote);
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('reading_house_sitting_save_button')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ReadingHouseSittingEditorSheet), findsNothing);
      expect(
        tester
            .widgetList<EditableText>(find.byType(EditableText))
            .where((field) => field.focusNode.hasFocus),
        isEmpty,
      );
      expect(tester.testTextInput.isVisible, isFalse);

      await tester.tap(
        find.byKey(const ValueKey<String>('reading-house-sitting-1')),
      );
      await tester.pumpAndSettle();
      for (final key in fieldKeys) {
        expect(
          tester
              .widget<TextField>(find.byKey(ValueKey<String>(key)))
              .focusNode
              ?.hasFocus,
          isFalse,
        );
      }
    },
  );

  testWidgets('scheduled date and time persist through edit and reopen', (
    tester,
  ) async {
    final authority = _FakeReadingHouseAuthority();
    authority.lastSnapshot = ReadingHouseSnapshot(
      flowId: authority.flowId,
      calendarId: 'shared-house-calendar',
      plan: const ReadingHousePlan(),
      sittings: <ReadingHouseSitting>[
        kReadingHouseSittings.first.copyWith(
          scheduledDate: DateTime(2026, 9, 14),
          hour: 20,
          minute: 15,
        ),
        ...kReadingHouseSittings.skip(1),
      ],
      openDoors: false,
      members: const <SharedCalendarMember>[_FakeReadingHouseAuthority._host],
      held: true,
      canEdit: true,
      canManageMembership: true,
      isSharedHouse: true,
    );
    await pumpHouse(
      tester,
      authority: authority,
      initialFlowId: authority.flowId,
    );
    await jumpHouseScroll(tester, 2000);
    await tester.tap(
      find.byKey(const ValueKey<String>('reading-house-sitting-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('reading_house_sitting_save_button')),
    );
    await tester.pumpAndSettle();

    expect(
      authority.lastSnapshot?.sittings.first.scheduledDate,
      DateTime(2026, 9, 14),
    );
    expect(authority.lastSnapshot?.sittings.first.hour, 20);
    expect(authority.lastSnapshot?.sittings.first.minute, 15);

    await pumpHouse(
      tester,
      authority: authority,
      initialFlowId: authority.flowId,
    );
    await jumpHouseScroll(tester, 2000);
    expect(find.textContaining('8:15'), findsOneWidget);
  });

  testWidgets('accepted viewer sees the same house without write controls', (
    tester,
  ) async {
    final authority = _FakeReadingHouseAuthority();
    authority.lastSnapshot = ReadingHouseSnapshot(
      flowId: authority.flowId,
      calendarId: 'shared-house-calendar',
      plan: const ReadingHousePlan(),
      sittings: kReadingHouseSittings,
      openDoors: false,
      members: const <SharedCalendarMember>[
        _FakeReadingHouseAuthority._host,
        SharedCalendarMember(
          userId: 'reader-user',
          role: SharedCalendarRole.viewer,
          status: SharedCalendarInviteStatus.accepted,
          displayName: 'Nia Morgan',
          handle: 'niam',
        ),
      ],
      held: true,
      canEdit: false,
      canManageMembership: false,
      isSharedHouse: true,
    );
    await pumpHouse(
      tester,
      authority: authority,
      initialFlowId: authority.flowId,
    );
    await jumpHouseScroll(tester, 900);
    expect(find.text('Nia Morgan'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('reading-house-setup')),
        matching: find.byType(TextField),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('reading-house-book')),
      findsOneWidget,
    );
    expect(find.byType(MaatFlowDetailDock), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('reading-house-invite-reader')),
      findsNothing,
    );

    await jumpHouseScroll(tester, 2000);
    await tester.tap(
      find.byKey(const ValueKey<String>('reading-house-sitting-1')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ReadingHouseSittingEditorSheet), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('reading-house-add-sitting')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('reading-house-place-reading')),
      findsNothing,
    );
    expect(authority.ensureCount, 0);
  });

  testWidgets('stale reader search cannot replace the newer query', (
    tester,
  ) async {
    final authority = _ControlledSearchAuthority();
    await pumpHouse(tester, authority: authority);
    await jumpHouseScroll(tester, 1050);
    await tester.tap(
      find.byKey(const ValueKey<String>('reading-house-invite-reader')),
    );
    await tester.pumpAndSettle();
    final field = find.byKey(
      const ValueKey<String>('reading-house-reader-search'),
    );
    await tester.enterText(field, 'Am');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(field, 'Ni');
    await tester.pump(const Duration(milliseconds: 350));

    authority.complete(
      'Ni',
      UserSearchResult(
        userId: 'nia-user',
        displayName: 'Nia Morgan',
        handle: 'niam',
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Nia Morgan'), findsOneWidget);
    authority.complete(
      'Am',
      UserSearchResult(
        userId: 'amina-user',
        displayName: 'Amina Reed',
        handle: 'aminareads',
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Nia Morgan'), findsOneWidget);
    expect(find.text('Amina Reed'), findsNothing);
    expect(authority.lastExcluded, contains('host-user'));
  });

  testWidgets('profile search waits 250ms before using the authority', (
    tester,
  ) async {
    final authority = _ControlledSearchAuthority();
    await pumpHouse(tester, authority: authority);
    await jumpHouseScroll(tester, 1050);
    await tester.tap(
      find.byKey(const ValueKey<String>('reading-house-invite-reader')),
    );
    await tester.pumpAndSettle();
    final field = find.byKey(
      const ValueKey<String>('reading-house-reader-search'),
    );
    await tester.enterText(field, 'Am');
    await tester.pump(const Duration(milliseconds: 249));
    expect(authority.searchCount, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(authority.searchCount, 1);

    authority.complete(
      'Am',
      UserSearchResult(
        userId: 'amina-user',
        displayName: 'Amina Reed',
        handle: 'aminareads',
      ),
    );
    await tester.pump();
    expect(find.text('Amina Reed'), findsOneWidget);
  });

  testWidgets('invite is locally busy and refreshes only members', (
    tester,
  ) async {
    final authority = _FakeReadingHouseAuthority()
      ..inviteGate = Completer<void>();
    await pumpHouse(
      tester,
      authority: authority,
      initialFlowId: authority.flowId,
    );
    authority.resetOperationCounts();
    await jumpHouseScroll(tester, 1050);
    await tester.tap(
      find.byKey(const ValueKey<String>('reading-house-invite-reader')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('reading-house-reader-search')),
      'Amina',
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    await tester.tap(find.text('Amina Reed'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('reading-house-invite-result-busy')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('reading-house-invite-sheet')),
      findsOneWidget,
    );
    expect(
      tester.widget<MaatFlowDetailDock>(find.byType(MaatFlowDetailDock)).busy,
      isFalse,
    );
    expect(authority.inviteCount, 1);
    expect(authority.ensureCount, 0);
    expect(authority.updateCount, 0);
    expect(authority.sittingSaveCount, 0);
    expect(authority.loadCount, 0);

    authority.inviteGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Amina Reed'), findsOneWidget);
    expect(authority.memberRefreshCount, 1);
    expect(authority.ensureCount, 0);
    expect(authority.updateCount, 0);
    expect(authority.sittingSaveCount, 0);
    expect(authority.loadCount, 0);
  });

  testWidgets('door change does not reload plan, members, or events', (
    tester,
  ) async {
    final authority = _FakeReadingHouseAuthority()
      ..updateGate = Completer<void>();
    await pumpHouse(
      tester,
      authority: authority,
      initialFlowId: authority.flowId,
    );
    authority.resetOperationCounts();
    await jumpHouseScroll(tester, 820);
    await tester.tap(find.text('Open · Commons'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('reading-house-choice-busy')),
      findsOneWidget,
    );
    expect(
      tester.widget<MaatFlowDetailDock>(find.byType(MaatFlowDetailDock)).busy,
      isFalse,
    );
    expect(authority.updateCount, 1);
    expect(authority.ensureCount, 0);
    expect(authority.memberRefreshCount, 0);
    expect(authority.sittingSaveCount, 0);
    expect(authority.loadCount, 0);

    authority.updateGate!.complete();
    await tester.pumpAndSettle();
    expect(
      find.text('Community members can discover this house in the Commons.'),
      findsOneWidget,
    );
    expect(authority.updateCount, 1);
    expect(authority.ensureCount, 0);
    expect(authority.memberRefreshCount, 0);
    expect(authority.sittingSaveCount, 0);
    expect(authority.loadCount, 0);
  });

  testWidgets('one sitting save stays in-sheet and preserves page scroll', (
    tester,
  ) async {
    final authority = _FakeReadingHouseAuthority()
      ..sittingSaveGate = Completer<void>();
    await pumpHouse(
      tester,
      authority: authority,
      initialFlowId: authority.flowId,
    );
    authority.resetOperationCounts();
    await jumpHouseScroll(tester, 2000);
    final position = tester.state<ScrollableState>(houseScrollable()).position;
    final beforeOffset = position.pixels;
    await tester.tap(
      find.byKey(const ValueKey<String>('reading-house-sitting-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('reading_house_sitting_save_button')),
    );
    await tester.pump();

    expect(find.byType(ReadingHouseSittingEditorSheet), findsOneWidget);
    expect(find.text('Saving…'), findsOneWidget);
    expect(
      tester.widget<MaatFlowDetailDock>(find.byType(MaatFlowDetailDock)).busy,
      isFalse,
    );
    expect(authority.sittingSaveCount, 1);
    expect(authority.lastSavedSittingEventNumber, 1);
    expect(authority.ensureCount, 0);
    expect(authority.updateCount, 0);
    expect(authority.memberRefreshCount, 0);
    expect(authority.loadCount, 0);

    authority.sittingSaveGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ReadingHouseSittingEditorSheet), findsNothing);
    expect(position.pixels, closeTo(beforeOffset, 0.01));
    expect(authority.sittingSaveCount, 1);
    expect(authority.ensureCount, 0);
    expect(authority.updateCount, 0);
    expect(authority.memberRefreshCount, 0);
    expect(authority.loadCount, 0);
  });

  testWidgets('narrow phone keeps the shared page free of layout overflow', (
    tester,
  ) async {
    await pumpHouse(tester, size: const Size(340, 700));
    final scroll = find.byKey(const ValueKey<String>('reading-house-scroll'));
    await tester.drag(scroll, const Offset(0, -1400));
    await tester.pumpAndSettle();
    await tester.drag(scroll, const Offset(0, -1400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('captures Reading House visual checkpoints', (tester) async {
    if (!_captureVisualCheckpoint) return;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    await _loadVisualFonts();

    for (final fixture in const <({String name, Size size})>[
      (name: '390', size: Size(390, 844)),
      (name: '340', size: Size(340, 700)),
    ]) {
      await pumpHouse(tester, size: fixture.size);
      await expectLater(
        find.byKey(_captureSurfaceKey),
        matchesGoldenFile('/tmp/reading-house-${fixture.name}-hero.png'),
      );

      await jumpHouseScroll(tester, 650);
      await expectLater(
        find.byKey(_captureSurfaceKey),
        matchesGoldenFile('/tmp/reading-house-${fixture.name}-setup.png'),
      );

      await jumpHouseScroll(tester, 1400);
      await expectLater(
        find.byKey(_captureSurfaceKey),
        matchesGoldenFile('/tmp/reading-house-${fixture.name}-calendar.png'),
      );

      await jumpHouseScroll(tester, 2000);
      await expectLater(
        find.byKey(_captureSurfaceKey),
        matchesGoldenFile('/tmp/reading-house-${fixture.name}-sittings.png'),
      );
    }
    expect(tester.takeException(), isNull);
  });
}

Future<void> _loadVisualFonts() async {
  final gentium = FontLoader('GentiumPlus')
    ..addFont(rootBundle.load('ios/Runner/Fonts/GentiumPlus-Regular.ttf'))
    ..addFont(rootBundle.load('ios/Runner/Fonts/GentiumPlus-Bold.ttf'));
  final cormorant = FontLoader('CormorantGaramond')
    ..addFont(rootBundle.load('ios/Runner/Fonts/CormorantGaramond-Regular.ttf'))
    ..addFont(rootBundle.load('ios/Runner/Fonts/CormorantGaramond-Italic.ttf'))
    ..addFont(rootBundle.load('ios/Runner/Fonts/CormorantGaramond-Medium.ttf'))
    ..addFont(
      rootBundle.load('ios/Runner/Fonts/CormorantGaramond-MediumItalic.ttf'),
    )
    ..addFont(
      rootBundle.load('ios/Runner/Fonts/CormorantGaramond-SemiBold.ttf'),
    );
  final materialIcons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  final hieroglyphs = FontLoader('Noto Sans Egyptian Hieroglyphs')
    ..addFont(
      rootBundle.load(
        'ios/Runner/Fonts/NotoSansEgyptianHieroglyphs-Regular.ttf',
      ),
    );
  await Future.wait(<Future<void>>[
    gentium.load(),
    cormorant.load(),
    materialIcons.load(),
    hieroglyphs.load(),
  ]);
}

class _FakeReadingHouseAuthority implements ReadingHouseAuthority {
  int get flowId => 41;
  int ensureCount = 0;
  int updateCount = 0;
  int sittingSaveCount = 0;
  int inviteCount = 0;
  int memberRefreshCount = 0;
  int searchCount = 0;
  int loadCount = 0;
  int? lastSavedSittingEventNumber;
  Set<String> lastExcluded = <String>{};
  ReadingHouseSnapshot? lastSnapshot;
  Completer<void>? updateGate;
  Completer<void>? inviteGate;
  Completer<void>? memberRefreshGate;
  Completer<void>? sittingSaveGate;

  static const _host = SharedCalendarMember(
    userId: 'host-user',
    role: SharedCalendarRole.owner,
    status: SharedCalendarInviteStatus.accepted,
    displayName: 'Host Reader',
    handle: 'host',
  );

  @override
  String? get currentUserId => 'host-user';

  void resetOperationCounts() {
    ensureCount = 0;
    updateCount = 0;
    sittingSaveCount = 0;
    inviteCount = 0;
    memberRefreshCount = 0;
    loadCount = 0;
    lastSavedSittingEventNumber = null;
  }

  @override
  Future<ReadingHouseSnapshot> ensureHouse({
    int? flowId,
    String? calendarId,
    required String personalCalendarId,
    required ReadingHousePlan plan,
    required List<ReadingHouseSitting> sittings,
    required bool openDoors,
    required TrackSkyTimeZone timezone,
  }) async {
    ensureCount += 1;
    final heldPlan = plan.copyWith(state: kReadingHouseHeldState);
    final snapshot = ReadingHouseSnapshot(
      flowId: flowId ?? this.flowId,
      calendarId: heldPlan.isSolo
          ? personalCalendarId
          : 'shared-house-calendar',
      plan: heldPlan,
      sittings: List<ReadingHouseSitting>.of(sittings),
      openDoors: !heldPlan.isSolo && openDoors,
      members: lastSnapshot?.members ?? const <SharedCalendarMember>[_host],
      held: true,
      canEdit: true,
      canManageMembership: !heldPlan.isSolo,
      isSharedHouse: !heldPlan.isSolo,
    );
    lastSnapshot = snapshot;
    return snapshot;
  }

  @override
  Future<SharedCalendarMember> inviteReader({
    required ReadingHouseSnapshot house,
    required UserSearchResult reader,
  }) async {
    inviteCount += 1;
    await inviteGate?.future;
    final member = SharedCalendarMember(
      userId: reader.userId,
      role: SharedCalendarRole.viewer,
      status: SharedCalendarInviteStatus.pending,
      displayName: reader.displayName,
      handle: reader.handle,
    );
    lastSnapshot = ReadingHouseSnapshot(
      flowId: house.flowId,
      calendarId: house.calendarId,
      plan: house.plan,
      sittings: house.sittings,
      openDoors: house.openDoors,
      members: <SharedCalendarMember>[...house.members, member],
      held: true,
      canEdit: true,
      canManageMembership: true,
      isSharedHouse: true,
    );
    return member;
  }

  @override
  Future<List<SharedCalendarMember>> refreshMembers({
    required ReadingHouseSnapshot house,
  }) async {
    memberRefreshCount += 1;
    await memberRefreshGate?.future;
    return lastSnapshot?.members ?? house.members;
  }

  @override
  Future<ReadingHouseSnapshot> load({
    required int flowId,
    required ReadingHousePlan fallbackPlan,
    required List<ReadingHouseSitting> fallbackSittings,
  }) async {
    loadCount += 1;
    return lastSnapshot ??
        ReadingHouseSnapshot(
          flowId: flowId,
          calendarId: 'shared-house-calendar',
          plan: fallbackPlan,
          sittings: fallbackSittings,
          openDoors: false,
          members: const <SharedCalendarMember>[_host],
          held: true,
          canEdit: true,
          canManageMembership: true,
          isSharedHouse: true,
        );
  }

  @override
  Future<ReadingHouseSnapshot> updateHeldHouse({
    required ReadingHouseSnapshot house,
    required ReadingHousePlan plan,
    required List<ReadingHouseSitting> sittings,
    required bool openDoors,
    required TrackSkyTimeZone timezone,
  }) async {
    updateCount += 1;
    await updateGate?.future;
    final snapshot = ReadingHouseSnapshot(
      flowId: house.flowId,
      calendarId: house.calendarId,
      plan: plan.copyWith(state: kReadingHouseHeldState),
      sittings: List<ReadingHouseSitting>.of(sittings),
      openDoors: !plan.isSolo && openDoors,
      members: house.members,
      held: true,
      canEdit: house.canEdit,
      canManageMembership: house.canManageMembership,
      isSharedHouse: house.isSharedHouse,
    );
    lastSnapshot = snapshot;
    return snapshot;
  }

  @override
  Future<ReadingHouseSnapshot> saveSitting({
    required ReadingHouseSnapshot house,
    required ReadingHouseSitting sitting,
    required List<ReadingHouseSitting> sittings,
    required TrackSkyTimeZone timezone,
  }) async {
    sittingSaveCount += 1;
    lastSavedSittingEventNumber = sitting.eventNumber;
    await sittingSaveGate?.future;
    final snapshot = ReadingHouseSnapshot(
      flowId: house.flowId,
      calendarId: house.calendarId,
      plan: house.plan,
      sittings: List<ReadingHouseSitting>.of(sittings),
      openDoors: house.openDoors,
      members: house.members,
      held: true,
      canEdit: house.canEdit,
      canManageMembership: house.canManageMembership,
      isSharedHouse: house.isSharedHouse,
    );
    lastSnapshot = snapshot;
    return snapshot;
  }

  @override
  Future<List<UserSearchResult>> searchReaders(
    String query, {
    required Iterable<String> excludedUserIds,
  }) async {
    searchCount += 1;
    lastExcluded = <String>{...excludedUserIds};
    final result = UserSearchResult(
      userId: 'amina-user',
      displayName: 'Amina Reed',
      handle: 'aminareads',
    );
    if (excludedUserIds.contains(result.userId) ||
        !query.toLowerCase().contains('amina')) {
      return const <UserSearchResult>[];
    }
    return <UserSearchResult>[result];
  }
}

class _ControlledSearchAuthority extends _FakeReadingHouseAuthority {
  final Map<String, Completer<List<UserSearchResult>>> _pending =
      <String, Completer<List<UserSearchResult>>>{};

  @override
  Future<List<UserSearchResult>> searchReaders(
    String query, {
    required Iterable<String> excludedUserIds,
  }) {
    searchCount += 1;
    lastExcluded = <String>{...excludedUserIds};
    return (_pending[query] ??= Completer<List<UserSearchResult>>()).future;
  }

  void complete(String query, UserSearchResult result) {
    final completer = _pending[query];
    if (completer == null) {
      throw StateError('No pending search for $query.');
    }
    completer.complete(<UserSearchResult>[result]);
  }
}
