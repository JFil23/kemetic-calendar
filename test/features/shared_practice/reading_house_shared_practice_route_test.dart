import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/shared_practice_models.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_detail_page.dart';
import 'package:mobile/features/calendar/the_reading_house/reading_house_authority.dart';
import 'package:mobile/features/calendar/the_reading_house_flow.dart';
import 'package:mobile/features/shared_practice/shared_practice_room_page.dart';

void main() {
  Future<void> pumpRoute(
    WidgetTester tester,
    SharedPracticeRoomSnapshot snapshot,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: SharedPracticeRoomRoutePage(
          roomId: snapshot.room.id,
          loadSnapshot: (_, _) async => snapshot,
          readingHouseAuthority: _NoopReadingHouseAuthority(
            snapshot.room.createdBy,
          ),
          resolvePersonalCalendarId: () async => 'personal-calendar',
          watchMessageChanges: (_) => const Stream<void>.empty(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('generic shared practice keeps the generic room page', (
    tester,
  ) async {
    final snapshot = _roomSnapshot(
      flowKey: 'generic-practice',
      sourceName: kReadingHouseTitle,
      sourceNotes: 'ordinary shared practice',
      viewerCanEdit: false,
      viewerIsMember: true,
      includeGroupVisual: true,
    );
    await pumpRoute(tester, snapshot);

    expect(sharedPracticeSnapshotIsReadingHouse(snapshot), isFalse);
    expect(find.byType(SharedPracticeRoomPage), findsOneWidget);
    expect(find.byType(ReadingHouseDetailSurface), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('live-group-flow-chat')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('group-flow-compact-merkhet')),
      findsOneWidget,
    );
    expect(find.text('Day 3 of 12 · host position'), findsOneWidget);

    expect(find.text('The third day feels steadier.'), findsOneWidget);

    final postQuote = find.byKey(
      const ValueKey<String>('post_group_quote_message-1'),
    );
    expect(postQuote, findsOneWidget);
    await tester.ensureVisible(postQuote);
    await tester.pumpAndSettle();
    await tester.tap(postQuote);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('live-group-flow-confirm-quote')),
      findsOneWidget,
    );
    expect(
      find.text('Flow Creator will approve this before it becomes public.'),
      findsOneWidget,
    );
  });

  testWidgets('Reading House creator gets the canonical editable detail', (
    tester,
  ) async {
    final snapshot = _roomSnapshot(
      flowKey: null,
      sourceFlowKey: kReadingHouseFlowKey,
      sourceName: kReadingHouseTitle,
      sourceNotes: 'maat=$kReadingHouseFlowKey',
      viewerCanEdit: true,
      viewerCanManage: true,
      viewerIsMember: true,
    );
    await pumpRoute(tester, snapshot);

    expect(sharedPracticeSnapshotIsReadingHouse(snapshot), isTrue);
    expect(find.byType(ReadingHouseDetailSurface), findsOneWidget);
    expect(find.byType(SharedPracticeRoomPage), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('live-group-flow-chat')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('reading-house-book')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('reading-house-edition')),
      findsOneWidget,
    );
    final editQuestion = find.byKey(
      const ValueKey<String>('reading-house-question-edit'),
    );
    await tester.ensureVisible(editQuestion);
    await tester.pumpAndSettle();
    await tester.tap(editQuestion);
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('reading-house-question')),
      findsOneWidget,
    );
    expect(find.byType(MaatFlowDetailDock), findsOneWidget);
  });

  testWidgets('public non-member cannot see the private group conversation', (
    tester,
  ) async {
    final snapshot = _roomSnapshot(
      flowKey: 'generic-practice',
      sourceName: 'Dawn Strength Practice',
      sourceNotes: 'ordinary shared practice',
      viewerCanEdit: false,
      includeGroupVisual: true,
    );
    await pumpRoute(tester, snapshot);

    expect(find.byType(SharedPracticeRoomPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('live-group-flow-chat')),
      findsNothing,
    );
  });

  testWidgets('revoked member no longer sees an already-open group room', (
    tester,
  ) async {
    final changes = StreamController<void>.broadcast();
    addTearDown(changes.close);
    final snapshot = _roomSnapshot(
      flowKey: 'generic-practice',
      sourceName: 'Dawn Strength Practice',
      sourceNotes: 'ordinary shared practice',
      viewerCanEdit: false,
      viewerIsMember: true,
      includeGroupVisual: true,
    );
    var loads = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SharedPracticeRoomRoutePage(
          roomId: snapshot.room.id,
          loadSnapshot: (_, _) async {
            loads += 1;
            if (loads == 1) return snapshot;
            throw StateError('ROOM_NOT_ACCESSIBLE');
          },
          watchMessageChanges: (_) => changes.stream,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('live-group-flow-chat')),
      findsOneWidget,
    );

    changes.add(null);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('live-group-flow-chat')),
      findsNothing,
    );
    expect(find.text('Shared practice could not be loaded.'), findsOneWidget);
  });

  testWidgets(
    'public viewer and accepted reader use the same read-only detail',
    (tester) async {
      for (final viewerIsMember in <bool>[false, true]) {
        final snapshot = _roomSnapshot(
          flowKey: null,
          sourceFlowKey: kReadingHouseFlowKey,
          sourceName: kReadingHouseTitle,
          sourceNotes: 'maat=$kReadingHouseFlowKey',
          viewerCanEdit: false,
          viewerCanManage: !viewerIsMember,
          viewerIsMember: viewerIsMember,
        );
        await pumpRoute(tester, snapshot);

        expect(find.byType(ReadingHouseDetailSurface), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey<String>('reading-house-setup')),
            matching: find.byType(TextField),
          ),
          findsNothing,
        );
        expect(find.byType(MaatFlowDetailDock), findsNothing);
        expect(
          find.byKey(const ValueKey<String>('reading-house-invite-reader')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('reading-house-add-sitting')),
          findsNothing,
        );
      }
    },
  );

  test('Commons and shared-flow preview resolve the existing presentation', () {
    final routeSource = File(
      'lib/features/shared_practice/shared_practice_room_page.dart',
    ).readAsStringSync();
    final mainSource = File('lib/main.dart').readAsStringSync();
    final sharedFlowSource = File(
      'lib/features/inbox/shared_flow_details_page.dart',
    ).readAsStringSync();
    final calendarSource = File(
      'lib/features/calendar/calendar_active_maat_flows.dart',
    ).readAsStringSync();

    expect(mainSource, contains('SharedPracticeRoomRoutePage(roomId: roomId)'));
    expect(routeSource, contains('return ReadingHouseDetailSurface('));
    expect(routeSource, isNot(contains('CommonsReadingHousePage')));
    expect(
      sharedFlowSource,
      contains('CalendarPage.buildCanonicalFlowDetail('),
    );
    expect(calendarSource, contains('return ReadingHouseDetailSurface('));
    expect(calendarSource, contains('LiveReadingHouseAuthority('));
  });
}

SharedPracticeRoomSnapshot _roomSnapshot({
  required String? flowKey,
  String? sourceFlowKey,
  required String sourceName,
  required String sourceNotes,
  required bool viewerCanEdit,
  bool viewerCanManage = false,
  bool viewerIsMember = false,
  bool includeGroupVisual = false,
}) {
  const plan = ReadingHousePlan(
    bookTitle: 'The Living Blood',
    editionNote: 'First edition',
    houseQuestion: 'What would you do if you could live forever?',
    state: kReadingHouseHeldState,
  );
  return SharedPracticeRoomSnapshot.fromJson(<String, dynamic>{
    'room': <String, dynamic>{
      'id': 'room-1',
      'calendar_id': 'calendar-1',
      'source_flow_id': 960,
      'created_by': 'host-user',
      'title': sourceName,
      if (flowKey != null) 'flow_key': flowKey,
      'status': 'active',
      'visibility': 'public',
      'join_policy': 'owner_approval',
      if (includeGroupVisual) 'member_count': 2,
    },
    'calendar': <String, dynamic>{
      'id': 'calendar-1',
      'owner_id': 'host-user',
      'name': 'Reading House',
      'color': 0x3FA98A,
    },
    'source_flow': <String, dynamic>{
      'id': 960,
      'user_id': 'host-user',
      'calendar_id': 'calendar-1',
      'name': sourceName,
      'notes': sourceNotes,
      'start_date': '2026-08-30',
      if (includeGroupVisual)
        'appearance': <String, dynamic>{
          'sign_kind': 'palm_count',
          'sign_label': 'Day count',
          'accent_argb': 0xFF3FA98A,
        },
      'ai_metadata': <String, dynamic>{
        'flow_key': sourceFlowKey ?? flowKey,
        kReadingHouseMetadataKey: readingHouseMetadata(
          plan: plan,
          sittings: kReadingHouseSittings,
          openDoors: true,
        ),
      },
    },
    'local_date': '2026-08-30',
    if (includeGroupVisual)
      'today_step': <String, dynamic>{
        'id': 'step-3',
        'client_event_id': 'event-3',
        'flow_id': 960,
        'title': 'Day 3 practice',
        'step_index': 3,
        'total_steps': 12,
      },
    'members': viewerIsMember
        ? <Map<String, dynamic>>[
            <String, dynamic>{
              'user_id': 'reader-user',
              'role': 'viewer',
              'display_name': 'Accepted Reader',
              if (includeGroupVisual) 'completed_count': 2,
              if (includeGroupVisual) 'total_count': 12,
            },
            if (includeGroupVisual)
              <String, dynamic>{
                'user_id': 'host-user',
                'role': 'owner',
                'display_name': 'Flow Creator',
                'completed_count': 3,
                'total_count': 12,
              },
          ]
        : const <Map<String, dynamic>>[],
    'entries': const <Map<String, dynamic>>[],
    if (includeGroupVisual)
      'messages': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'message-1',
          'room_id': 'room-1',
          'user_id': 'host-user',
          'flow_day': '2026-08-30',
          'body_text': 'The third day feels steadier.',
          'author_display_name': 'Flow Creator',
          'created_at': '2026-08-30T12:00:00Z',
        },
      ],
    'viewer_can_edit': viewerCanEdit,
    'viewer_can_manage': viewerCanManage,
    'viewer_is_member': viewerIsMember,
  });
}

class _NoopReadingHouseAuthority implements ReadingHouseAuthority {
  const _NoopReadingHouseAuthority(this.currentUserId);

  @override
  final String? currentUserId;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError(invocation.memberName.toString());
}
