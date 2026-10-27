import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/ask_haw/ask_haw_flow_contract.dart';
import 'package:mobile/features/ask_haw/ask_haw_models.dart';
import 'package:mobile/features/ask_haw/ask_haw_planner.dart';

void main() {
  final day = DateTime.utc(2026, 11, 1);
  DateTime at(int hour, [int minute = 0]) =>
      day.add(Duration(hours: hour, minutes: minute));
  AskHawContext context({
    List<AskHawEvent> events = const [],
    List<AskHawActivity> activities = const [],
    List<AskHawWindow>? windows,
    bool complete = true,
    String revision = 'coverage-1',
  }) => AskHawContext(
    nowUtc: at(8),
    timezone: 'America/Los_Angeles',
    events: events,
    activities: activities,
    windows: windows ?? [AskHawWindow(startUtc: at(9), endUtc: at(11))],
    coverageComplete: complete,
    coverageStartUtc: day,
    coverageEndUtc: day.add(const Duration(days: 1)),
    coverageRevision: revision,
  );
  AskHawActivity activity(
    String id, {
    int flow = 1,
    int? minutes = 20,
    List<String> prerequisites = const [],
    Map<String, AskHawCompletion> completions = const {},
    List<AskHawAlternative> alternatives = const [],
    Set<AskHawAdaptation> adaptations = const {},
    DateTime? preferred,
    bool paused = false,
    int priority = 0,
  }) => AskHawActivity(
    id: id,
    title: id,
    flowId: flow,
    stepId: 'practice',
    revision: 'v1',
    preferredStartUtc: preferred,
    paused: paused,
    priority: priority,
    completions: completions,
    contract: AskHawFlowContract(
      adaptations: adaptations,
      steps: [
        for (final pre in prerequisites)
          AskHawStep(
            id: pre,
            title: pre,
            guidance: 'Prerequisite.',
            minutes: 5,
          ),
        AskHawStep(
          id: 'practice',
          title: id,
          guidance: 'Authored guidance.',
          minutes: minutes,
          prerequisites: prerequisites,
          alternatives: alternatives,
        ),
      ],
    ),
  );
  const planner = AskHawPlanner();
  test('competing Flows use one schedule and preserve busy commitments', () {
    final result = planner.plan(
      context(
        events: [
          AskHawEvent(
            id: 'busy',
            title: 'Existing',
            startUtc: at(9),
            endUtc: at(9, 30),
            eventRevision: 'r1',
          ),
        ],
        activities: [activity('a', flow: 1), activity('b', flow: 2)],
      ),
    );
    expect(result.allocations, hasLength(2));
    expect(result.allocations[0].startUtc, at(9, 30));
    expect(result.allocations[1].startUtc, at(9, 50));
    expect(
      result.allocations[0].endUtc.isAfter(result.allocations[1].startUtc),
      isFalse,
    );
  });
  test('incomplete coverage and missing revisions cannot prove free time', () {
    expect(
      planner
          .plan(context(complete: false, activities: [activity('a')]))
          .available,
      isFalse,
    );
    expect(
      planner
          .plan(context(revision: '', activities: [activity('a')]))
          .available,
      isFalse,
    );
    expect(
      planner
          .plan(
            context(
              windows: [AskHawWindow(startUtc: at(23), endUtc: at(25))],
              activities: [activity('a')],
            ),
          )
          .available,
      isFalse,
    );
  });
  test('unknown and partial prerequisites do not count as observed', () {
    for (final completion in [
      AskHawCompletion.unknown,
      AskHawCompletion.partial,
      AskHawCompletion.skipped,
    ]) {
      expect(
        planner
            .plan(
              context(
                activities: [
                  activity(
                    'a',
                    prerequisites: ['prepare'],
                    completions: {'prepare': completion},
                  ),
                ],
              ),
            )
            .available,
        isFalse,
      );
    }
    expect(
      planner
          .plan(
            context(
              activities: [
                activity(
                  'a',
                  prerequisites: ['prepare'],
                  completions: {'prepare': AskHawCompletion.observed},
                ),
              ],
            ),
          )
          .available,
      isTrue,
    );
  });
  test('completed, skipped and paused activity is not proposed again', () {
    expect(
      planner
          .plan(
            context(
              activities: [
                activity('a', paused: true),
                activity(
                  'b',
                  completions: {'practice': AskHawCompletion.observed},
                ),
                activity(
                  'c',
                  completions: {'practice': AskHawCompletion.skipped},
                ),
              ],
            ),
          )
          .allocations,
      isEmpty,
    );
  });
  test(
    'unknown durations do not fit and alternatives require authored permission',
    () {
      const alternative = AskHawAlternative(
        id: 'small',
        label: 'Small return',
        minutes: 5,
        guidance: 'The approved shorter practice.',
      );
      expect(
        planner
            .plan(
              context(activities: [activity('a', minutes: null)]),
              maxMinutes: 10,
            )
            .available,
        isFalse,
      );
      expect(
        planner
            .plan(
              context(
                activities: [
                  activity('a', alternatives: [alternative]),
                ],
              ),
              maxMinutes: 10,
            )
            .available,
        isFalse,
      );
      final result = planner.plan(
        context(
          activities: [
            activity(
              'a',
              alternatives: [alternative],
              adaptations: {AskHawAdaptation.shorten},
            ),
          ],
        ),
        maxMinutes: 10,
      );
      expect(result.allocations.single.minutes, 5);
      expect(result.allocations.single.alternativeId, 'small');
      expect(
        result.allocations.single.guidance,
        'The approved shorter practice.',
      );
    },
  );
  test(
    'all-day and cross-midnight commitments remain busy over their full range',
    () {
      final result = planner.plan(
        context(
          events: [
            AskHawEvent(
              id: 'all-day',
              title: 'Away',
              startUtc: day,
              endUtc: at(24),
              allDay: true,
            ),
            AskHawEvent(
              id: 'overnight',
              title: 'Night',
              startUtc: at(-1),
              endUtc: at(10),
            ),
          ],
          activities: [activity('a')],
        ),
      );
      expect(result.available, isFalse);
    },
  );
  test('touching boundaries are free; overlapping availability is merged', () {
    final result = planner.plan(
      context(
        events: [
          AskHawEvent(
            id: 'busy',
            title: 'Existing',
            startUtc: at(8),
            endUtc: at(9),
          ),
        ],
        activities: [activity('a', minutes: 90)],
        windows: [
          AskHawWindow(startUtc: at(9), endUtc: at(10)),
          AskHawWindow(startUtc: at(9, 30), endUtc: at(11)),
        ],
      ),
    );
    expect(result.allocations.single.startUtc, at(9));
    expect(result.allocations.single.endUtc, at(10, 30));
  });
  test('preferred instant is used when free, with stable fallback', () {
    final result = planner.plan(
      context(activities: [activity('a', preferred: at(10))]),
    );
    expect(result.allocations.single.startUtc, at(10));
    final busy = AskHawEvent(
      id: 'busy',
      title: 'Existing',
      startUtc: at(10),
      endUtc: at(11),
    );
    expect(
      planner
          .plan(
            context(
              events: [busy],
              activities: [activity('a', preferred: at(10))],
            ),
          )
          .allocations
          .single
          .startUtc,
      at(9),
    );
  });
  test(
    'proposal invalidates on coverage, event time or source revision change',
    () {
      final a = activity('a');
      final original = context(
        activities: [a],
        events: [
          AskHawEvent(
            id: 'busy',
            title: 'Existing',
            startUtc: at(8),
            endUtc: at(9),
            eventRevision: 'r1',
          ),
        ],
      );
      final plan = planner.plan(original);
      expect(plan.isCurrent(original), isTrue);
      expect(
        plan.isCurrent(context(activities: [a], revision: 'coverage-2')),
        isFalse,
      );
      expect(
        plan.isCurrent(
          context(
            activities: [a],
            events: [
              AskHawEvent(
                id: 'busy',
                title: 'Existing',
                startUtc: at(8),
                endUtc: at(9, 10),
                eventRevision: 'r1',
              ),
            ],
          ),
        ),
        isFalse,
      );
      final revised = AskHawActivity(
        id: a.id,
        title: a.title,
        flowId: a.flowId,
        stepId: a.stepId,
        contract: a.contract,
        revision: 'v2',
      );
      expect(
        plan.isCurrent(context(activities: [revised], events: original.events)),
        isFalse,
      );
    },
  );
  test('UTC windows retain elapsed durations through a DST transition', () {
    final result = planner.plan(
      AskHawContext(
        nowUtc: DateTime.utc(2026, 11, 1, 7),
        timezone: 'America/Los_Angeles',
        coverageComplete: true,
        coverageStartUtc: DateTime.utc(2026, 11, 1, 7),
        coverageEndUtc: DateTime.utc(2026, 11, 2, 8),
        coverageRevision: 'fall-back',
        windows: [
          AskHawWindow(
            startUtc: DateTime.utc(2026, 11, 1, 8, 30),
            endUtc: DateTime.utc(2026, 11, 1, 10, 30),
          ),
        ],
        activities: [activity('a', minutes: 90)],
      ),
    );
    expect(result.allocations.single.minutes, 90);
    expect(
      result.allocations.single.startUtc,
      DateTime.utc(2026, 11, 1, 8, 30),
    );
    expect(result.allocations.single.endUtc, DateTime.utc(2026, 11, 1, 10));
  });
  test(
    'unknown timed duration never proves a free opening using display fallback',
    () {
      final unresolved = AskHawEvent(
        id: 'unknown',
        title: 'Unresolved',
        startUtc: at(9),
        endUtc: at(10),
        durationKnown: false,
      );
      final blocked = planner.plan(
        context(events: [unresolved], activities: [activity('a')]),
      );
      expect(blocked.available, isFalse);
      expect(blocked.reason, contains('no confirmed duration'));
      final beforeWindow = AskHawEvent(
        id: 'earlier',
        title: 'Earlier unresolved',
        startUtc: at(7),
        endUtc: at(8),
        durationKnown: false,
      );
      expect(
        planner
            .plan(context(events: [beforeWindow], activities: [activity('a')]))
            .available,
        isFalse,
      );
      final afterWindow = AskHawEvent(
        id: 'later',
        title: 'Later unresolved',
        startUtc: at(12),
        endUtc: at(13),
        durationKnown: false,
      );
      expect(
        planner
            .plan(context(events: [afterWindow], activities: [activity('a')]))
            .available,
        isTrue,
      );
    },
  );
  test(
    'personal duration preferences rank authored choices and keep explicit fit hard',
    () {
      const small = AskHawAlternative(
        id: 'small',
        label: 'Small',
        minutes: 5,
        guidance: 'A small authored return.',
        countsAsCompletion: true,
      );
      const medium = AskHawAlternative(
        id: 'medium',
        label: 'Medium',
        minutes: 10,
        guidance: 'A medium authored return.',
      );
      AskHawActivity preferred({
        int? preference,
        int? defaultMinutes = 20,
        Set<AskHawAdaptation> adaptations = const {AskHawAdaptation.shorten},
        List<AskHawAlternative> alternatives = const [small, medium],
      }) => AskHawActivity(
        id: 'preferred',
        title: 'Preferred',
        flowId: 7,
        stepId: 'practice',
        revision: 'v1',
        preferredMinutes: preference,
        contract: AskHawFlowContract(
          adaptations: adaptations,
          steps: [
            AskHawStep(
              id: 'practice',
              title: 'Practice',
              guidance: 'Full authored practice.',
              minutes: defaultMinutes,
              alternatives: alternatives,
            ),
          ],
        ),
      );
      final chosen = planner
          .plan(context(activities: [preferred(preference: 10)]))
          .allocations
          .single;
      expect(chosen.minutes, 10);
      expect(chosen.alternativeId, 'medium');
      expect(chosen.guidance, 'A medium authored return.');
      expect(chosen.countsAsCompletion, isFalse);
      final fits = planner
          .plan(context(activities: [preferred(preference: 10)]), maxMinutes: 6)
          .allocations
          .single;
      expect(fits.minutes, 5);
      expect(fits.countsAsCompletion, isTrue);
      final full = planner
          .plan(context(activities: [preferred(preference: 25)]))
          .allocations
          .single;
      expect(full.minutes, 20);
      expect(full.alternativeId, isNull);
      final unavailable = preferred(preference: 10, adaptations: {});
      expect(
        planner
            .plan(context(activities: [unavailable]))
            .allocations
            .single
            .minutes,
        20,
      );
      expect(
        planner
            .plan(context(activities: [unavailable]), maxMinutes: 10)
            .available,
        isFalse,
      );
      for (final invalid in [0, -1, 1441]) {
        expect(
          planner
              .plan(context(activities: [preferred(preference: invalid)]))
              .allocations
              .single
              .minutes,
          20,
        );
      }
    },
  );
  test(
    'future-day UTC windows stay on that day and stale clock or availability invalidates',
    () {
      final tomorrow = day.add(const Duration(days: 1));
      AskHawContext scope({DateTime? current, List<AskHawWindow>? windows}) =>
          AskHawContext(
            nowUtc: current ?? at(8),
            timezone: 'America/Los_Angeles',
            coverageComplete: true,
            coverageStartUtc: day,
            coverageEndUtc: day.add(const Duration(days: 3)),
            coverageRevision: 'future-day',
            windows:
                windows ??
                [
                  AskHawWindow(
                    startUtc: tomorrow.add(const Duration(hours: 9)),
                    endUtc: tomorrow.add(const Duration(hours: 10)),
                  ),
                ],
            activities: [activity('future', minutes: 20)],
          );
      final plan = planner.plan(scope());
      expect(
        plan.allocations.single.startUtc,
        tomorrow.add(const Duration(hours: 9)),
      );
      expect(plan.isCurrent(scope()), isTrue);
      expect(
        plan.isCurrent(
          scope(current: tomorrow.add(const Duration(hours: 9, minutes: 1))),
        ),
        isFalse,
      );
      expect(
        plan.isCurrent(
          scope(
            windows: [
              AskHawWindow(
                startUtc: tomorrow.add(const Duration(hours: 11)),
                endUtc: tomorrow.add(const Duration(hours: 12)),
              ),
            ],
          ),
        ),
        isFalse,
      );
    },
  );
  test(
    'preflight uses the same union of overlapping availability as planning',
    () {
      final scope = context(
        activities: [activity('a', minutes: 90)],
        windows: [
          AskHawWindow(startUtc: at(9), endUtc: at(10)),
          AskHawWindow(startUtc: at(9, 30), endUtc: at(11)),
        ],
      );
      final plan = planner.plan(scope);
      expect(plan.allocations.single.endUtc, at(10, 30));
      expect(plan.isCurrent(scope), isTrue);
    },
  );
  test('a plan cannot be revalidated under another account identity', () {
    AskHawContext scope(String account) => AskHawContext(
      nowUtc: at(8),
      accountId: account,
      coverageComplete: true,
      coverageStartUtc: day,
      coverageEndUtc: at(24),
      coverageRevision: 'same-data-revision',
      windows: [AskHawWindow(startUtc: at(9), endUtc: at(11))],
      activities: [activity('same-shape')],
    );
    final plan = planner.plan(scope('account-a'));
    expect(plan.isCurrent(scope('account-a')), isTrue);
    expect(plan.isCurrent(scope('account-b')), isFalse);
  });
}
