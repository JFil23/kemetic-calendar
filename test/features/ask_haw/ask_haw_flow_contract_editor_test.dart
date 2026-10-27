import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/ask_haw/ask_haw_flow_contract.dart';
import 'package:mobile/features/ask_haw/ask_haw_flow_contract_editor.dart';
import '../../support/ask_haw_flow_contract_fixture.dart';

Map<String, dynamic> fixture() => Map<String, dynamic>.from(
  jsonDecode(jsonEncode(askHawFlowContractFixture)) as Map,
);

void main() {
  test(
    'step links require explicit versioned identity and preserve other behavior',
    () {
      const original = <String, dynamic>{
        'other_owner': {'keep': true},
        'ask_haw': {'step_id': 'prepare', 'contract_version': 1},
      };
      expect(askHawAuthoredStepId(original), 'prepare');
      expect(
        askHawAuthoredStepId({
          'ask_haw': {'step_id': 'prepare', 'contract_version': 99},
        }),
        isNull,
      );
      expect(askHawAuthoredStepId({'title': 'prepare'}), isNull);
      final changed = withAskHawAuthoredStep(original, 'read')!;
      expect(changed['other_owner'], {'keep': true});
      expect(askHawAuthoredStepId(changed), 'read');
      expect(askHawAuthoredStepId(original), 'prepare');
      expect(withAskHawAuthoredStep(changed, null), {
        'other_owner': {'keep': true},
      });
    },
  );

  test(
    'creator validation shares contract boundaries and rejects unsafe graphs',
    () {
      expect(validateAskHawFlowAssistance(fixture()), isNull);
      for (final mutation in <void Function(Map<String, dynamic>)>[
        (raw) => raw['version'] = 99,
        (raw) => raw['steps'][0]['minutes'] = 0,
        (raw) => raw['steps'][0]['minutes'] = 'ten',
        (raw) => raw['steps'][1]['id'] = raw['steps'][0]['id'],
        (raw) => raw['steps'][0]['prerequisites'] = ['read'],
        (raw) => raw['steps'][0]['prerequisites'] = ['missing'],
        (raw) => raw['steps'][0]['guidance'] = ' ',
        (raw) => raw['steps'][0]['alternatives'][0]['minutes'] = 20,
      ]) {
        final raw = fixture();
        mutation(raw);
        expect(validateAskHawFlowAssistance(raw), isNotNull, reason: '$raw');
      }
    },
  );

  testWidgets(
    'unsupported guidance is retained until an explicit replacement',
    (tester) async {
      final key = GlobalKey<AskHawFlowContractEditorState>();
      const future = {
        'version': 42,
        'future': {
          'preserve': ['exactly'],
        },
      };
      Map<String, dynamic>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AskHawFlowContractEditor(
                key: key,
                value: future,
                initiallyExpanded: true,
                onChanged: (value) => saved = value,
              ),
            ),
          ),
        ),
      );
      expect(key.currentState!.validateAndCommit(), isTrue);
      expect(saved, isNull);
      expect(
        find.byKey(const ValueKey('ask-haw-contract-guidance')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('ask-haw-assistance-replace')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('ask-haw-contract-guidance')),
        'Pause only when you choose.',
      );
      expect(key.currentState!.validateAndCommit(), isTrue);
      expect(saved?['version'], 1);
      expect(saved?.containsKey('future'), isFalse);
      expect(saved?['guidance'], 'Pause only when you choose.');
    },
  );

  testWidgets(
    'incomplete drafts survive restoration and cannot save invalid durations',
    (tester) async {
      final raw = fixture();
      raw['steps'][0]['minutes'] = 'soon';
      final key = GlobalKey<AskHawFlowContractEditorState>();
      Map<String, dynamic>? saved, draft;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AskHawFlowContractEditor(
                key: key,
                value: askHawFlowContractFixture,
                draft: {'replacement': false, 'contract': raw},
                onChanged: (value) => saved = value,
                onDraftChanged: (value) => draft = value,
              ),
            ),
          ),
        ),
      );
      expect(key.currentState!.validateAndCommit(), isFalse);
      expect(saved, isNull);
      await tester.pump();
      final length = find.byKey(const ValueKey('ask-haw-step-0-minutes'));
      await tester.ensureVisible(length);
      await tester.enterText(length, '15');
      expect(draft?['contract']['steps'][0]['minutes'], 15);
      expect(key.currentState!.validateAndCommit(), isTrue);
      expect(saved?['steps'][0]['minutes'], 15);
      expect(
        saved?['steps'][0]['alternatives'][0]['countsAsCompletion'],
        isTrue,
      );
      expect(draft, isNull);
      expect(AskHawFlowContract.tryFromJson(saved)?.supported, isTrue);
    },
  );

  testWidgets(
    'editing preserves extension fields and removal explicitly disables assistance',
    (tester) async {
      final raw = fixture()..['creatorExtension'] = {'preserve': true};
      raw['steps'][0]['futureStepField'] = 'kept';
      final key = GlobalKey<AskHawFlowContractEditorState>();
      Map<String, dynamic>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AskHawFlowContractEditor(
                key: key,
                value: raw,
                initiallyExpanded: true,
                onChanged: (value) => saved = value,
              ),
            ),
          ),
        ),
      );
      final title = find.byKey(const ValueKey('ask-haw-step-0-title'));
      await tester.ensureVisible(title);
      await tester.enterText(title, 'Prepare a quiet place');
      expect(key.currentState!.validateAndCommit(), isTrue);
      expect(saved?['creatorExtension'], {'preserve': true});
      expect(saved?['steps'][0]['futureStepField'], 'kept');
      await tester.pump();
      final remove = find.byKey(const ValueKey('ask-haw-assistance-remove'));
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      expect(saved?['version'], 1);
      expect(saved?['steps'], isEmpty);
      expect(saved?['adaptations'], isEmpty);
      expect(AskHawFlowContract.tryFromJson(saved)?.supported, isTrue);
    },
  );
}
