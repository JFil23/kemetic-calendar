import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flow_appearance.dart';
import 'package:mobile/features/calendar/presentation/user_flow_appearance_visual.dart';
import 'package:mobile/features/shared_practice/presentation/group_flow_ui_preview.dart';

const _captureGroupFlowUi = bool.fromEnvironment('CAPTURE_GROUP_FLOW_UI');

void main() {
  test('live group room refreshes from room-scoped message changes', () {
    final repo = File('lib/data/shared_practice_repo.dart').readAsStringSync();
    final room = File(
      'lib/features/shared_practice/shared_practice_room_page.dart',
    ).readAsStringSync();

    expect(repo, contains('watchSharedPracticeChanges'));
    expect(repo, contains("table: 'shared_practice_messages'"));
    expect(repo, contains("table: 'shared_practice_rooms'"));
    expect(repo, contains("table: 'shared_practice_room_members'"));
    expect(repo, contains("column: 'room_id'"));
    expect(repo, contains("'p_public': isPublic"));
    expect(repo, isNot(contains("'p_public_identity': isPublic")));
    expect(repo, contains('watchTogetherInboxChanges'));
    expect(repo, contains("table: 'shared_practice_join_requests'"));
    expect(room, contains('_repo.watchSharedPracticeChanges'));
    expect(room, contains('roomChanges(widget.roomId)'));
    expect(room, contains('_messageRefreshDebounce'));
    expect(room, contains('_messageChangesSubscription?.cancel()'));

    final surface = File(
      'lib/features/shared_practice/presentation/group_flow_ui_preview.dart',
    ).readAsStringSync();
    expect(
      surface,
      contains('imageOpacityOverride: appearance.hasImage ? 0.16 : null'),
    );
    expect(surface, contains('showSignVisual: false'));
    expect(surface, contains("'group-flow-compact-merkhet'"));
  });

  testWidgets('group chat message header fits a small phone at 1.3x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(
          body: GroupFlowChatSurface(
            flowTitle: 'Dawn Strength Practice',
            positionLabel: 'Day 12 of 30 · host position',
            appearance: FlowAppearance.empty,
            accent: const Color(0xFF6F93A8),
            memberInitials: const <String>['AA', 'BB'],
            memberCount: 2,
            messages: const <GroupFlowChatMessagePreview>[
              GroupFlowChatMessagePreview(
                id: 'long-message',
                author: 'A very long participant display name',
                initials: 'AP',
                body: 'Keeping pace together without clipping the header.',
                timeLabel: '10:42 PM',
              ),
            ],
            onPostMessage: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text('Keeping pace together without clipping the header.'),
      findsOneWidget,
    );
    if (_captureGroupFlowUi) {
      await expectLater(
        find.byKey(const ValueKey<String>('group-flow-chat-surface')),
        matchesGoldenFile('/tmp/together-small-phone-text-1.3.png'),
      );
    }
  });

  testWidgets('group flow preview exercises Flow, Feed, Commons, and Inbox', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: GroupFlowUiPreviewSheet(
            flowTitle: 'Dawn Strength Practice',
            appearance: FlowAppearance(
              signKind: FlowSignKind.palmCount,
              signLabel: 'sessions',
              accentArgb: 0xFF6F93A8,
            ),
            accent: Color(0xFF6F93A8),
            participants: <GroupFlowParticipantPreview>[
              GroupFlowParticipantPreview(id: 'amina', name: 'Amina'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('group-flow-preview-flow-page')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('group-flow-chat-surface')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('group-flow-compact-merkhet')),
      findsOneWidget,
    );
    expect(find.text('Day 12 of 30 · host position'), findsOneWidget);
    expect(find.textContaining('Host guidance'), findsNothing);
    expect(find.byType(FlowSignVisual), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('post_group_quote_preview-you-1')),
      findsOneWidget,
    );

    if (_captureGroupFlowUi) {
      await expectLater(
        find.byKey(const ValueKey<String>('group-flow-ui-preview-sheet')),
        matchesGoldenFile('/tmp/group-flow-ui-flow.png'),
      );
    }

    await tester.enterText(
      find.byKey(const ValueKey<String>('reading-house-chat-message-field')),
      'Keeping pace with you today.',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('reading-house-chat-send')),
    );
    await tester.pump();
    expect(find.text('Keeping pace with you today.'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('group-flow-preview-observed')),
    );
    await tester.pump();
    final merkhet = tester.widget<FlowSignVisual>(find.byType(FlowSignVisual));
    expect(merkhet.completedOccurrences, 12);

    final publicNameToggle = find.byKey(
      const ValueKey<String>('group-flow-preview-public-name-toggle'),
    );
    await tester.scrollUntilVisible(
      publicNameToggle,
      160,
      scrollable: find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('group-flow-preview-flow-page'),
            ),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.drag(
      find.byKey(const ValueKey<String>('group-flow-preview-flow-page')),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    await tester.tap(publicNameToggle);
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('group-flow-preview-feed')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('group-flow-preview-feed-page')),
      findsOneWidget,
    );
    expect(find.text('Together'), findsOneWidget);
    if (_captureGroupFlowUi) {
      await expectLater(
        find.byKey(const ValueKey<String>('group-flow-ui-preview-sheet')),
        matchesGoldenFile('/tmp/group-flow-ui-feed.png'),
      );
    }
    final feedTogether = find.byKey(
      const ValueKey<String>('group-flow-preview-feed-together'),
    );
    await tester.tap(feedTogether);
    await tester.pump();
    expect(find.text('Requested'), findsOneWidget);
    await tester.tap(feedTogether);
    await tester.pump();
    expect(find.text('Together'), findsOneWidget);

    final mutualToggle = find.byKey(
      const ValueKey<String>('group-flow-preview-feed-mutual-toggle'),
    );
    await tester.scrollUntilVisible(
      mutualToggle,
      180,
      scrollable: find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('group-flow-preview-feed-page'),
            ),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(mutualToggle);
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('group-flow-preview-feed-together')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('group-flow-preview-commons')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('group-flow-preview-commons-page')),
      findsOneWidget,
    );
    expect(find.text('2 members'), findsOneWidget);
    expect(find.text('Practice Together'), findsOneWidget);
    expect(find.textContaining('Likes only'), findsOneWidget);
    expect(find.textContaining('Your name is private'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('group-flow-preview-quote-post')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('group-flow-preview-quote-comment')),
      findsOneWidget,
    );

    if (_captureGroupFlowUi) {
      await expectLater(
        find.byKey(const ValueKey<String>('group-flow-ui-preview-sheet')),
        matchesGoldenFile('/tmp/group-flow-ui-commons.png'),
      );
    }

    final request = find.byKey(
      const ValueKey<String>('group-flow-preview-request'),
    );
    await tester.tap(request);
    await tester.pump();
    expect(find.text('Requested'), findsOneWidget);
    await tester.tap(request);
    await tester.pump();
    expect(find.text('Practice Together'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('group-flow-preview-inbox')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('group-flow-preview-inbox-page')),
      findsOneWidget,
    );
    expect(
      find.text('Amina wants to join Dawn Strength Practice.'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('group-flow-preview-accept')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('group-flow-preview-policy')),
      findsOneWidget,
    );
    expect(find.text('Public in Commons'), findsOneWidget);
    expect(find.text('Nobody'), findsOneWidget);
    expect(find.text('Friends of creator'), findsOneWidget);
    expect(find.text('Friends of participants'), findsOneWidget);
    expect(find.text('Anyone'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('group-flow-preview-visibility-public'),
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('group-flow-preview-audience-nobody')),
    );
    await tester.pump();

    if (_captureGroupFlowUi) {
      await expectLater(
        find.byKey(const ValueKey<String>('group-flow-ui-preview-sheet')),
        matchesGoldenFile('/tmp/group-flow-ui-inbox.png'),
      );
    }

    await tester.tap(
      find.byKey(const ValueKey<String>('group-flow-preview-commons')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dawn Strength Practice'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('group-flow-preview-request')),
      findsNothing,
    );

    expect(tester.takeException(), isNull);
  });
}
