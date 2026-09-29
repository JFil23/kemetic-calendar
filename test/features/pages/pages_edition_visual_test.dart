import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/commons_models.dart';
import 'package:mobile/features/pages/pages_board.dart';
import 'package:mobile/features/pages/pages_models.dart';
import 'package:mobile/features/pages/pages_feed_rotation.dart';

void main() {
  testWidgets(
    'edition previews fit existing pane geometry at narrow and wide phone widths',
    (tester) async {
      tester.view.physicalSize = const Size(630, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fonts =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      for (final f in fonts) {
        final loader = FontLoader(f['family']);
        for (final a in f['fonts']) {
          loader.addFont(rootBundle.load(a['asset']));
        }
        await loader.load();
      }
      const cards = [
        PagesCard(
          PagesDestination.planner,
          state: PagesLoadState.ready,
          plannerDisplay: PagesPlannerDisplay.note,
          primary: PagesSignal('Say no to burnout', label: 'Note'),
          meta: 'Today’s alignment note',
        ),
        PagesCard(
          PagesDestination.planner,
          state: PagesLoadState.ready,
          plannerDisplay: PagesPlannerDisplay.todo,
          primary: PagesSignal(
            'Prepare tomorrow’s reading',
            label: 'To do',
            detail: '9/28 · 8:00 am',
          ),
          meta: 'Next unfinished to-do',
        ),
        PagesCard(
          PagesDestination.planner,
          state: PagesLoadState.ready,
          plannerDisplay: PagesPlannerDisplay.nutrition,
          primary: PagesSignal(
            'Magnesium',
            label: 'Nutrition',
            detail: 'Pumpkin seeds · Muscle and nerve support',
          ),
          meta: 'Today’s decan nutrition',
        ),
        PagesCard(
          PagesDestination.feed,
          state: PagesLoadState.ready,
          feedDisplay: PagesFeedDisplay.answer,
          answer: CommonsAnswer(
            id: 'a',
            questionId: 'q',
            userId: 'other',
            authorDisplayName: 'A community member',
            bodyText:
                'I am slowing down enough to notice the people around me, especially when the day becomes busy.',
          ),
          meta: 'Question of the day · public answer',
        ),
      ];
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final width in [150.0, 186.5, 205.0])
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: SizedBox(
                        width: width,
                        child: Column(
                          children: [
                            for (final card in cards)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: PagesTile(card: card, onTap: () {}),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final path = Platform.environment['HAW_PAGES_CAPTURE_PATH'];
      if (path != null) {
        await expectLater(find.byKey(key), matchesGoldenFile(path));
      }
    },
  );
}
