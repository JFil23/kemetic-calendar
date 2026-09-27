import 'package:mobile/data/share_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flow_appearance.dart';
import 'package:mobile/data/commons_models.dart';
import 'package:mobile/data/shared_practice_models.dart';
import 'package:mobile/features/pages/pages_arrangement.dart';
import 'package:mobile/features/pages/pages_models.dart';
import 'package:mobile/features/rhythm/planner/planner_overview.dart';
import 'package:mobile/features/rhythm/models/rhythm_models.dart';

const flow = PagesFlow(
  id: '1',
  name: 'Actual flow',
  appearance: FlowAppearance(signKind: FlowSignKind.shen),
  total: 20,
  completed: 12,
);
void main() {
  test('Inbox share wording preserves direction, kind and response', () {
    InboxShareItem share({
      bool outgoing = false,
      EventInviteResponseStatus response = EventInviteResponseStatus.noResponse,
    }) => InboxShareItem(
      shareId: 's',
      kind: InboxShareKind.flow,
      recipientId: outgoing ? 'other' : 'me',
      senderId: outgoing ? 'me' : 'other',
      payloadId: 'p',
      title: 'Real flow',
      createdAt: DateTime(2026),
      responseStatus: response,
    );
    expect(pagesShareUpdateLabel(share(), 'me'), 'Shared a flow with you');
    expect(
      pagesShareUpdateLabel(share(outgoing: true), 'me'),
      'You shared a flow',
    );
    expect(
      pagesShareUpdateLabel(
        share(outgoing: true, response: EventInviteResponseStatus.accepted),
        'me',
      ),
      'Accepted your invitation',
    );
    expect(
      pagesShareUpdateLabel(
        share(outgoing: true, response: EventInviteResponseStatus.declined),
        'me',
      ),
      'Declined your invitation',
    );
  });

  test('new join request outranks older unseen like across activity types', () {
    final selected = selectPagesFeed([
      PagesFeedCandidate(
        flow: flow,
        at: DateTime(2026, 9, 25),
        reason: 'Liked',
        unresolved: true,
      ),
      PagesFeedCandidate(
        flow: flow,
        at: DateTime(2026, 9, 26),
        reason: 'Wants to join',
        unresolved: true,
      ),
      PagesFeedCandidate(
        flow: flow,
        at: DateTime(2026, 9, 27),
        reason: 'Public',
        joinable: true,
      ),
    ]);
    expect(selected!.reason, 'Wants to join');
  });
  test('public visibility does not imply join eligibility', () {
    CommonsPracticeRoom room({
      bool eligible = true,
      bool member = false,
      String? request,
      String status = 'active',
      SharedPracticeJoinPolicy policy = SharedPracticeJoinPolicy.ownerApproval,
    }) => CommonsPracticeRoom(
      id: 'r',
      calendarId: 'c',
      sourceFlowId: 1,
      createdBy: 'other',
      title: 'Group',
      status: status,
      visibility: SharedPracticeRoomVisibility.public,
      joinPolicy: policy,
      viewerCanRequestJoin: eligible,
      viewerIsMember: member,
      viewerRequestStatus: request,
    );
    expect(isPagesJoinable(room()), isTrue);
    for (final r in [
      room(eligible: false),
      room(member: true),
      room(request: 'pending'),
      room(request: 'blocked'),
      room(policy: SharedPracticeJoinPolicy.closed),
      room(status: 'closed'),
    ]) {
      expect(isPagesJoinable(r), isFalse);
    }
    expect(pagesCommonsSignal(room()).label, 'Commons');
    expect(pagesCommonsSignal(room()).title, 'Group');
    expect(pagesCommonsSignal(null).title, 'Find a group');
  });
  test('planner chooses an open todo, then future nutrition, never a flow', () {
    final now = DateTime(2026, 9, 26, 12);
    final food = PagesPlannerItem(
      'Nutrition',
      isNutrition: true,
      at: now.add(const Duration(hours: 1)),
    );
    final todo = PagesPlannerItem(
      'Commitment',
      isNutrition: false,
      at: now.add(const Duration(hours: 2)),
    );
    expect(selectPagesPlanner([food, todo], now), same(todo));
    expect(
      selectPagesPlanner([
        const PagesPlannerItem('Done', done: true, isNutrition: false),
        food,
      ], now),
      same(food),
    );
    expect(
      selectPagesPlanner([
        PagesPlannerItem(
          'Past food',
          isNutrition: true,
          at: now.subtract(const Duration(hours: 1)),
        ),
      ], now),
      isNull,
    );
  });
  test(
    'studio chooses earliest scheduled flow and never invents an unscheduled fallback',
    () {
      final now = DateTime(2026, 9, 26);
      const other = PagesFlow(
        id: '2',
        name: 'Later',
        appearance: FlowAppearance.empty,
        total: 30,
        completed: 2,
      );
      final next = PagesUpcomingEvent(
        flowId: '1',
        title: 'Practice',
        at: now.add(const Duration(hours: 1)),
      );
      final selected = selectPagesStudio(
        [other, flow],
        [
          PagesUpcomingEvent(
            flowId: '2',
            title: 'Later',
            at: now.add(const Duration(days: 1)),
          ),
          next,
        ],
        now,
      );
      expect(selected.flow, same(flow));
      expect(selected.event, same(next));
      expect(selectPagesStudio([flow], [], now).flow, isNull);
      expect(
        selectPagesStudio(
          [
            const PagesFlow(
              id: 'done',
              name: 'Done',
              appearance: FlowAppearance.empty,
              total: 10,
              completed: 10,
            ),
          ],
          [],
          now,
        ).flow,
        isNull,
      );
    },
  );
  test('planner weighting matches done partial and pending with fallback', () {
    expect(
      plannerCompletion([
        RhythmItemState.done,
        RhythmItemState.partial,
        RhythmItemState.pending,
      ], []),
      .5,
    );
    expect(plannerCompletion([], [RhythmItemState.done]), 1);
    expect(plannerCompletion([], []), 0);
  });
}
