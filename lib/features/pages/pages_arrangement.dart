import 'pages_feed_rotation.dart';
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

/// Stable within a local day/edition, independent of payload ordering. Eligibility
/// is rechecked on each existing cache update; nothing is recorded as "seen".
({PagesFeedDisplay display, CommonsPracticeRoom? practice})
selectPagesFeedEdition({
  required DateTime now,
  required CommonsQuestion question,
  required CommonsHomeSnapshot commons,
}) {
  final edition = PagesFeedRotation.editionAt(now);
  final byId = <String, CommonsPracticeRoom>{};
  // Prefer the viewer-specific record when the same room appears in both lists.
  for (final room in [
    ...commons.mySharedPractices,
    ...commons.publicSharedPractices,
  ]) {
    if (room.id.isNotEmpty) byId.putIfAbsent(room.id, () => room);
  }
  final rooms =
      byId.values
          .where(
            (room) =>
                room.title.trim().isNotEmpty &&
                room.memberCount >= 2 &&
                !room.viewerCanManage &&
                room.viewerRequestStatus != 'approved' &&
                isPagesJoinable(room),
          )
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
  final day = now.toLocal();
  final seed = '${day.year}-${day.month}-${day.day}:${edition.name}';
  var hash = 0;
  for (final unit in seed.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  final room = rooms.isEmpty ? null : rooms[hash % rooms.length];
  final unanswered =
      question.question.trim().isNotEmpty &&
      question.myAnswer == null &&
      !question.answers.any((answer) => answer.isMine);
  final priorities = switch (edition) {
    PagesFeedEdition.dawn => [
      PagesFeedDisplay.question,
      PagesFeedDisplay.practice,
      PagesFeedDisplay.publicRhythm,
    ],
    PagesFeedEdition.midday => [
      PagesFeedDisplay.practice,
      PagesFeedDisplay.question,
      PagesFeedDisplay.publicRhythm,
    ],
    PagesFeedEdition.dusk => [PagesFeedDisplay.publicRhythm],
  };
  for (final display in priorities) {
    if (display == PagesFeedDisplay.question && unanswered) {
      return (display: display, practice: null);
    }
    if (display == PagesFeedDisplay.practice && room != null) {
      return (display: display, practice: room);
    }
    if (display == PagesFeedDisplay.publicRhythm) {
      return (display: display, practice: null);
    }
  }
  return (display: PagesFeedDisplay.publicRhythm, practice: null);
}

class PagesUpcomingEvent {
  const PagesUpcomingEvent({
    required this.flowId,
    required this.title,
    required this.at,
    this.id = '',
    this.clientEventId = '',
    this.calendarId = '',
    this.behavior = const {},
  });
  final String id, clientEventId, calendarId;
  final Map<String, dynamic> behavior;
  final String flowId, title;
  final DateTime at;
}

({PagesFlow? flow, PagesUpcomingEvent? event}) selectPagesStudio(
  List<PagesFlow> flows,
  List<PagesUpcomingEvent> events,
  DateTime now,
) {
  final upcoming = events.where((e) => !e.at.isBefore(now)).toList()
    ..sort((a, b) {
      final time = a.at.compareTo(b.at);
      return time == 0 ? a.id.compareTo(b.id) : time;
    });
  for (final event in upcoming) {
    for (final flow in flows) {
      if (flow.id == event.flowId) return (flow: flow, event: event);
    }
  }
  return (flow: null, event: null);
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
