import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flow_appearance.dart';
import 'package:mobile/data/shared_practice_models.dart';
import 'package:mobile/features/shared_practice/together_flow_day_hero.dart';

SharedPracticeRoomSnapshot _snapshot({
  String clientEventId = 'event-3',
  int memberCount = 2,
}) {
  return SharedPracticeRoomSnapshot.fromJson(<String, dynamic>{
    'room': <String, dynamic>{
      'id': 'room-1',
      'calendar_id': null,
      'source_flow_id': 42,
      'created_by': 'host-1',
      'title': 'Morning Practice',
      'status': 'active',
      'member_count': memberCount,
    },
    'calendar': <String, dynamic>{
      'id': null,
      'name': 'Group flow',
      'color': 0xFFD4AF37,
    },
    'local_date': '2026-09-26',
    'today_step': <String, dynamic>{
      'id': 'step-3',
      'client_event_id': clientEventId,
      'flow_id': 42,
      'title': 'Third practice',
      'step_index': 3,
      'total_steps': 12,
    },
    'members': <Map<String, dynamic>>[
      <String, dynamic>{
        'user_id': 'host-1',
        'display_name': 'Sekhet',
        'completion_status': 'none',
        'presence_status': 'not_yet',
      },
      <String, dynamic>{
        'user_id': 'friend-1',
        'display_name': 'Amina',
        'completion_status': 'none',
        'presence_status': 'not_yet',
      },
    ],
    'entries': <dynamic>[],
    'messages': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'message-1',
        'room_id': 'room-1',
        'user_id': 'friend-1',
        'flow_day': '2026-09-26',
        'body_text': 'Meet the day where it is.',
        'author_display_name': 'Amina',
      },
    ],
    'viewer_is_member': true,
  });
}

Widget _hero(SharedPracticeRoomSnapshot snapshot) {
  return MaterialApp(
    home: Scaffold(
      body: TogetherFlowDayHero(
        flowId: 42,
        clientEventId: 'event-3',
        flowTitle: 'Morning Practice',
        calendarName: 'Personal',
        appearance: FlowAppearance.empty,
        accent: const Color(0xFFD4AF37),
        completedOccurrences: 2,
        totalOccurrences: 12,
        animationRevision: 0,
        fallback: const SizedBox(key: ValueKey<String>('solo-flow-fallback')),
        resolveRoom: (_) async => 'room-1',
        loadSnapshot: (_, _) async => snapshot,
        watchMessageChanges: (_) => const Stream<void>.empty(),
      ),
    ),
  );
}

void main() {
  testWidgets('current host step replaces the graphic with group chat', (
    tester,
  ) async {
    await tester.pumpWidget(_hero(_snapshot()));
    await tester.pumpAndSettle();

    final chat = find.byKey(const ValueKey<String>('together-flow-day-chat'));
    expect(chat, findsOneWidget);
    expect(find.text('Day 3 of 12 · host position'), findsOneWidget);
    expect(find.text('Meet the day where it is.'), findsOneWidget);
    expect(tester.getSize(chat).height, 190);
    expect(
      find.byKey(const ValueKey<String>('solo-flow-fallback')),
      findsNothing,
    );
  });

  testWidgets('historical event keeps the original solo graphic', (
    tester,
  ) async {
    await tester.pumpWidget(_hero(_snapshot(clientEventId: 'event-4')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('together-flow-day-chat')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('solo-flow-fallback')),
      findsOneWidget,
    );
  });
}
