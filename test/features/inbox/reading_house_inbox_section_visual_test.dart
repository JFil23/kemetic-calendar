import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/share_models.dart';
import 'package:mobile/data/share_repo.dart';
import 'package:mobile/data/shared_calendar_models.dart';
import 'package:mobile/features/calendar/calendar_invalidation.dart';
import 'package:mobile/features/calendar/the_reading_house/reading_house_room_repository.dart';
import 'package:mobile/features/inbox/conversation_user.dart';
import 'package:mobile/features/inbox/dm_conversation_models.dart';
import 'package:mobile/features/inbox/inbox_page.dart';
import 'package:mobile/features/inbox/presentation/reading_house_inbox_section.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/maat_flow_visual_test_fonts.dart';
import '../../support/maat_flow_visual_goldens.dart';

const _captureReadingHouseInboxVisuals = bool.fromEnvironment(
  'CAPTURE_READING_HOUSE_INBOX_VISUALS',
);
final _goldenRoot = maatFlowVisualGoldenRoot;
const _captureKey = ValueKey<String>('reading-house-inbox-visual-capture');
final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

final _pendingReadingHouseInvite = SharedCalendarInvite(
  calendarId: 'pending-house-calendar',
  calendarName: 'The Odyssey',
  calendarColorValue: 0x3FA98A,
  role: SharedCalendarRole.viewer,
  invitedAt: DateTime.utc(2026, 9, 4, 7, 15),
  invitedBy: 'amina',
  inviterDisplayName: 'Amina',
  inviteDirection: 'incoming',
  filingLifecycle: 'pending',
  sourceFlowId: 104,
  sourceFlowKey: 'the-reading-house',
  sourceBookTitle: 'The Odyssey',
);

class _VisualRoomDataSource implements ReadingHouseRoomDataSource {
  const _VisualRoomDataSource({this.summaries});

  final List<ReadingHouseRoomSummary>? summaries;

  static const identity = ReadingHouseRoomIdentity(
    calendarId: 'odyssey-house-calendar',
    flowId: 41,
  );

  static final summary = ReadingHouseRoomSummary(
    identity: identity,
    title: 'The Odyssey',
    members: const <ReadingHouseRoomMember>[
      ReadingHouseRoomMember(
        userId: 'amina',
        role: 'host',
        displayName: 'Amina',
      ),
      ReadingHouseRoomMember(
        userId: 'reader-a',
        role: 'member',
        displayName: 'You',
      ),
    ],
    memberCount: 3,
    unreadCount: 2,
    active: true,
    locked: false,
    ended: false,
    latestMessage: 'Perfect. I’m finishing the opening section now.',
    latestMessageAt: DateTime.utc(2026, 9, 4, 7, 21),
    latestAuthorId: 'amina',
    latestAuthorDisplayName: 'Amina',
  );

  static final messages = <ReadingHouseRoomMessage>[
    ReadingHouseRoomMessage(
      id: 'message-1',
      identity: identity,
      authorId: 'amina',
      body: 'Can we start fifteen minutes later?',
      createdAt: DateTime(2026, 9, 4, 7, 18),
      updatedAt: DateTime(2026, 9, 4, 7, 18),
    ),
    ReadingHouseRoomMessage(
      id: 'message-2',
      identity: identity,
      authorId: 'reader-a',
      body: 'Works for me.',
      createdAt: DateTime(2026, 9, 4, 7, 20),
      updatedAt: DateTime(2026, 9, 4, 7, 20),
    ),
    ReadingHouseRoomMessage(
      id: 'message-3',
      identity: identity,
      authorId: 'amina',
      body: 'Perfect. I’m finishing the opening section now.',
      createdAt: DateTime(2026, 9, 4, 7, 21),
      updatedAt: DateTime(2026, 9, 4, 7, 21),
    ),
  ];

  @override
  String? get currentUserId => 'reader-a';

  @override
  Future<void> deleteMessage({
    required ReadingHouseRoomIdentity identity,
    required String messageId,
  }) async {}

  @override
  Future<List<ReadingHouseRoomMessage>> listMessages({
    required ReadingHouseRoomIdentity identity,
    DateTime? before,
    int limit = 50,
  }) async => messages;

  @override
  Future<List<ReadingHouseRoomSummary>> listSummaries() async =>
      summaries ?? <ReadingHouseRoomSummary>[summary];

  @override
  Future<DateTime> markRead({
    required ReadingHouseRoomIdentity identity,
    required DateTime through,
  }) async => through;

  @override
  Future<void> sendMessage({
    required ReadingHouseRoomIdentity identity,
    required String body,
  }) async {}

  @override
  Future<void> updateMessage({
    required ReadingHouseRoomIdentity identity,
    required String messageId,
    required String body,
  }) async {}

  @override
  Stream<void> watchRoom(ReadingHouseRoomIdentity identity) =>
      const Stream<void>.empty();

  @override
  Stream<List<ReadingHouseRoomSummary>> watchSummaries() =>
      const Stream<List<ReadingHouseRoomSummary>>.empty();
}

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

DmConversationSummary _conversation({
  required String id,
  required String title,
  required String preview,
}) {
  return DmConversationSummary(
    id: id,
    type: DmConversationType.direct,
    createdBy: id,
    createdAt: _epoch,
    updatedAt: _epoch,
    members: <DmConversationMember>[
      DmConversationMember(
        user: ConversationUser(id: id, displayName: title),
        role: 'member',
      ),
    ],
    unreadCount: 0,
    lastBody: preview,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    const appLinksMessages = MethodChannel('com.llfbandit.app_links/messages');
    const appLinksEvents = MethodChannel('com.llfbandit.app_links/events');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(appLinksMessages, (_) async => null);
    messenger.setMockMethodCallHandler(appLinksEvents, (_) async {
      scheduleMicrotask(
        () =>
            messenger.handlePlatformMessage(appLinksEvents.name, null, (_) {}),
      );
      return null;
    });
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _ensureSupabaseInitialized();
    await loadMaatFlowVisualTestFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required Size size,
    double textScale = 1,
    List<ReadingHouseInboxRoomFixture>? rooms =
        const <ReadingHouseInboxRoomFixture>[
          kReadingHouseInboxRoomVisualFixture,
        ],
    bool showPendingInvite = false,
    Stream<List<InboxShareItem>>? inboxItemsStream,
    Stream<List<SharedCalendarInvite>>? incomingInvitesStream,
    ReadingHouseRoomDataSource roomDataSource = const _VisualRoomDataSource(),
    Stream<CalendarInvalidated> flowLifecycleStream = const Stream.empty(),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    await tester.binding.setSurfaceSize(size);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: InboxSheetRoutePage(
              childForTesting: InboxPage(
                sheet: true,
                inboxItemsStreamForTesting:
                    inboxItemsStream ??
                    const Stream<List<InboxShareItem>>.empty()
                        .asBroadcastStream(),
                flowLifecycleStreamForTesting: flowLifecycleStream,
                committedFlowItemsLoaderForTesting: () async => const [],
                disableAuxiliarySubscriptionsForTesting: true,
                readingHouseRoomsForTesting: rooms,
                dmConversationsForTesting: <DmConversationSummary>[
                  _conversation(
                    id: 'producedbyearth',
                    title: 'producedbyearth',
                    preview: '12-Day Bird Calls in Lea…',
                  ),
                  _conversation(
                    id: 'monroe-coconut',
                    title: 'Monroe/coconut',
                    preview: 'yes',
                  ),
                ],
                activityForTesting: <InboxActivityItem>[
                  InboxActivityItem(
                    type: InboxActivityType.follow,
                    createdAt: _epoch,
                    actorName: 'L.',
                  ),
                ],
                calendarSummarySubtitleForTesting: 'No pending invites',
                incomingCalendarInvitesStreamForTesting:
                    incomingInvitesStream ??
                    Stream<List<SharedCalendarInvite>>.value(
                      showPendingInvite
                          ? <SharedCalendarInvite>[_pendingReadingHouseInvite]
                          : const <SharedCalendarInvite>[],
                    ),
                readingHouseRoomDataSourceForTesting: roomDataSource,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    if (showPendingInvite) {
      await tester.tap(find.byKey(const ValueKey<String>('inbox-invites-row')));
      await tester.pumpAndSettle();
      expect(find.text('PENDING'), findsOneWidget);
    }
  }

  testWidgets(
    'real pending-invite stream reveals the Reading House card without reopening Inbox',
    (tester) async {
      final invites = StreamController<List<SharedCalendarInvite>>.broadcast();
      final inboxItems = StreamController<List<InboxShareItem>>.broadcast();
      addTearDown(invites.close);
      addTearDown(inboxItems.close);
      await pumpPage(
        tester,
        size: const Size(390, 844),
        inboxItemsStream: inboxItems.stream,
        incomingInvitesStream: invites.stream,
      );

      inboxItems.add(<InboxShareItem>[
        InboxShareItem(
          shareId: 'pending-house-notification',
          kind: InboxShareKind.calendar,
          recipientId: 'reader-a',
          senderId: 'amina',
          senderName: 'Amina',
          payloadId: 'pending-house-calendar',
          title: 'The Odyssey',
          createdAt: DateTime.utc(2026, 9, 4, 7, 15, 1),
          payloadJson: const <String, dynamic>{
            'notification_kind': 'calendar_invite',
            'calendar_id': 'pending-house-calendar',
            'calendar_name': 'The Odyssey',
          },
        ),
      ]);
      invites.add(<SharedCalendarInvite>[_pendingReadingHouseInvite]);
      await tester.pumpAndSettle();

      expect(find.text('The Reading House · waiting on you'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('inbox-invites-row')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('reading-house-pending-invite')),
        findsOneWidget,
      );
      expect(find.textContaining('Amina invited you to read'), findsOneWidget);
      expect(find.textContaining('invited you to this calendar'), findsNothing);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey<String>('reading-house-invite-accept')),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(
                const ValueKey<String>('reading-house-invite-decline'),
              ),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('actual Inbox route places each House above Messages', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(390, 844));
    final room = find.byKey(
      const ValueKey<String>(
        'reading-house-inbox-room-odyssey-house-calendar-41',
      ),
    );
    final messages = find.text('MESSAGES');
    expect(room, findsOneWidget);
    expect(
      tester.getBottomLeft(room).dy,
      lessThan(tester.getTopLeft(messages).dy),
    );
    expect(find.text('The Odyssey · 3 readers'), findsOneWidget);
    expect(find.text('producedbyearth'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each room opens with its own canonical House identity', (
    tester,
  ) async {
    String? calendarId;
    int? flowId;
    await tester.pumpWidget(
      MaterialApp(
        home: ReadingHouseInboxRoomSection(
          rooms: kReadingHouseInboxMultipleRoomVisualFixtures,
          onOpenRoom: (calendar, flow) {
            calendarId = calendar;
            flowId = flow;
          },
        ),
      ),
    );
    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'reading-house-inbox-room-celestine-house-calendar-82',
        ),
      ),
    );
    expect(calendarId, 'celestine-house-calendar');
    expect(flowId, 82);
  });

  testWidgets('ended Houses have no Inbox room', (tester) async {
    final lifecycle = StreamController<CalendarInvalidated>.broadcast(
      sync: true,
    );
    addTearDown(lifecycle.close);
    final endedSummary = ReadingHouseRoomSummary(
      identity: const ReadingHouseRoomIdentity(
        calendarId: 'beloved-house-calendar',
        flowId: 93,
      ),
      title: 'Beloved',
      members: const <ReadingHouseRoomMember>[],
      memberCount: 2,
      unreadCount: 0,
      active: false,
      locked: false,
      ended: true,
      latestMessage: 'This House has ended.',
      latestMessageAt: DateTime.utc(2026, 9, 1),
    );
    await pumpPage(
      tester,
      size: const Size(390, 844),
      rooms: null,
      flowLifecycleStream: lifecycle.stream,
      roomDataSource: _VisualRoomDataSource(
        summaries: <ReadingHouseRoomSummary>[
          _VisualRoomDataSource.summary,
          endedSummary,
        ],
      ),
    );
    lifecycle.add(
      const CalendarInvalidated(
        reason: CalendarInvalidationReason.flowEndedCommitted,
        flowId: 93,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ReadingHouseInboxRoomRow), findsOneWidget);
    expect(find.text('The Reading House'), findsOneWidget);
    expect(find.text('Beloved'), findsNothing);
    expect(find.textContaining('ended'), findsNothing);
  });

  testWidgets('loading and error remain dedicated room-section states', (
    tester,
  ) async {
    for (final state in const <ReadingHouseInboxSectionStatus>[
      ReadingHouseInboxSectionStatus.loading,
      ReadingHouseInboxSectionStatus.error,
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: ReadingHouseInboxRoomSection(
            rooms: const <ReadingHouseInboxRoomFixture>[],
            status: state,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });

  for (final fixture
      in <(String, Size, double, List<ReadingHouseInboxRoomFixture>, bool)>[
        (
          'minimum',
          const Size(320, 700),
          1,
          const <ReadingHouseInboxRoomFixture>[
            kReadingHouseInboxRoomVisualFixture,
          ],
          false,
        ),
        (
          'mockup',
          const Size(390, 844),
          1,
          const <ReadingHouseInboxRoomFixture>[
            kReadingHouseInboxRoomVisualFixture,
          ],
          false,
        ),
        (
          'large',
          const Size(430, 932),
          1,
          const <ReadingHouseInboxRoomFixture>[
            kReadingHouseInboxRoomVisualFixture,
          ],
          false,
        ),
        (
          'accessible',
          const Size(390, 844),
          1.35,
          const <ReadingHouseInboxRoomFixture>[
            kReadingHouseInboxRoomVisualFixture,
          ],
          false,
        ),
        (
          'multiple',
          const Size(390, 844),
          1,
          kReadingHouseInboxMultipleRoomVisualFixtures,
          false,
        ),
        (
          'pending-invite',
          const Size(390, 844),
          1,
          const <ReadingHouseInboxRoomFixture>[
            kReadingHouseInboxRoomVisualFixture,
          ],
          true,
        ),
      ]) {
    testWidgets('actual Reading House Inbox visual ${fixture.$1}', (
      tester,
    ) async {
      await pumpPage(
        tester,
        size: fixture.$2,
        textScale: fixture.$3,
        rooms: fixture.$4,
        showPendingInvite: fixture.$5,
      );
      expect(tester.takeException(), isNull);
      final goldenPath = fixture.$1 == 'mockup'
          ? '$_goldenRoot/reading-house-inbox-390x844.png'
          : fixture.$1 == 'multiple'
          ? '$_goldenRoot/reading-house-inbox-multiple-390x844.png'
          : fixture.$1 == 'pending-invite'
          ? '$_goldenRoot/reading-house-inbox-pending-invite-390x844.png'
          : _captureReadingHouseInboxVisuals
          ? '/tmp/reading-house-inbox-${fixture.$1}.png'
          : null;
      if (goldenPath != null) {
        await expectLater(
          find.byKey(_captureKey),
          matchesGoldenFile(goldenPath),
        );
      }
    });
  }

  testWidgets('actual Reading House Inbox visual House Chat', (tester) async {
    await pumpPage(tester, size: const Size(390, 844));
    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'reading-house-inbox-room-odyssey-house-calendar-41',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('House Chat'), findsWidgets);
    await expectLater(
      find.byKey(_captureKey),
      matchesGoldenFile('$_goldenRoot/reading-house-inbox-chat-390x844.png'),
    );
  });
}
