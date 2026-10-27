import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/ask_haw/ask_haw_catalog.dart';
import 'package:mobile/features/ask_haw/ask_haw_engine.dart';
import 'package:mobile/features/ask_haw/ask_haw_flow_contract.dart';
import 'package:mobile/features/ask_haw/ask_haw_memory.dart';
import 'package:mobile/features/ask_haw/ask_haw_models.dart';
import 'package:mobile/features/ask_haw/ask_haw_recognizer.dart';
import 'package:mobile/features/ask_haw/ask_haw_response.dart';

void main() {
  const engine = AskHawEngine();
  const recognizer = AskHawRecognizer();
  final now = DateTime.utc(2026, 10, 27, 16);
  AskHawContext context({
    List<AskHawEvent> events = const [],
    String? selected,
    bool complete = true,
    int? flow,
  }) => AskHawContext(
    nowUtc: now,
    events: events,
    selectedEventId: selected,
    selectedFlowId: flow,
    coverageComplete: complete,
    coverageStartUtc: now,
    coverageEndUtc: now.add(const Duration(days: 1)),
  );
  test('public explanation uses canon and canonical link', () {
    final response = engine.respond(recognizer.recognize('What is a decan?'));
    expect(response.title, 'Decans');
    expect(response.body, isNotEmpty);
    expect(response.options.single.id, 'open:library:decans');
    expect(
      engine.respond(recognizer.recognize('Explain quantum gardening')).kind,
      AskHawResponseKind.unavailable,
    );
  });
  test(
    'unknown questions retain explicit event fallback without making a mutation',
    () {
      final response = engine.respond(recognizer.recognize('How do I cook?'));
      expect(response.kind, AskHawResponseKind.choices);
      expect(response.options.any((value) => value.id == 'event:add'), isTrue);
    },
  );
  test('find Flow filters Library and handles missing content honestly', () {
    final result = engine.respond(recognizer.recognize('Find reading flows'));
    expect(
      result.options.any((value) => value.id == 'open:maat:the-reading-house'),
      isTrue,
    );
    expect(
      result.options.any((value) => value.id.startsWith('open:library:')),
      isFalse,
    );
    final missing = engine.respond(
      recognizer.recognize('Find a beginner cooking Flow'),
    );
    expect(missing.kind, AskHawResponseKind.unavailable);
    expect(
      missing.options.any((value) => value.id.startsWith('open:')),
      isFalse,
    );
  });
  test(
    'reflection seeds request interests or time without inferring saved prose',
    () {
      expect(
        engine.respond(recognizer.recognize('Find a flow')).title,
        'What interests you?',
      );
      expect(
        engine
            .respond(recognizer.recognize('Find time for a personal activity'))
            .title,
        'What would you like time for?',
      );
    },
  );
  test(
    'public time budget offers only known fitting readings without a calendar claim',
    () {
      final response = engine.respond(
        recognizer.recognize('I have 10 minutes'),
      );
      expect(response.kind, AskHawResponseKind.results);
      expect(response.body, contains('do not reserve calendar time'));
      for (final option in response.options.where(
        (value) => value.id.startsWith('open:'),
      )) {
        final content = buildAskHawCatalog().byId(option.id.substring(5))!;
        expect(content.durationMinutes, lessThanOrEqualTo(10));
      }
    },
  );
  test(
    'remembered fitting reading is honored within the current real budget',
    () {
      final catalog = AskHawCatalog(const [
        AskHawContent(
          id: 'library:a',
          kind: AskHawContentKind.library,
          title: 'First reading',
          summary: 'An available reading.',
          durationMinutes: 2,
        ),
        AskHawContent(
          id: 'library:remembered',
          kind: AskHawContentKind.library,
          title: 'Chosen reading',
          summary: 'The confirmed choice.',
          durationMinutes: 8,
        ),
        AskHawContent(
          id: 'library:unknown',
          kind: AskHawContentKind.library,
          title: 'Unknown duration',
          summary: 'No estimate is authored.',
        ),
      ]);
      AskHawMemory memory(
        String id, {
        bool enabled = true,
        bool hidden = false,
      }) => AskHawMemory(
        payload: {
          'bindings': {
            for (final minutes in [5, 10])
              'i have $minutes minutes': {
                'intent': 'fit',
                'contentId': id,
                'minutes': 30,
              },
          },
          'preferences': {'suggestionsEnabled': enabled},
          if (hidden) 'hidden': [id],
        },
      );
      AskHawResponse fit(String raw, AskHawMemory saved) => engine.respond(
        recognizer.recognize(raw, memory: saved),
        catalog: catalog,
        memory: saved,
        limit: 1,
      );
      final saved = memory('library:remembered');
      final chosen = fit('I have 10 minutes', saved);
      expect(chosen.options.first.id, 'open:library:remembered');
      expect(chosen.options.first.reason, contains('meaning you confirmed'));
      expect(chosen.options.first.reason, contains('8-minute'));
      expect(chosen.body, contains('do not reserve calendar time'));

      final short = recognizer.recognize('I have 5 minutes', memory: saved);
      expect(short.minutes, 5);
      final bounded = engine.respond(short, catalog: catalog, memory: saved);
      expect(
        bounded.options.where((o) => o.id.startsWith('open:')).map((o) => o.id),
        ['open:library:a'],
      );
      expect(
        fit('I have 10 minutes', memory('library:unknown')).options.first.id,
        'open:library:a',
      );
      expect(
        fit('I have 10 minutes', memory('library:missing')).options.first.id,
        'open:library:a',
      );
      expect(
        fit(
          'I have 10 minutes',
          memory('library:remembered', hidden: true),
        ).options.first.id,
        'open:library:a',
      );
      expect(
        fit(
          'I have 10 minutes',
          memory('library:remembered', enabled: false),
        ).kind,
        AskHawResponseKind.unavailable,
      );
    },
  );

  test('disabled suggestions remain quiet while explicit lookup works', () {
    final memory = AskHawMemory(
      payload: {
        'preferences': {'suggestionsEnabled': false},
      },
    );
    expect(
      engine
          .respond(recognizer.recognize('I have 10 minutes'), memory: memory)
          .kind,
      AskHawResponseKind.unavailable,
    );
    expect(
      engine
          .respond(recognizer.recognize('What is a decan?'), memory: memory)
          .options
          .single
          .id,
      'open:library:decans',
    );
  });
  test('incomplete loaded context cannot identify the next occurrence', () {
    final event = AskHawEvent(
      id: 'a',
      title: 'Later',
      startUtc: now.add(const Duration(hours: 1)),
      endUtc: now.add(const Duration(hours: 2)),
    );
    expect(
      engine
          .respond(
            recognizer.recognize("What's next?"),
            context: context(events: [event], complete: false),
          )
          .kind,
      AskHawResponseKind.unavailable,
    );
    final response = engine.respond(
      recognizer.recognize("What's next?"),
      context: context(events: [event]),
    );
    expect(response.title, 'Later');
    expect(response.options.single.id, 'target:event:a');
  });
  test('read-only event and ambiguous target never produce action options', () {
    final a = AskHawEvent(
      id: 'a',
      title: 'Dentist',
      startUtc: now,
      endUtc: now.add(const Duration(hours: 1)),
    );
    final b = AskHawEvent(
      id: 'b',
      title: 'Dentist',
      startUtc: now.add(const Duration(days: 1)),
      endUtc: now.add(const Duration(days: 1, hours: 1)),
      editable: true,
    );
    final readonly = engine.respond(
      recognizer.recognize('move this to Friday'),
      context: context(events: [a], selected: 'a'),
    );
    expect(readonly.kind, AskHawResponseKind.unavailable);
    final ambiguous = engine.respond(
      recognizer.recognize('move Dentist to Friday'),
      context: context(events: [a, b]),
    );
    expect(ambiguous.kind, AskHawResponseKind.choices);
    expect(
      ambiguous.options.every((value) => !value.id.startsWith('action:')),
      isTrue,
    );
  });
  test(
    'Flow bound event only permits its actual authored duration alternative',
    () {
      const contract = AskHawFlowContract(
        adaptations: {AskHawAdaptation.shorten},
        steps: [
          AskHawStep(
            id: 'practice',
            title: 'Practice',
            guidance: 'Main practice.',
            minutes: 20,
            alternatives: [
              AskHawAlternative(
                id: 'small',
                label: 'Small',
                minutes: 5,
                guidance: 'Short practice.',
              ),
            ],
          ),
        ],
      );
      final catalog = AskHawCatalog([
        const AskHawContent(
          id: 'flow:7',
          kind: AskHawContentKind.flow,
          title: 'Practice',
          summary: 'Practice.',
          flowId: 7,
          editable: true,
          contract: contract,
        ),
      ]);
      final event = AskHawEvent(
        id: 'a',
        title: 'Practice',
        startUtc: now,
        endUtc: now.add(const Duration(minutes: 20)),
        flowId: 7,
        stepId: 'practice',
        editable: true,
      );
      final unsupported = engine.respond(
        recognizer.recognize('shorten this to 10 minutes'),
        context: context(events: [event], selected: 'a'),
        catalog: catalog,
      );
      expect(unsupported.kind, AskHawResponseKind.unavailable);
      final approved = engine.respond(
        recognizer.recognize('shorten this to 5 minutes'),
        context: context(events: [event], selected: 'a'),
        catalog: catalog,
      );
      expect(approved.options.first.id, 'action:shorten:a');
    },
  );
  test('pause lifecycle uses verified edit permission and active state', () {
    final catalog = AskHawCatalog([
      const AskHawContent(
        id: 'flow:7',
        kind: AskHawContentKind.flow,
        title: 'Practice',
        summary: 'Practice.',
        flowId: 7,
        editable: true,
        active: true,
      ),
    ]);
    final response = engine.respond(
      recognizer.recognize('pause this Flow'),
      context: context(flow: 7),
      catalog: catalog,
    );
    expect(response.kind, AskHawResponseKind.proposal);
    expect(response.options.single.id, 'action:pause:7');
  });

  test(
    'known existing Flow occurrences fit before new scheduling proposals',
    () {
      final catalog = AskHawCatalog([
        const AskHawContent(
          id: 'flow:7',
          kind: AskHawContentKind.flow,
          title: 'Offering Table',
          summary: 'Existing Flow.',
          flowId: 7,
          active: true,
        ),
      ]);
      final events = [
        AskHawEvent(
          id: 'unknown',
          title: 'Unknown duration',
          flowId: 7,
          durationKnown: false,
          startUtc: now,
          endUtc: now.add(const Duration(minutes: 3)),
        ),
        AskHawEvent(
          id: 'all-day',
          title: 'All day',
          flowId: 7,
          allDay: true,
          startUtc: now,
          endUtc: now.add(const Duration(minutes: 3)),
        ),
        AskHawEvent(
          id: 'real',
          title: 'Place water',
          flowId: 7,
          startUtc: now.add(const Duration(minutes: 5)),
          endUtc: now.add(const Duration(minutes: 8)),
        ),
      ];
      final response = engine.respond(
        recognizer.recognize('I have 10 minutes'),
        catalog: catalog,
        context: context(events: events),
      );
      expect(response.options.single.id, 'target:event:real');
      expect(response.body, contains('no extra session is added'));
    },
  );
  test(
    'unknown timed end keeps next navigable without claiming a duration',
    () {
      final start = now.add(const Duration(hours: 2));
      final response = engine.respond(
        recognizer.recognize("What's next?"),
        context: context(
          events: [
            AskHawEvent(
              id: 'unknown-end',
              title: 'Start-only commitment',
              startUtc: start,
              endUtc: start,
              durationKnown: false,
            ),
          ],
        ),
      );
      expect(response.title, 'Start-only commitment');
      expect(response.options.single.id, 'target:event:unknown-end');
      final visible =
          '${response.body} ${response.options.single.detail ?? ''}';
      expect(visible, isNot(contains('minute')));
      expect(visible, isNot(contains('hour')));
      expect(visible, isNot(contains('–')));
    },
  );

  test('built-in skip and next preserve the canonical completion owner', () {
    final catalog = AskHawCatalog([
      const AskHawContent(
        id: 'flow:7',
        kind: AskHawContentKind.flow,
        title: 'Follow the Sky',
        summary: 'Sky.',
        flowId: 7,
        active: true,
        editable: true,
        maatFlowKey: 'track-the-sky',
      ),
    ]);
    final event = AskHawEvent(
      id: 'sky',
      title: 'Sky turning',
      flowId: 7,
      startUtc: now,
      endUtc: now.add(const Duration(hours: 1)),
      editable: true,
    );
    final skipped = engine.respond(
      recognizer.recognize('skip this'),
      catalog: catalog,
      context: context(events: [event], selected: 'sky'),
    );
    expect(skipped.options.single.id, 'target:event:sky');
    expect(askHawCanAdaptEvent(event, AskHawIntent.move, catalog), isFalse);
    final next = engine.respond(
      recognizer.recognize("What's next?"),
      catalog: catalog,
      context: context(events: [event], flow: 7),
    );
    expect(next.options.single.id, 'target:event:sky');
  });
  test(
    'ordinary custom Flow calendar moves share the event permission policy',
    () {
      final catalog = AskHawCatalog([
        const AskHawContent(
          id: 'flow:7',
          kind: AskHawContentKind.flow,
          title: 'My practice',
          summary: 'Custom.',
          flowId: 7,
        ),
      ]);
      final event = AskHawEvent(
        id: 'custom',
        title: 'My practice',
        flowId: 7,
        startUtc: now,
        endUtc: now.add(const Duration(minutes: 20)),
        editable: true,
      );
      expect(askHawCanAdaptEvent(event, AskHawIntent.move, catalog), isTrue);
      expect(
        askHawCanAdaptEvent(event, AskHawIntent.shorten, catalog),
        isFalse,
      );
      final readonly = AskHawEvent(
        id: 'custom',
        title: 'My practice',
        flowId: 7,
        startUtc: now,
        endUtc: now.add(const Duration(minutes: 20)),
      );
      expect(
        askHawCanAdaptEvent(readonly, AskHawIntent.move, catalog),
        isFalse,
      );
    },
  );
  test(
    'Flow lifecycle refuses read-only or inactive Flows and respects pause state',
    () {
      AskHawCatalog flow({
        bool editable = true,
        bool active = true,
        bool paused = false,
      }) => AskHawCatalog([
        AskHawContent(
          id: 'flow:7',
          kind: AskHawContentKind.flow,
          title: 'Practice',
          summary: 'Practice.',
          flowId: 7,
          editable: editable,
          active: active,
          paused: paused,
        ),
      ]);
      final scope = context(flow: 7);
      for (final catalog in [flow(editable: false), flow(active: false)]) {
        final refused = engine.respond(
          recognizer.recognize('pause this Flow'),
          context: scope,
          catalog: catalog,
        );
        expect(refused.kind, AskHawResponseKind.unavailable);
        expect(
          refused.options.any((option) => option.id.startsWith('action:')),
          isFalse,
        );
      }
      final alreadyPaused = engine.respond(
        recognizer.recognize('pause this Flow'),
        context: scope,
        catalog: flow(paused: true),
      );
      expect(alreadyPaused.title, 'This Flow is already paused');
      expect(
        alreadyPaused.options.any((option) => option.id.startsWith('action:')),
        isFalse,
      );
      final resumed = engine.respond(
        recognizer.recognize('resume this Flow'),
        context: scope,
        catalog: flow(paused: true),
      );
      expect(resumed.kind, AskHawResponseKind.proposal);
      expect(resumed.options.single.id, 'action:resume:7');
      final running = engine.respond(
        recognizer.recognize('resume this Flow'),
        context: scope,
        catalog: flow(),
      );
      expect(running.title, 'This Flow is already running');
      expect(
        running.options.any((option) => option.id.startsWith('action:')),
        isFalse,
      );
    },
  );
  test(
    'explanations contain authored substance beyond rhetorical opening lines',
    () {
      final decan = engine.respond(recognizer.recognize('What is a decan?'));
      expect(decan.body, contains('ten-day'));
      final maat = engine.respond(recognizer.recognize('What is Maat?'));
      expect(maat.options.single.id, 'open:library:maat');
      expect(maat.body, contains('truth, justice, and order'));
      expect(maat.body, isNot(startsWith('What holds when')));
      final invalid = engine.respond(
        recognizer.recognize('I have 0 minutes'),
        memory: AskHawMemory(
          payload: {
            'preferences': {'preferredDurationMinutes': 20},
          },
        ),
      );
      expect(invalid.kind, AskHawResponseKind.choices);
      expect(invalid.title, 'How much time do you have?');
    },
  );
  test('confirmed content meaning works without a separate search phrase', () {
    final memory = AskHawMemory(
      payload: {
        'bindings': {
          'evening reset': {
            'intent': 'find',
            'query': '',
            'contentId': 'maat:the-djed',
          },
        },
      },
    );
    final request = recognizer.recognize('Evening reset', memory: memory);
    final response = engine.respond(request, memory: memory);
    expect(response.options.single.id, 'open:maat:the-djed');
    expect(response.options.single.reason, contains('confirmed'));
  });
  test(
    'selected Flow next offers eligible authored guidance without creating a session',
    () {
      const contract = AskHawFlowContract(
        steps: [
          AskHawStep(
            id: 'prepare',
            title: 'Prepare',
            guidance: 'Gather your materials.',
            minutes: 5,
          ),
          AskHawStep(
            id: 'practice',
            title: 'Practice',
            guidance: 'Follow the authored practice.',
            minutes: 20,
            prerequisites: ['prepare'],
          ),
        ],
      );
      final catalog = AskHawCatalog([
        const AskHawContent(
          id: 'flow:7',
          kind: AskHawContentKind.flow,
          title: 'My practice',
          summary: 'Custom practice.',
          flowId: 7,
          active: true,
          contract: contract,
        ),
      ]);
      AskHawContext scope(Map<String, AskHawCompletion> completions) =>
          AskHawContext(
            nowUtc: now,
            selectedFlowId: 7,
            coverageComplete: true,
            activities: [
              AskHawActivity(
                id: '7:practice',
                title: 'Practice',
                flowId: 7,
                stepId: 'practice',
                contract: contract,
                completions: completions,
              ),
            ],
          );
      final ready = engine.respond(
        recognizer.recognize("What's next?"),
        catalog: catalog,
        context: scope({'prepare': AskHawCompletion.observed}),
      );
      expect(ready.title, 'Practice');
      expect(ready.body, contains('Follow the authored practice.'));
      expect(ready.body, contains('has not been added'));
      expect(ready.options.single.id, 'open:flow:7');
      final blocked = engine.respond(
        recognizer.recognize("What's next?"),
        catalog: catalog,
        context: scope({'prepare': AskHawCompletion.unknown}),
      );
      expect(blocked.title, 'Nothing upcoming in the loaded period');
      expect(
        blocked.options.any(
          (option) =>
              option.id.startsWith('proposal:') ||
              option.id.startsWith('action:'),
        ),
        isFalse,
      );
    },
  );
  test(
    'reading goal clarification gives one explicit find or event decision',
    () {
      final response = engine.respond(
        recognizer.recognize('I want to read more'),
      );
      expect(response.kind, AskHawResponseKind.choices);
      expect(response.options.map((option) => option.id), [
        'correction:find',
        'correction:event',
      ]);
      expect(response.options.first.label, 'Find a reading Flow');
      expect(response.options.last.label, 'Add reading to my calendar');
    },
  );
}
