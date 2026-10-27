import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/ask_haw/ask_haw_memory.dart';
import 'package:mobile/features/ask_haw/ask_haw_flow_contract.dart';

void main() {
  test('memory retains receipt and recursively freezes caller-owned input', () {
    final bindings = <String, dynamic>{
      'reset': {'intent': 'find', 'query': 'stability'},
    };
    final payload = <String, dynamic>{
      'bindings': bindings,
      'hidden': ['flow:7'],
      'preferences': {
        'suggestionsEnabled': false,
        'preferredDurationMinutes': 20,
        'preferredTimeOfDay': 'evening',
      },
    };
    final memory = AskHawMemory(revision: 7, epoch: 2, payload: payload);
    bindings.clear();
    expect(memory.bindingFor('reset')!['query'], 'stability');
    expect(memory.suggestionsEnabled, isFalse);
    expect(memory.preferredDurationMinutes, 20);
    expect(memory.preferredTimeOfDay, 'evening');
    expect(memory.hiddenSuggestions, {'flow:7'});
    expect(
      () => memory.preferences['suggestionsEnabled'] = true,
      throwsUnsupportedError,
    );
    final restored = AskHawMemory.fromJson(memory.toJson());
    expect(restored.revision, 7);
    expect(restored.epoch, 2);
    expect(restored.payload, memory.payload);
  });
  test('malformed optional preferences do not crash an interaction', () {
    final memory = AskHawMemory(
      payload: {
        'preferences': {
          'preferredDurationMinutes': 'ten',
          'preferredTimeOfDay': 'sunset',
        },
        'hidden': 5,
      },
    );
    expect(memory.preferredDurationMinutes, isNull);
    expect(memory.preferredTimeOfDay, 'any');
    expect(memory.hiddenSuggestions, isEmpty);
  });
  test(
    'new confirmed binding replaces the prior meaning and clear changes epoch',
    () {
      final old = AskHawMemory(
        revision: 1,
        epoch: 1,
        payload: {
          'bindings': {
            'reset': {'intent': 'find', 'query': 'reading'},
          },
        },
      );
      final corrected = old.copyWith(
        revision: 2,
        payload: {
          'bindings': {
            'reset': {'intent': 'find', 'query': 'stability'},
          },
        },
      );
      expect(corrected.bindingFor('reset')!['query'], 'stability');
      expect(old.bindingFor('reset')!['query'], 'reading');
      final cleared = AskHawMemory(revision: 3, epoch: 2);
      expect(cleared.bindings, isEmpty);
      expect(cleared.epoch, greaterThan(corrected.epoch));
    },
  );
  test(
    'authored capabilities survive JSON with prerequisite and alternative meanings',
    () {
      const contract = AskHawFlowContract(
        guidance: 'Take your time.',
        adaptations: {AskHawAdaptation.shorten, AskHawAdaptation.reschedule},
        steps: [
          AskHawStep(
            id: 'prepare',
            title: 'Prepare',
            guidance: 'Place water.',
            minutes: 3,
          ),
          AskHawStep(
            id: 'practice',
            title: 'Practice',
            guidance: 'Continue slowly.',
            minutes: 20,
            prerequisites: ['prepare'],
            completionMeaning: 'One completed return.',
            recoveryGuidance: 'Return at the next opportunity.',
            alternatives: [
              AskHawAlternative(
                id: 'short',
                label: 'Small return',
                minutes: 5,
                guidance: 'The authored short practice.',
              ),
            ],
          ),
        ],
      );
      final restored = AskHawFlowContract.tryFromJson(contract.toJson())!;
      expect(restored.permits(AskHawAdaptation.shorten), isTrue);
      expect(restored.permits(AskHawAdaptation.pause), isFalse);
      expect(
        restored.step('practice')!.eligible({
          'prepare': AskHawCompletion.partial,
        }),
        isFalse,
      );
      expect(
        restored.step('practice')!.eligible({
          'prepare': AskHawCompletion.observed,
        }),
        isTrue,
      );
      expect(
        restored.step('practice')!.completionMeaning,
        'One completed return.',
      );
      expect(
        restored.step('practice')!.alternatives.single.guidance,
        'The authored short practice.',
      );
    },
  );
  test('future, malformed and cyclic contracts fail closed for assistance', () {
    expect(AskHawFlowContract.tryFromJson({'version': 2, 'steps': []}), isNull);
    expect(
      AskHawFlowContract.tryFromJson({'version': 1, 'steps': 'bad'}),
      isNull,
    );
    expect(
      AskHawFlowContract.tryFromJson({
        'version': 1,
        'adaptations': ['execute'],
        'steps': [],
      }),
      isNull,
    );
    const cycle = AskHawFlowContract(
      steps: [
        AskHawStep(id: 'a', title: 'A', guidance: 'A', prerequisites: ['b']),
        AskHawStep(id: 'b', title: 'B', guidance: 'B', prerequisites: ['a']),
      ],
    );
    expect(cycle.supported, isFalse);
    expect(AskHawFlowContract.tryFromJson(cycle.toJson()), isNull);
    const missing = AskHawFlowContract(
      steps: [
        AskHawStep(
          id: 'a',
          title: 'A',
          guidance: 'A',
          prerequisites: ['missing'],
        ),
      ],
    );
    expect(missing.supported, isFalse);
  });
}
