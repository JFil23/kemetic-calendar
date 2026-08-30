part of 'calendar_page.dart';

/// Compatibility route for older Calendar entry points.
///
/// Reading House editing intentionally delegates to the same visual surface and
/// [LiveReadingHouseAuthority] used by the Ma'at detail route. This keeps one
/// persistence, invitation, publication, and materialization authority while
/// the surrounding Calendar navigation is migrated independently.
class _ReadingHouseAuthoringPage extends StatelessWidget {
  const _ReadingHouseAuthoringPage({
    required this.flow,
    this.onPersisted,
    this.resizeToAvoidBottomInset = true,
  });

  final _Flow flow;
  final Future<void> Function(ReadingHouseSnapshot snapshot)? onPersisted;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final timezone = readingHouseTimeZoneFromFlowNotes(flow.notes);
    return ReadingHouseDetailPage(
      timezone: timezone,
      initialStartDate: flow.start ?? defaultReadingHouseStartDate(timezone),
      initialPlan: readingHousePlanFromFlowNotes(flow.notes),
      initialFlowId: flow.id,
      initialCalendarId: flow.calendarId,
      initiallyHeld: true,
      authority: LiveReadingHouseAuthority(Supabase.instance.client),
      resolvePersonalCalendarId: CalendarPage._loadHeadlessPersonalCalendarId,
      onPersisted: onPersisted,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }
}
