import 'package:flutter/foundation.dart';
import '../../data/flow_appearance.dart';

enum PagesDestination {
  calendar,
  feed,
  planner,
  journal,
  studio,
  inbox,
  calendars,
  library,
}

enum PagesLoadState { absent, loading, ready, failed }

@immutable
class PagesPerson {
  const PagesPerson(this.name, {this.glyphIds = const []});
  final String name;
  final List<String> glyphIds;
}

@immutable
class PagesSignal {
  const PagesSignal(
    this.title, {
    this.label = '',
    this.detail = '',
    this.glyph = '',
    this.status = '',
    this.color = 0xffd4af37,
    this.progress,
    this.glyphIds = const [],
    this.people = const [],
  });
  final String title, label, detail, glyph, status;
  final int color;
  final double? progress;
  final List<String> glyphIds;
  final List<PagesPerson> people;
}

@immutable
class PagesFlow {
  const PagesFlow({
    required this.id,
    required this.name,
    required this.appearance,
    this.color = 0xffd4af37,
    this.completed = 0,
    this.total = 0,
    this.start,
    this.end,
    this.imageBytes,
    this.maatKey,
  });
  final String id, name;
  final String? maatKey;
  final FlowAppearance appearance;
  final int color, completed, total;
  final DateTime? start, end;
  final Uint8List? imageBytes;
}

@immutable
class PagesCalendarDay {
  const PagesCalendarDay(
    this.day, {
    this.today = false,
    this.past = false,
    this.colors = const [],
  });
  final int day;
  final bool today, past;
  final List<int> colors;
}

@immutable
class PagesCard {
  const PagesCard(
    this.destination, {
    this.state = PagesLoadState.absent,
    this.meta = '',
    this.primary = const PagesSignal(''),
    this.upper = const PagesSignal(''),
    this.lower = const PagesSignal(''),
    this.flow,
    this.days = const [],
    this.weekdays = const [],
    this.week = const [],
    this.calendars = const [],
    this.unread = 0,
  });
  final PagesDestination destination;
  final PagesLoadState state;
  final String meta;
  final PagesSignal primary, upper, lower;
  final PagesFlow? flow;
  final List<PagesCalendarDay> days;
  final List<String> weekdays;
  final List<bool> week;
  final List<({int color, bool visible})> calendars;
  final int unread;
  String get title => switch (destination) {
    PagesDestination.calendar => 'Calendar',
    PagesDestination.feed => 'Feed',
    PagesDestination.planner => 'Planner',
    PagesDestination.journal => 'Journal',
    PagesDestination.studio => 'Flow Studio',
    PagesDestination.inbox => 'Inbox',
    PagesDestination.calendars => 'Calendars',
    PagesDestination.library => 'Library',
  };
}

@immutable
class PagesSearchRecord {
  const PagesSearchRecord(this.title, this.category, this.location);
  final String title, category, location;
}
