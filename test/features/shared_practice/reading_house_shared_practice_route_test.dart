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
    );
    await pumpRoute(tester, snapshot);

    expect(sharedPracticeSnapshotIsReadingHouse(snapshot), isFalse);
    expect(find.byType(SharedPracticeRoomPage), findsOneWidget);
    expect(find.byType(ReadingHouseDetailPage), findsNothing);
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
    expect(find.byType(ReadingHouseDetailPage), findsOneWidget);
    expect(find.byType(SharedPracticeRoomPage), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('reading-house-setup')),
        matching: find.byType(TextField),
      ),
      findsNWidgets(3),
    );
    expect(find.byType(MaatFlowDetailDock), findsOneWidget);
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

        expect(find.byType(ReadingHouseDetailPage), findsOneWidget);
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
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();

    expect(mainSource, contains('SharedPracticeRoomRoutePage(roomId: roomId)'));
    expect(routeSource, contains('return ReadingHouseDetailPage('));
    expect(routeSource, isNot(contains('CommonsReadingHousePage')));
    expect(
      sharedFlowSource,
      contains('CalendarPage.buildCanonicalMaatFlowDetail('),
    );
    expect(calendarSource, contains('return ReadingHouseDetailPage('));
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
    'members': viewerIsMember
        ? <Map<String, dynamic>>[
            <String, dynamic>{
              'user_id': 'reader-user',
              'role': 'viewer',
              'display_name': 'Accepted Reader',
            },
          ]
        : const <Map<String, dynamic>>[],
    'entries': const <Map<String, dynamic>>[],
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
