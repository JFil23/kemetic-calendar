import '../../data/share_models.dart';
import 'pages_models.dart';
import '../../data/commons_models.dart';
import '../../data/shared_practice_models.dart';

bool isPagesJoinable(CommonsPracticeRoom r) =>
    r.viewerCanRequestJoin &&
    !r.viewerIsMember &&
    r.viewerRequestStatus != 'pending' &&
    r.viewerRequestStatus != 'blocked' &&
    r.joinPolicy != SharedPracticeJoinPolicy.closed &&
    r.status == 'active' &&
    r.visibility == SharedPracticeRoomVisibility.public;
PagesSignal pagesCommonsSignal(CommonsPracticeRoom? room) => PagesSignal(
  room?.title ?? 'Find a group',
  label: 'Commons',
  detail: room == null ? '' : 'Practice together',
);

class PagesEventWindow {
  const PagesEventWindow(this.events, this.end);
  final List<PagesUpcomingEvent> events;
  final DateTime end;
}

class PagesFeedCandidate {
  const PagesFeedCandidate({
    required this.flow,
    required this.at,
    required this.reason,
    this.unresolved = false,
    this.joinable = false,
    this.ownShared = false,
    this.actor = '',
    this.actorId,
  });
  final PagesFlow flow;
  final DateTime at;
  final String reason, actor;
  final String? actorId;
  final bool unresolved, joinable, ownShared;
}

PagesFeedCandidate? selectPagesFeed(Iterable<PagesFeedCandidate> records) {
  final rows = records.toList()..sort((a, b) => b.at.compareTo(a.at));
  for (final predicate in <bool Function(PagesFeedCandidate)>[
    (r) => r.unresolved,
    (r) => r.joinable,
    (r) => r.ownShared,
  ]) {
    for (final row in rows) {
      if (predicate(row)) return row;
    }
  }
  return null;
}

class PagesUpcomingEvent {
  const PagesUpcomingEvent({
    required this.flowId,
    required this.title,
    required this.at,
  });
  final String flowId, title;
  final DateTime at;
}

({PagesFlow? flow, PagesUpcomingEvent? event}) selectPagesStudio(
  List<PagesFlow> flows,
  List<PagesUpcomingEvent> events,
  DateTime now,
) {
  final remaining = flows
      .where((f) => f.total == 0 || f.completed < f.total)
      .toList();
  final upcoming = events.where((e) => !e.at.isBefore(now)).toList()
    ..sort((a, b) => a.at.compareTo(b.at));
  for (final event in upcoming) {
    for (final flow in remaining) {
      if (flow.id == event.flowId) return (flow: flow, event: event);
    }
  }
  return (
    flow: remaining.where((f) => f.total > f.completed).firstOrNull,
    event: null,
  );
}

class PagesPlannerItem {
  const PagesPlannerItem(
    this.title, {
    this.at,
    this.done = false,
    required this.isNutrition,
  });
  final String title;
  final DateTime? at;
  final bool done, isNutrition;
}

PagesPlannerItem? selectPagesPlanner(
  Iterable<PagesPlannerItem> records,
  DateTime now,
) {
  final todos = records.where((r) => !r.done && !r.isNutrition).toList()
    ..sort(
      (a, b) => (a.at ?? DateTime(9999)).compareTo(b.at ?? DateTime(9999)),
    );
  if (todos.isNotEmpty) return todos.first;
  final nutrition =
      records
          .where(
            (r) =>
                !r.done &&
                r.isNutrition &&
                r.at != null &&
                !r.at!.isBefore(now),
          )
          .toList()
        ..sort((a, b) => a.at!.compareTo(b.at!));
  return nutrition.firstOrNull;
}

/// The subject is the other person, so outgoing actions cannot be attributed to them.
String pagesShareUpdateLabel(InboxShareItem share, String viewerId) {
  final outgoing = share.senderId == viewerId;
  if (share.responseStatus == EventInviteResponseStatus.declined) {
    return outgoing
        ? 'Declined your invitation'
        : 'You declined the invitation';
  }
  if (share.responseStatus == EventInviteResponseStatus.accepted ||
      share.importedAt != null) {
    return outgoing
        ? 'Accepted your invitation'
        : 'You accepted the invitation';
  }
  return switch (share.kind) {
    InboxShareKind.flow =>
      outgoing ? 'You shared a flow' : 'Shared a flow with you',
    InboxShareKind.event =>
      outgoing ? 'You sent an event' : 'Invited you to an event',
    InboxShareKind.calendar =>
      outgoing ? 'You sent an invitation' : 'Invited you to a calendar',
    InboxShareKind.message =>
      outgoing ? 'You sent a message' : 'Sent you a message',
  };
}
