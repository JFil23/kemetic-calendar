import 'ask_haw_catalog.dart';
import 'ask_haw_flow_contract.dart';
import 'ask_haw_memory.dart';
import 'ask_haw_models.dart';
import 'ask_haw_planner.dart';
import 'ask_haw_recognizer.dart';
import 'ask_haw_response.dart';

/// Deterministic decisions and authored answers. This class performs no reads,
/// writes, network requests, notifications, or background work.
class AskHawEngine {
  const AskHawEngine();

  AskHawResponse respond(
    AskHawRequest request, {
    AskHawCatalog? catalog,
    AskHawContext? context,
    AskHawMemory? memory,
    int limit = 2,
    DateTime? nowUtc,
  }) {
    final content = catalog ?? buildAskHawCatalog();
    switch (request.intent) {
      case AskHawIntent.event:
        return const AskHawResponse(
          title: 'Add this to your calendar',
          options: [AskHawOption(id: 'event:add', label: 'Add as event')],
        );
      case AskHawIntent.clarify:
        if (request.query == 'reading goal') {
          return const AskHawResponse(
            title: 'What would you like to do?',
            kind: AskHawResponseKind.choices,
            options: [
              AskHawOption(id: 'correction:find', label: 'Find a reading Flow'),
              AskHawOption(
                id: 'correction:event',
                label: 'Add reading to my calendar',
              ),
            ],
          );
        }
        return _help;
      case AskHawIntent.unsupported:
        return const AskHawResponse(
          title: 'Try a more specific request',
          body:
              'I can find Flows and Library readings, explain Library topics, and help with supported calendar actions.',
          kind: AskHawResponseKind.choices,
          options: [
            AskHawOption(id: 'help', label: 'See examples'),
            AskHawOption(
              id: 'event:add',
              label: 'Add as event',
              secondary: true,
            ),
          ],
        );
      case AskHawIntent.preferences:
        return const AskHawResponse(
          title: 'What ḥꜣw remembers',
          body:
              'Review your confirmed phrases, preferences and hidden suggestions.',
          options: [
            AskHawOption(id: 'memory:settings', label: 'Manage memory'),
          ],
        );
      case AskHawIntent.find:
        return _find(
          request,
          content,
          memory,
          limit,
          context?.nowUtc ?? nowUtc,
        );
      case AskHawIntent.explain:
        return _explain(request, content, memory);
      case AskHawIntent.fit:
        return _fit(request, content, context, memory, limit, nowUtc);
      case AskHawIntent.plan:
        return _plan(request, context, memory);
      case AskHawIntent.next:
        return _next(context, content);
      case AskHawIntent.move:
      case AskHawIntent.shorten:
      case AskHawIntent.skip:
        return _eventAction(request, context, content);
      case AskHawIntent.pause:
      case AskHawIntent.resume:
        return _flowAction(request, context, content);
    }
  }

  AskHawResponse _find(
    AskHawRequest request,
    AskHawCatalog catalog,
    AskHawMemory? memory,
    int limit,
    DateTime? nowUtc,
  ) {
    final confirmed = request.contentId == null
        ? null
        : catalog.byId(request.contentId!);
    if (confirmed != null) {
      return _results(
        [
          AskHawMatch(
            content: confirmed,
            score: 100,
            reason: 'Uses the meaning you confirmed for this phrase.',
          ),
        ],
        title: 'Here is what I found',
        limit: limit,
      );
    }
    final normalized = normalizeAskHaw(request.query);
    if (normalized == 'time for a personal activity' ||
        normalized.isEmpty ||
        const {'flow', 'flows', 'a flow'}.contains(normalized)) {
      return AskHawResponse(
        title: normalized.contains('activity')
            ? 'What would you like time for?'
            : 'What interests you?',
        body: normalized.contains('activity')
            ? 'Name an activity, or tell me how many minutes you have.'
            : 'Name a topic and I will look through the available Flows and Library.',
        kind: AskHawResponseKind.choices,
        options: const [
          AskHawOption(id: 'input:Find reading flows', label: 'Reading'),
          AskHawOption(id: 'input:Find sky flows', label: 'Sky and seasons'),
          AskHawOption(
            id: 'input:I have 10 minutes',
            label: 'I have 10 minutes',
          ),
        ],
      );
    }
    final flowOnly = RegExp(
      r'\bflows?\b',
    ).hasMatch(normalizeAskHaw(request.raw));
    final source = flowOnly
        ? AskHawCatalog(
            catalog.entries.where(
              (value) => value.kind != AskHawContentKind.library,
            ),
          )
        : catalog;
    final bound = request.contentId == null
        ? null
        : source.byId(request.contentId!);
    final matches = bound == null
        ? source.search(
            request.query,
            memory: memory,
            limit: limit + 1,
            nowUtc: nowUtc,
          )
        : [
            AskHawMatch(
              content: bound,
              score: 100,
              reason: 'Uses the meaning you confirmed for this phrase.',
            ),
          ];
    return _results(
      matches,
      limit: limit,
      title: 'Here is what I found',
      empty:
          'No matching content is available in the catalog I can access. Try another topic or search your shared content.',
    );
  }

  AskHawResponse _explain(
    AskHawRequest request,
    AskHawCatalog catalog,
    AskHawMemory? memory,
  ) {
    final bound = request.contentId == null
        ? null
        : catalog.byId(request.contentId!);
    final matches = bound == null
        ? catalog.search(
            request.query,
            memory: memory,
            kind: AskHawContentKind.library,
            limit: 3,
          )
        : [
            AskHawMatch(
              content: bound,
              score: 100,
              reason: 'Uses your confirmed phrase.',
            ),
          ];
    if (matches.isEmpty) {
      return const AskHawResponse(
        title: 'I do not have an authored explanation for that yet',
        body: 'Try a Library topic, or look for related Flows.',
        kind: AskHawResponseKind.unavailable,
        options: [AskHawOption(id: 'help', label: 'See examples')],
      );
    }
    if (matches.length > 1 && matches[0].score == matches[1].score) {
      return _results(matches, limit: 2, title: 'Which topic did you mean?');
    }
    final match = matches.first;
    return AskHawResponse(
      title: match.content.title,
      body: match.content.explanation ?? match.content.summary,
      options: [
        AskHawOption(
          id: match.content.optionId,
          label: 'Read in Library',
          detail: match.content.commitment,
        ),
      ],
    );
  }

  AskHawResponse _fit(
    AskHawRequest request,
    AskHawCatalog catalog,
    AskHawContext? context,
    AskHawMemory? memory,
    int limit,
    DateTime? nowUtc,
  ) {
    final minutes = request.minutes ?? memory?.preferredDurationMinutes;
    if (minutes == null || minutes <= 0 || minutes > 1440) {
      return const AskHawResponse(
        title: 'How much time do you have?',
        kind: AskHawResponseKind.choices,
        options: [
          AskHawOption(id: 'input:I have 10 minutes', label: '10 minutes'),
          AskHawOption(id: 'input:I have 20 minutes', label: '20 minutes'),
        ],
      );
    }
    if (memory?.suggestionsEnabled == false) {
      return const AskHawResponse(
        title: 'Suggestions are turned off',
        body:
            'You can still find a specific Flow or ask about a Library topic.',
        kind: AskHawResponseKind.unavailable,
        options: [
          AskHawOption(id: 'memory:settings', label: 'Manage preferences'),
        ],
      );
    }
    // Existing occurrences come first. A one-hour display fallback, an all-day
    // event, or missing source duration cannot become time-budget evidence.
    if (context != null) {
      final upcoming =
          context.events.where((event) {
            final flow = event.flowId == null
                ? null
                : catalog.byId('flow:${event.flowId}');
            final duration = event.endUtc.difference(event.startUtc).inMinutes;
            return flow != null &&
                flow.active &&
                !flow.paused &&
                event.durationKnown &&
                !event.allDay &&
                event.endUtc.isAfter(context.nowUtc) &&
                duration > 0 &&
                duration <= minutes &&
                event.completion != AskHawCompletion.observed &&
                event.completion != AskHawCompletion.skipped;
          }).toList()..sort((a, b) {
            final time = a.startUtc.compareTo(b.startUtc);
            return time != 0 ? time : a.id.compareTo(b.id);
          });
      if (upcoming.isNotEmpty) {
        return AskHawResponse(
          title: 'A practice that fits $minutes minutes',
          body:
              'These are already on your calendar. Open the occurrence to continue; no extra session is added.',
          kind: AskHawResponseKind.results,
          options: [
            for (final event in upcoming.take(limit))
              AskHawOption(
                id: 'target:event:${event.id}',
                label: event.title,
                detail:
                    '${event.endUtc.difference(event.startUtc).inMinutes} minutes',
                reason: 'An existing occurrence in a Flow you already keep.',
              ),
          ],
        );
      }
    }
    // Active authored practices first; an activity cannot qualify by an assumed
    // duration. A free-time claim additionally requires full busy coverage.
    if (context != null && context.activities.isNotEmpty) {
      final proposal = const AskHawPlanner().plan(
        context,
        maxMinutes: minutes,
        limit: limit,
      );
      if (proposal.available) {
        return _proposalResponse(
          proposal,
          title: 'A practice that fits $minutes minutes',
        );
      }
    }
    final remembered = request.contentId == null
        ? null
        : catalog.byId(request.contentId!);
    final rememberedFits =
        remembered != null &&
        remembered.kind == AskHawContentKind.library &&
        remembered.durationMinutes != null &&
        remembered.durationMinutes! > 0 &&
        remembered.durationMinutes! <= minutes &&
        memory?.hiddenSuggestions.contains(remembered.id) != true;
    final matches = <AskHawMatch>[
      if (rememberedFits)
        AskHawMatch(
          content: remembered,
          score: 100,
          reason:
              'The meaning you confirmed; its ${remembered.durationMinutes}-minute reading fits your time.',
          matchedTerms: const [],
        ),
      ...catalog
          .search(
            '',
            memory: memory,
            optional: true,
            maxMinutes: minutes,
            nowUtc: context?.nowUtc ?? nowUtc,
            kind: AskHawContentKind.library,
            limit: limit + 1,
          )
          .where(
            (match) => !rememberedFits || match.content.id != remembered.id,
          ),
    ];
    return _results(
      matches,
      limit: limit,
      title: 'For your $minutes minutes',
      empty:
          'I could not find a reading with a known duration that fits. Try a little more time.',
      body:
          'These reading estimates fit your budget. They do not reserve calendar time.',
    );
  }

  AskHawResponse _plan(
    AskHawRequest request,
    AskHawContext? context,
    AskHawMemory? memory,
  ) {
    if (context == null) return _needsCalendar;
    final proposal = const AskHawPlanner().plan(context);
    if (!proposal.available) {
      return AskHawResponse(
        title: 'No plan is ready yet',
        body: proposal.reason,
        kind: AskHawResponseKind.unavailable,
        options: const [
          AskHawOption(id: 'calendar:open', label: 'Open Calendar'),
          AskHawOption(
            id: 'input:Find a flow',
            label: 'Explore Flows',
            secondary: true,
          ),
        ],
      );
    }
    return _proposalResponse(proposal, title: 'A plan to review');
  }

  AskHawResponse _next(AskHawContext? context, AskHawCatalog catalog) {
    if (context == null || !context.coverageComplete) return _needsCalendar;
    final future =
        context.events
            .where(
              (event) =>
                  event.endUtc.isAfter(context.nowUtc) &&
                  event.completion != AskHawCompletion.observed &&
                  event.completion != AskHawCompletion.skipped &&
                  (context.selectedFlowId == null ||
                      event.flowId == context.selectedFlowId),
            )
            .toList()
          ..sort((a, b) {
            final start = a.startUtc.compareTo(b.startUtc);
            return start != 0 ? start : a.id.compareTo(b.id);
          });
    if (future.isEmpty && context.selectedFlowId != null) {
      final flow = catalog.byId('flow:${context.selectedFlowId}');
      if (flow != null && flow.active && !flow.paused) {
        for (final activity in context.activities) {
          if (activity.flowId != context.selectedFlowId ||
              activity.paused ||
              !activity.contract.supported) {
            continue;
          }
          final step = activity.contract.step(activity.stepId);
          if (step == null ||
              !step.eligible(activity.completions) ||
              activity.completions[step.id] == AskHawCompletion.observed ||
              activity.completions[step.id] == AskHawCompletion.skipped) {
            continue;
          }
          return AskHawResponse(
            title: step.title,
            body:
                '${step.guidance}\n\nOpen the Flow to continue. This step has not been added to your calendar.',
            options: [AskHawOption(id: flow.optionId, label: 'Open Flow')],
          );
        }
      }
    }
    if (future.isEmpty) {
      return const AskHawResponse(
        title: 'Nothing upcoming in the loaded period',
        body: 'Open Calendar to review another date or explore a Flow.',
        options: [AskHawOption(id: 'calendar:open', label: 'Open Calendar')],
      );
    }
    final event = future.first;
    return AskHawResponse(
      title: event.title,
      body: 'The next available occurrence in your loaded calendar period.',
      options: [
        AskHawOption(id: 'target:event:${event.id}', label: 'Open occurrence'),
      ],
    );
  }

  AskHawResponse _eventAction(
    AskHawRequest request,
    AskHawContext? context,
    AskHawCatalog catalog,
  ) {
    if (context == null) return _needsCalendar;
    final target = normalizeAskHaw(request.targetText ?? '');
    final useSelected = const {
      '',
      'this',
      'it',
      'this event',
      'this occurrence',
    }.contains(target);
    final matches =
        context.events
            .where(
              (event) => useSelected
                  ? event.id == context.selectedEventId
                  : normalizeAskHaw(event.title) == target ||
                        normalizeAskHaw(event.title).contains(target),
            )
            .toList()
          ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
    if (matches.isEmpty) {
      return const AskHawResponse(
        title: 'Which event did you mean?',
        body: 'Use its title, or open its occurrence first.',
        kind: AskHawResponseKind.choices,
        options: [
          AskHawOption(id: 'calendar:open', label: 'Choose in Calendar'),
        ],
      );
    }
    if (matches.length > 1) {
      return AskHawResponse(
        title: 'Choose an occurrence',
        body: 'The change applies to the occurrence you choose.',
        kind: AskHawResponseKind.choices,
        options: [
          for (final event in matches.take(4))
            AskHawOption(id: 'target:event:${event.id}', label: event.title),
        ],
      );
    }
    final event = matches.single;
    if (!event.editable) {
      return const AskHawResponse(
        title: 'This occurrence is read only',
        body:
            'Only an occurrence you have permission to change can be adjusted.',
        kind: AskHawResponseKind.unavailable,
      );
    }
    if (request.intent == AskHawIntent.skip) {
      return AskHawResponse(
        title: 'Record an explicit skip',
        body:
            'Use this occurrence’s existing completion control. No event is deleted and no completion is inferred.',
        options: [
          AskHawOption(
            id: 'target:event:${event.id}',
            label: 'Open occurrence',
          ),
        ],
      );
    }
    if (!askHawCanAdaptEvent(event, request.intent, catalog)) {
      return AskHawResponse(
        title: 'This Flow has no approved ${request.intent.name} action',
        body: 'Open its full detail to use its supported controls.',
        kind: AskHawResponseKind.unavailable,
        options: [
          AskHawOption(id: 'open:flow:${event.flowId}', label: 'Open Flow'),
        ],
      );
    }
    if (request.intent == AskHawIntent.shorten && request.minutes == null) {
      return const AskHawResponse(
        title: 'How short should the occurrence be?',
        body: 'Include a duration, such as “shorten this to 10 minutes”.',
        kind: AskHawResponseKind.choices,
      );
    }
    if (request.intent == AskHawIntent.shorten && event.flowId != null) {
      if (askHawApprovedAlternative(event, request.minutes!, catalog) == null) {
        return AskHawResponse(
          title: 'Choose an approved shorter practice',
          body:
              'This duration is not an authored alternative for this occurrence.',
          kind: AskHawResponseKind.unavailable,
          options: [
            AskHawOption(id: 'open:flow:${event.flowId}', label: 'Open Flow'),
          ],
        );
      }
    }
    if (request.intent == AskHawIntent.move && request.temporalText == null) {
      return const AskHawResponse(
        title: 'When should it move?',
        body: 'Include a date or time, such as “move this to Friday at 3pm”.',
        kind: AskHawResponseKind.choices,
      );
    }
    return AskHawResponse(
      title: '${_verb(request.intent)} ${event.title}',
      body: 'Review the occurrence and the proposed change before applying it.',
      kind: AskHawResponseKind.proposal,
      options: [
        AskHawOption(
          id: 'action:${request.intent.name}:${event.id}',
          label: 'Review change',
        ),
        AskHawOption(
          id: 'target:event:${event.id}',
          label: 'Open occurrence',
          secondary: true,
        ),
      ],
    );
  }

  AskHawResponse _flowAction(
    AskHawRequest request,
    AskHawContext? context,
    AskHawCatalog catalog,
  ) {
    if (context == null) return _needsCalendar;
    final target = normalizeAskHaw(request.targetText ?? '')
        .replaceFirst(RegExp(r'^(my|the)\s+'), '')
        .replaceFirst(RegExp(r'\s+flow$'), '');
    final selected = const {'', 'this', 'it', 'this flow'}.contains(target);
    final flows = catalog.entries
        .where(
          (value) =>
              value.kind == AskHawContentKind.flow &&
              (selected
                  ? value.flowId == context.selectedFlowId
                  : normalizeAskHaw(value.title).contains(target)),
        )
        .toList();
    if (flows.length != 1) {
      return AskHawResponse(
        title: 'Which Flow did you mean?',
        body: 'Use its title or choose its full detail first.',
        kind: AskHawResponseKind.choices,
        options: [
          for (final flow in flows.take(4))
            AskHawOption(id: flow.optionId, label: flow.title),
        ],
      );
    }
    final flow = flows.single;
    if (!flow.editable || !flow.active) {
      return AskHawResponse(
        title: 'This Flow does not offer that action',
        body: 'Open the Flow to review its current lifecycle and permissions.',
        kind: AskHawResponseKind.unavailable,
        options: [AskHawOption(id: flow.optionId, label: 'Open Flow')],
      );
    }
    final wantsPause = request.intent == AskHawIntent.pause;
    if (wantsPause == flow.paused) {
      return AskHawResponse(
        title: wantsPause
            ? 'This Flow is already paused'
            : 'This Flow is already running',
        options: [AskHawOption(id: flow.optionId, label: 'Open Flow')],
      );
    }
    return AskHawResponse(
      title: '${_verb(request.intent)} ${flow.title}',
      body: request.intent == AskHawIntent.pause
          ? 'Review the pause before applying it. Completed history stays with the Flow.'
          : 'Review how the Flow resumes before applying it.',
      kind: AskHawResponseKind.proposal,
      options: [
        AskHawOption(
          id: 'action:${request.intent.name}:${flow.flowId}',
          label: 'Review change',
        ),
      ],
    );
  }
}

AskHawResponse _results(
  List<AskHawMatch> matches, {
  required String title,
  int limit = 2,
  String? empty,
  String? body,
}) {
  if (matches.isEmpty) {
    return AskHawResponse(
      title: 'No matching content found',
      body: empty ?? 'Try another topic.',
      kind: AskHawResponseKind.unavailable,
      options: const [AskHawOption(id: 'help', label: 'See examples')],
    );
  }
  return AskHawResponse(
    title: title,
    body: body,
    kind: AskHawResponseKind.results,
    options: [
      for (final match in matches.take(limit))
        AskHawOption(
          id: match.content.optionId,
          label: match.content.title,
          detail: match.content.commitment,
          reason: match.reason,
        ),
      if (matches.length > limit)
        const AskHawOption(
          id: 'search:more',
          label: 'See more',
          secondary: true,
        ),
    ],
  );
}

AskHawResponse _proposalResponse(AskHawPlan plan, {required String title}) =>
    AskHawResponse(
      title: title,
      body: plan.reason,
      kind: AskHawResponseKind.proposal,
      options: [
        for (final item in plan.allocations)
          AskHawOption(
            id: 'proposal:${item.activityId}',
            label: item.title,
            detail: '${item.minutes} minutes · ${item.guidance}',
            reason: item.reason,
          ),
      ],
    );

String _verb(AskHawIntent intent) => switch (intent) {
  AskHawIntent.move => 'Move',
  AskHawIntent.shorten => 'Shorten',
  AskHawIntent.skip => 'Skip',
  AskHawIntent.pause => 'Pause',
  AskHawIntent.resume => 'Resume',
  _ => 'Review',
};

const _needsCalendar = AskHawResponse(
  title: 'Calendar context is needed',
  body: 'Refresh your account calendars to use this request.',
  kind: AskHawResponseKind.unavailable,
  options: [AskHawOption(id: 'calendar:open', label: 'Open Calendar')],
);

const _help = AskHawResponse(
  title: 'Ask ḥꜣw',
  body:
      'Add an event, find a Flow or reading, ask about a Library topic, or plan around your available time.',
  kind: AskHawResponseKind.choices,
  options: [
    AskHawOption(id: 'input:What is a decan?', label: 'What is a decan?'),
    AskHawOption(id: 'input:I have 10 minutes', label: 'I have 10 minutes'),
    AskHawOption(id: 'input:Help me plan today', label: 'Help me plan today'),
  ],
);

/// Shared event adaptation boundary for decisions and the final action owner.
/// Calendar permissions authorize ordinary custom-event moves; authored practice
/// changes require the Flow's optional contract. Astronomy anchors never move.
bool askHawCanAdaptEvent(
  AskHawEvent event,
  AskHawIntent intent,
  AskHawCatalog catalog,
) {
  if (!event.editable) return false;
  if (intent == AskHawIntent.skip) return true;
  if (intent != AskHawIntent.move && intent != AskHawIntent.shorten) {
    return false;
  }
  if (event.flowId == null) return true;
  final flow = catalog.byId('flow:${event.flowId}');
  if (flow == null) return false;
  if (intent == AskHawIntent.move) {
    if (flow.maatFlowKey == 'track-the-sky') return false;
    if (flow.contract == null) return flow.maatFlowKey == null;
    return flow.contract!.permits(AskHawAdaptation.reschedule);
  }
  return flow.contract?.permits(AskHawAdaptation.shorten) == true &&
      _eventStep(event, catalog)?.alternatives.isNotEmpty == true;
}

AskHawAlternative? askHawApprovedAlternative(
  AskHawEvent event,
  int minutes,
  AskHawCatalog catalog,
) {
  if (!askHawCanAdaptEvent(event, AskHawIntent.shorten, catalog)) return null;
  final alternatives =
      _eventStep(event, catalog)?.alternatives ?? const <AskHawAlternative>[];
  for (final alternative in alternatives) {
    if (alternative.minutes == minutes) return alternative;
  }
  return null;
}

AskHawStep? _eventStep(AskHawEvent event, AskHawCatalog catalog) {
  if (event.flowId == null) return null;
  final contract = catalog.byId('flow:${event.flowId}')?.contract;
  if (contract?.supported != true) return null;
  if (event.stepId != null) return contract!.step(event.stepId!);
  return contract!.steps.length == 1 ? contract.steps.single : null;
}
