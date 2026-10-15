import 'package:flutter/foundation.dart';
import '../../data/commons_question_selection.dart';
import '../nodes/kemetic_node_library.dart';
import 'pages_models.dart';

/// Public, bundled material only. This projection never enters an account cache
/// or invents events, memberships, unread counts or saved account records.
class GuestPagesContent {
  GuestPagesContent(DateTime now)
    : cards = [
        for (final destination in PagesDestination.values)
          ValueNotifier(_card(destination, now)),
      ];

  final List<ValueNotifier<PagesCard>> cards;

  static PagesCard _card(PagesDestination destination, DateTime now) {
    final node = KemeticNodeLibrary.resolve('haw')!;
    return switch (destination) {
      PagesDestination.calendar => PagesCard(
        destination,
        state: PagesLoadState.ready,
        calendarDate: now,
        meta: 'Follow the turning of the year',
      ),
      PagesDestination.feed => PagesCard(
        destination,
        state: PagesLoadState.ready,
        question: activeCommonsQuestion(null, now),
        feedAnswerSummary: 'Sign in to join the Commons',
        meta: 'A question for today',
      ),
      PagesDestination.studio => PagesCard(
        destination,
        state: PagesLoadState.ready,
        primary: const PagesSignal(
          'Explore Ma’at flows',
          detail: 'Make room for what matters',
        ),
        meta: 'Sky · nourishment · reading · stability · imagination',
      ),
      PagesDestination.library => PagesCard(
        destination,
        state: PagesLoadState.ready,
        libraryNodeId: node.id,
        primary: PagesSignal(node.title, glyph: node.glyph),
        meta: 'Explore the Kemetic library',
      ),
      PagesDestination.planner => PagesCard(
        destination,
        state: PagesLoadState.ready,
        plannerDisplay: PagesPlannerDisplay.note,
        primary: const PagesSignal(
          'Make room for your rhythm',
          label: 'Planner',
        ),
        meta: 'Create an account to plan your days',
      ),
      PagesDestination.journal => PagesCard(
        destination,
        state: PagesLoadState.ready,
        meta: 'Create an account to keep your reflections',
      ),
      PagesDestination.inbox => PagesCard(
        destination,
        state: PagesLoadState.ready,
        primary: const PagesSignal(
          'Practice together',
          detail: 'Invitations and conversations',
        ),
        meta: 'Create an account to connect',
      ),
      PagesDestination.calendars => PagesCard(
        destination,
        state: PagesLoadState.ready,
        primary: const PagesSignal(
          'Time, held together',
          detail: 'Your calendars, in one place',
        ),
        meta: 'Create an account to connect your calendars',
      ),
    };
  }

  List<PagesSearchRecord> searchRecords() => [
    for (final node in KemeticNodeLibrary.nodes)
      PagesSearchRecord(node.title, 'Library', '/nodes/${node.id}'),
    const PagesSearchRecord(
      'Ma’at Flows',
      'Flow Studio',
      '/flows?mode=maatFlows',
    ),
    const PagesSearchRecord('Calendar', 'Calendar', '/'),
  ];

  void refresh(DateTime now) {
    for (final card in cards) {
      card.value = _card(card.value.destination, now);
    }
  }

  void dispose() {
    for (final card in cards) {
      card.dispose();
    }
  }
}
