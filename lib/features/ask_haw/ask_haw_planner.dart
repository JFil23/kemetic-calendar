import 'ask_haw_flow_contract.dart';
import 'ask_haw_models.dart';

class AskHawAllocation {
  const AskHawAllocation({
    required this.activityId,
    required this.flowId,
    required this.stepId,
    required this.title,
    required this.startUtc,
    required this.endUtc,
    required this.guidance,
    required this.reason,
    required this.sourceRevision,
    this.alternativeId,
    this.countsAsCompletion = false,
  });
  final String activityId, stepId, title, guidance, reason, sourceRevision;
  final int flowId;
  final DateTime startUtc, endUtc;
  final String? alternativeId;
  final bool countsAsCompletion;
  int get minutes => endUtc.difference(startUtc).inMinutes;
}

class AskHawPlan {
  const AskHawPlan({
    required this.allocations,
    required this.reason,
    required this.coverageRevision,
    required this.eventSnapshot,
    required this.activityRevisions,
    this.blockedReasons = const [],
    this.accountId,
  });
  final List<AskHawAllocation> allocations;
  final String reason, coverageRevision;
  final Map<String, String> eventSnapshot, activityRevisions;
  final List<String> blockedReasons;
  final String? accountId;
  bool get available => allocations.isNotEmpty;

  /// This is the pre-commit guard, not a replacement for a checked account
  /// mutation. Server-side revisions must be revalidated by the action owner.
  bool isCurrent(AskHawContext context) {
    if (context.accountId != accountId ||
        !context.coverageComplete ||
        coverageRevision.isEmpty ||
        context.coverageRevision != coverageRevision) {
      return false;
    }
    final currentWindows = _mergeWindows(context.windows);
    if (allocations.any(
      (allocation) =>
          allocation.startUtc.isBefore(context.nowUtc) ||
          !currentWindows.any(
            (window) =>
                window.valid &&
                context.covers(window) &&
                !allocation.startUtc.isBefore(window.startUtc) &&
                !allocation.endUtc.isAfter(window.endUtc),
          ),
    )) {
      return false;
    }
    final events = _eventSnapshot(context.events);
    if (events.length != eventSnapshot.length ||
        eventSnapshot.entries.any(
          (entry) => events[entry.key] != entry.value,
        )) {
      return false;
    }
    final revisions = {
      for (final activity in context.activities) activity.id: activity.revision,
    };
    return activityRevisions.entries.every(
      (entry) => revisions[entry.key] == entry.value,
    );
  }
}

/// Computes proposals only. Civil-day, DST and user time preference conversion
/// belongs to the existing timezone owner supplying UTC windows and activities.
class AskHawPlanner {
  const AskHawPlanner();
  AskHawPlan plan(AskHawContext context, {int? maxMinutes, int limit = 4}) {
    AskHawPlan result(
      List<AskHawAllocation> allocations,
      String reason,
      List<String> blocked,
    ) => AskHawPlan(
      allocations: List.unmodifiable(allocations),
      accountId: context.accountId,
      reason: reason,
      blockedReasons: List.unmodifiable(blocked),
      coverageRevision: context.coverageRevision,
      eventSnapshot: Map.unmodifiable(_eventSnapshot(context.events)),
      activityRevisions: Map.unmodifiable({
        for (final activity in context.activities)
          activity.id: activity.revision,
      }),
    );
    if (limit <= 0 || (maxMinutes != null && maxMinutes <= 0)) {
      return result([], 'Choose a positive amount of time.', []);
    }
    final windows = _mergeWindows(context.windows);
    if (windows.isEmpty ||
        windows.any((window) => !context.covers(window)) ||
        context.coverageRevision.isEmpty) {
      return result(
        [],
        'Calendar coverage is incomplete. Refresh the calendars before proposing free time.',
        [],
      );
    }
    if (context.events.any(
      (event) =>
          !event.startUtc.isUtc ||
          !event.endUtc.isUtc ||
          !event.endUtc.isAfter(event.startUtc),
    )) {
      return result(
        [],
        'An event has an unresolved time range. Review it before planning around it.',
        [],
      );
    }
    if (context.events.any(
      (event) =>
          !event.allDay &&
          !event.durationKnown &&
          windows.any((window) => event.startUtc.isBefore(window.endUtc)),
    )) {
      return result(
        [],
        'An event has no confirmed duration. Confirm its end time before planning around it.',
        [],
      );
    }
    final blocked = <String>[];
    final busy = <AskHawWindow>[
      for (final event in context.events)
        AskHawWindow(startUtc: event.startUtc, endUtc: event.endUtc),
    ];
    final activities = context.activities.toList()
      ..sort((a, b) {
        final priority = b.priority.compareTo(a.priority);
        if (priority != 0) return priority;
        final preferred = (a.preferredStartUtc ?? context.nowUtc).compareTo(
          b.preferredStartUtc ?? context.nowUtc,
        );
        return preferred != 0 ? preferred : a.id.compareTo(b.id);
      });
    final allocations = <AskHawAllocation>[];
    final seen = <String>{};
    for (final activity in activities) {
      if (allocations.length >= limit) break;
      if (!seen.add(activity.id) || activity.paused) continue;
      final contract = activity.contract;
      final step = contract.step(activity.stepId);
      if (!contract.supported || step == null) {
        blocked.add('${activity.title}: authored assistance is unavailable.');
        continue;
      }
      if (activity.completions[step.id] == AskHawCompletion.observed ||
          activity.completions[step.id] == AskHawCompletion.skipped) {
        continue;
      }
      if (!step.eligible(activity.completions)) {
        blocked.add(
          '${activity.title}: a prerequisite has not been confirmed complete.',
        );
        continue;
      }
      final choices =
          <
            ({
              int minutes,
              String guidance,
              String? alternativeId,
              bool countsAsCompletion,
            })
          >[
            if (step.minutes != null && step.minutes! > 0)
              (
                minutes: step.minutes!,
                guidance: step.guidance,
                alternativeId: null,
                countsAsCompletion: true,
              ),
            if (contract.permits(AskHawAdaptation.shorten))
              for (final alternative in step.alternatives)
                (
                  minutes: alternative.minutes,
                  guidance: alternative.guidance,
                  alternativeId: alternative.id,
                  countsAsCompletion: alternative.countsAsCompletion,
                ),
          ];
      // A duration preference orders authored choices; it never invents one or
      // changes the explicit maximum budget. Keep the unchanged default as a
      // fallback if the author did not offer a suitable shorter practice.
      final preferred = activity.preferredMinutes;
      if (preferred != null &&
          preferred > 0 &&
          preferred <= 1440 &&
          (step.minutes == null || step.minutes! > preferred)) {
        final favored =
            choices
                .where(
                  (choice) =>
                      choice.alternativeId != null &&
                      choice.minutes <= preferred,
                )
                .toList()
              ..sort((a, b) {
                final duration = b.minutes.compareTo(a.minutes);
                return duration != 0
                    ? duration
                    : a.alternativeId!.compareTo(b.alternativeId!);
              });
        choices.removeWhere((choice) => favored.contains(choice));
        choices.insertAll(0, favored);
      }
      if (choices.isEmpty) {
        blocked.add('${activity.title}: duration is unspecified.');
        continue;
      }
      AskHawAllocation? allocation;
      for (final choice in choices) {
        if (maxMinutes != null && choice.minutes > maxMinutes) continue;
        final duration = Duration(minutes: choice.minutes);
        // Try the stated preferred instant first, then the first real opening.
        final ordered = <AskHawWindow>[
          if (activity.preferredStartUtc != null)
            for (final window in windows)
              if (!activity.preferredStartUtc!.isBefore(window.startUtc) &&
                  activity.preferredStartUtc!.isBefore(window.endUtc))
                AskHawWindow(
                  startUtc: activity.preferredStartUtc!,
                  endUtc: window.endUtc,
                ),
          ...windows,
        ];
        for (final window in ordered) {
          var start = window.startUtc.isBefore(context.nowUtc)
              ? context.nowUtc
              : window.startUtc;
          while (!start.add(duration).isAfter(window.endUtc)) {
            final end = start.add(duration);
            final conflicts =
                busy.where((item) => item.overlaps(start, end)).toList()
                  ..sort((a, b) => a.endUtc.compareTo(b.endUtc));
            if (conflicts.isEmpty) {
              allocation = AskHawAllocation(
                activityId: activity.id,
                flowId: activity.flowId,
                stepId: step.id,
                title: activity.title,
                startUtc: start,
                endUtc: end,
                guidance: choice.guidance,
                alternativeId: choice.alternativeId,
                countsAsCompletion: choice.countsAsCompletion,
                sourceRevision: activity.revision,
                reason: choice.alternativeId == null
                    ? 'Fits your available time; its prerequisites are satisfied.'
                    : 'An author-approved shorter alternative fits your available time.',
              );
              break;
            }
            start = conflicts.last.endUtc;
          }
          if (allocation != null) break;
        }
        if (allocation != null) break;
      }
      if (allocation == null) {
        blocked.add(
          '${activity.title}: no eligible opening fits its approved duration.',
        );
      } else {
        allocations.add(allocation);
        busy.add(
          AskHawWindow(
            startUtc: allocation.startUtc,
            endUtc: allocation.endUtc,
          ),
        );
      }
    }
    return result(
      allocations,
      allocations.isEmpty
          ? 'No eligible activity fits the available time.'
          : 'A proposal using your available time and authored Flow guidance.',
      blocked,
    );
  }
}

Map<String, String> _eventSnapshot(Iterable<AskHawEvent> events) => {
  for (final event in events)
    event.id:
        '${event.eventRevision ?? ''}|${event.startUtc.toUtc().toIso8601String()}|'
        '${event.endUtc.toUtc().toIso8601String()}|${event.editable}|${event.flowId}',
};

List<AskHawWindow> _mergeWindows(Iterable<AskHawWindow> source) {
  final windows = source.toList();
  if (windows.any((window) => !window.valid)) return [];
  windows.sort((a, b) => a.startUtc.compareTo(b.startUtc));
  final merged = <AskHawWindow>[];
  for (final window in windows) {
    if (merged.isNotEmpty && !window.startUtc.isAfter(merged.last.endUtc)) {
      final last = merged.removeLast();
      merged.add(
        AskHawWindow(
          startUtc: last.startUtc,
          endUtc: window.endUtc.isAfter(last.endUtc)
              ? window.endUtc
              : last.endUtc,
        ),
      );
    } else {
      merged.add(window);
    }
  }
  return merged;
}
