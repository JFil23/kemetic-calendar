import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/commons_models.dart';
import 'package:mobile/features/profile/commons_question_block.dart';
import 'package:mobile/features/profile/commons_rhythm_block.dart';
import '../../support/maat_flow_visual_test_fonts.dart';

void main() {
  setUpAll(() async {
    await loadMaatFlowVisualTestFonts();
    final font = FontLoader('Ahem')
      ..addFont(rootBundle.load('ios/Runner/Fonts/GentiumPlus-Regular.ttf'));
    await font.load();
  });
  testWidgets('all loaded public answers render and more remains reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var calls = 0;
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final answers = List.generate(
      9,
      (i) => CommonsAnswer(
        id: 'answer-$i',
        questionId: 'today',
        userId: 'person-$i',
        bodyText: 'Public reflection $i',
        authorDisplayName: 'Practitioner $i',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Inter'),
        home: Scaffold(
          backgroundColor: const Color(0xFF090805),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  const CommonsRhythmBlock(
                    summary: CommonsRhythmSummary(
                      activeUsersTodayLabel: '2',
                      flowsKeptTodayLabel: '7',
                      publicFragmentsTodayLabel: '3',
                      publicRoomsOpenLabel: '1',
                    ),
                  ),
                  CommonsQuestionBlock(
                    question: CommonsQuestion(
                      id: 'today',
                      question:
                          'What do I know now that I could not see thirty days ago?',
                      answers: answers,
                      myAnswer: answers.first,
                    ),
                    composer: CommonsAnswerComposer(
                      controller: controller,
                      saving: false,
                      onSave: () {},
                      onCancel: () {},
                    ),
                    answerBuilder: (answer, mine) => CommonsAnswerCard(
                      answer: answer,
                      isMine: mine,
                      onAction: (_) {},
                    ),
                    hasMoreAnswers: true,
                    onLoadMore: () => calls++,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Public reflection 8'), findsOneWidget);
    expect(find.text('Public reflection 0'), findsOneWidget);
    await tester.ensureVisible(find.text('Show more answers'));
    await tester.tap(find.text('Show more answers'));
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'old global caches and failed reads do not become followed totals',
    (tester) async {
      final legacy = CommonsRhythmSummary.fromJson({
        'active_users_today': 9876,
        'flows_kept_today': 4321,
        'public_fragments_today': 6789,
        'public_rooms_open': 987,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CommonsRhythmBlock(summary: legacy)),
        ),
      );
      expect(find.text('9876'), findsNothing);
      expect(find.text('4321'), findsNothing);
      expect(find.text('—'), findsNWidgets(4));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CommonsRhythmBlock(errorMessage: 'Could not refresh'),
          ),
        ),
      );
      expect(find.text('0'), findsNothing);
      expect(find.text('Could not refresh'), findsOneWidget);
    },
  );

  testWidgets('Commons reference layout with followed rhythm and public answers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Inter'),
        home: Scaffold(
          backgroundColor: const Color(0xFF090805),
          body: RepaintBoundary(
            key: const ValueKey('capture'),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  const CommonsRhythmBlock(
                    summary: CommonsRhythmSummary(
                      activeUsersTodayLabel: '2',
                      flowsKeptTodayLabel: '7',
                      publicFragmentsTodayLabel: '3',
                      publicRoomsOpenLabel: '1',
                    ),
                  ),
                  CommonsQuestionBlock(
                    question: const CommonsQuestion(
                      id: 'today',
                      question:
                          'What do I know now that I could not see thirty days ago?',
                      answers: [
                        CommonsAnswer(
                          id: '1',
                          questionId: 'today',
                          userId: 'other',
                          bodyText:
                              'I can let a small daily practice become enough.',
                          authorDisplayName: 'A fellow practitioner',
                        ),
                      ],
                    ),
                    composer: CommonsAnswerComposer(
                      controller: controller,
                      saving: false,
                      onSave: () {},
                      onCancel: () {},
                    ),
                    answerBuilder: (answer, mine) => CommonsAnswerCard(
                      answer: answer,
                      isMine: mine,
                      onAction: (_) {},
                    ),
                    hasMoreAnswers: true,
                    onLoadMore: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (Platform.environment['COMMONS_CAPTURE'] == '1') {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('capture')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/tmp/commons-public-reference-v2.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
