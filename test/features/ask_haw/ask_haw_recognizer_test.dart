import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/ask_haw/ask_haw_memory.dart';
import 'package:mobile/features/ask_haw/ask_haw_models.dart';
import 'package:mobile/features/ask_haw/ask_haw_recognizer.dart';

void main() {
  const recognizer = AskHawRecognizer();
  group('ordinary event preservation', () {
    for (final raw in [
      'Dentist Friday at 3',
      'dinner with Mike at 6pm in Beverly Hills',
      'workout for an hour at 7am',
      'call mom',
      'buy bread',
      'dinner on Rekh-Wer 8 at 6pm',
      'flight 3/15 at 9am',
      'meet James at Soho House at 8',
    ]) {
      test(raw, () {
        final result = recognizer.recognize(raw);
        expect(result.intent, AskHawIntent.event);
        expect(result.raw, raw);
      });
    }
  });
  test('supported requests retain slots and question intent', () {
    expect(recognizer.recognize("What's next?").intent, AskHawIntent.next);
    final fit = recognizer.recognize('I only have 10 minutes');
    expect(fit.intent, AskHawIntent.fit);
    expect(fit.minutes, 10);
    expect(
      recognizer.recognize('Help me plan today').intent,
      AskHawIntent.plan,
    );
    expect(recognizer.recognize('What is a decan?').query, 'decan');
    expect(
      recognizer.recognize('Find a beginner cooking Flow').query,
      'beginner cooking flow',
    );
    final move = recognizer.recognize('Move this to Friday at 3pm');
    expect(move.intent, AskHawIntent.move);
    expect(move.targetText, 'this');
    expect(move.temporalText, 'friday at 3pm');
    expect(move.explicitTemporal, isTrue);
    final shorten = recognizer.recognize('shorten this to 10 minutes');
    expect(shorten.intent, AskHawIntent.shorten);
    expect(shorten.minutes, 10);
    expect(
      recognizer.recognize('pause my reading Flow').intent,
      AskHawIntent.pause,
    );
    expect(
      recognizer.recognize('resume my reading Flow').intent,
      AskHawIntent.resume,
    );
  });
  test('reflection seeds are explicit requests, never saved events', () {
    expect(recognizer.recognize('Find a flow').intent, AskHawIntent.find);
    expect(
      recognizer.recognize('Find time for a personal activity').intent,
      AskHawIntent.find,
    );
  });
  test('unsupported questions and verbs never silently become events', () {
    for (final raw in [
      'Why am I tired?',
      'How do I cook?',
      'Can you email Mom?',
      'When should I move?',
      'Delete all my events',
      'remember everything',
      'Tomorrow at 8?',
      'help me write a novel',
    ]) {
      expect(
        recognizer.recognize(raw).intent,
        AskHawIntent.unsupported,
        reason: raw,
      );
    }
  });
  test('confirmed phrases remember a meaning; explicit time overrides it', () {
    final memory = AskHawMemory(
      payload: {
        'bindings': {
          'evening reset': {
            'intent': 'find',
            'query': 'stability',
            'contentId': 'maat:the-djed',
          },
        },
      },
    );
    final learned = recognizer.recognize('Evening reset', memory: memory);
    expect(learned.intent, AskHawIntent.find);
    expect(learned.contentId, 'maat:the-djed');
    expect(learned.learned, isTrue);
    expect(
      recognizer
          .recognize('Evening reset tomorrow at 8', memory: memory)
          .intent,
      AskHawIntent.event,
    );
    expect(
      recognizer.recognize('Move this to Friday', memory: memory).intent,
      AskHawIntent.move,
    );
  });
  test('confirmed event correction overrides the exact question only', () {
    final memory = AskHawMemory(
      payload: {
        'bindings': {
          'what is a decan': {'intent': 'event'},
          'reset': {'intent': 'event'},
        },
      },
    );
    final corrected = recognizer.recognize('What is a decan?', memory: memory);
    expect(corrected.intent, AskHawIntent.event);
    expect(corrected.learned, isTrue);
    expect(corrected.raw, 'What is a decan?');
    expect(
      recognizer.recognize('What is a decan tomorrow?', memory: memory).intent,
      AskHawIntent.explain,
    );
    final dated = recognizer.recognize('Reset tomorrow at 8', memory: memory);
    expect(dated.intent, AskHawIntent.event);
    expect(dated.explicitTemporal, isTrue);
    expect(dated.learned, isFalse);
  });
  test('learned bindings cannot authorize mutations', () {
    final memory = AskHawMemory(
      payload: {
        'bindings': {
          'make room': {'intent': 'move', 'contentId': 'private-event'},
          'end it': {'intent': 'pause', 'contentId': 'flow:7'},
        },
      },
    );
    expect(
      recognizer.recognize('make room', memory: memory).intent,
      AskHawIntent.event,
    );
    expect(
      recognizer.recognize('end it', memory: memory).intent,
      AskHawIntent.event,
    );
  });
  test('duration grammar is bounded and preserves decimal hours', () {
    expect(parseAskHawMinutes('I have 1.5 hours'), 90);
    expect(parseAskHawMinutes('half an hour'), 30);
    expect(parseAskHawMinutes('an hour'), 60);
    expect(parseAskHawMinutes('0 minutes'), isNull);
    expect(parseAskHawMinutes('1500 minutes'), isNull);
  });
  test(
    'transliteration and punctuation matching leaves event text untouched',
    () {
      expect(normalizeAskHaw('  Ḥꜣw — Kꜣr  '), 'haw kar');
      expect(normalizeAskHaw('h\u0323ꜣw'), 'haw');
      expect(
        recognizer.recognize('Ḥꜣw — Kꜣr tomorrow').raw,
        'Ḥꜣw — Kꜣr tomorrow',
      );
    },
  );
  test(
    'invalid or missing explicit time budgets clarify instead of adding events',
    () {
      for (final raw in [
        'I have 0 minutes',
        'I have 1500 minutes',
        'I have time',
      ]) {
        expect(recognizer.recognize(raw).intent, AskHawIntent.fit);
      }
      expect(recognizer.recognize('I have 0 minutes').minutes, 0);
    },
  );
  test('explicit decan shorter-session seed enters preference selection', () {
    for (final raw in [
      'Help me use shorter sessions',
      'Use shorter sessions',
    ]) {
      final request = recognizer.recognize(raw);
      expect(request.intent, AskHawIntent.preferences);
      expect(request.query, 'shorter sessions');
      expect(request.requiresAccount, isTrue);
      expect(request.raw, raw);
    }
  });
  test(
    'confirmed supported searches and explanations resolve before generic grammar',
    () {
      final memory = AskHawMemory(
        payload: {
          'bindings': {
            'find a reading flow': {
              'intent': 'find',
              'query': 'reading',
              'contentId': 'maat:the-reading-house',
            },
            'explain thoth': {
              'intent': 'explain',
              'query': 'thoth',
              'contentId': 'library:djehuty',
            },
            'i have 10 minutes': {'intent': 'fit', 'minutes': 30},
          },
        },
      );
      final find = recognizer.recognize('Find a reading Flow', memory: memory);
      expect(find.contentId, 'maat:the-reading-house');
      expect(find.learned, isTrue);
      final explain = recognizer.recognize('Explain Thoth', memory: memory);
      expect(explain.contentId, 'library:djehuty');
      expect(explain.learned, isTrue);
      expect(explain.explicitTemporal, isFalse);
      for (final date in ['Thoth 1', 'Ḏḥwty 1', 'Hathor 4', 'Oct. 27']) {
        final raw = 'Explain Thoth on $date';
        final datedMemory = AskHawMemory(
          payload: {
            'bindings': {
              normalizeAskHaw(raw): {
                'intent': 'explain',
                'contentId': 'library:djehuty',
              },
            },
          },
        );
        final dated = recognizer.recognize(raw, memory: datedMemory);
        expect(dated.explicitTemporal, isTrue, reason: date);
        expect(dated.learned, isFalse, reason: date);
        expect(dated.contentId, isNull, reason: date);
      }
      expect(
        recognizer.recognize('I have 10 minutes', memory: memory).minutes,
        10,
      );
      final dated = recognizer.recognize(
        'Find a reading Flow tomorrow',
        memory: memory,
      );
      expect(dated.learned, isFalse);
      expect(dated.contentId, isNull);
    },
  );
  test(
    'documented reading goal asks one choice and explicit dated entries stay events',
    () {
      final goal = recognizer.recognize('I want to read more');
      expect(goal.intent, AskHawIntent.clarify);
      expect(goal.query, 'reading goal');
      expect(
        recognizer.recognize('I want to read more tomorrow at 8').intent,
        AskHawIntent.event,
      );
      expect(
        recognizer.recognize('Read more tomorrow at 8').intent,
        AskHawIntent.event,
      );
      final confirmed = AskHawMemory(
        payload: {
          'bindings': {
            'i want to read more': {'intent': 'find', 'query': 'reading'},
          },
        },
      );
      expect(
        recognizer.recognize('I want to read more', memory: confirmed).intent,
        AskHawIntent.find,
      );
      expect(
        recognizer
            .recognize('I want to read more tomorrow at 8', memory: confirmed)
            .intent,
        AskHawIntent.event,
      );
    },
  );
}
