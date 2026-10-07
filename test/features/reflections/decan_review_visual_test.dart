import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/reflections/decan_review_models.dart';
import 'package:mobile/features/reflections/decan_review_views.dart';
import 'package:mobile/features/reflections/decan_review_widgets.dart';

void main() {
  final start = DateTime(2026, 10, 1);
  final moments = [
    DecanMoment(
      id: 'r',
      kind: 'maat_response',
      sourceId: 'r',
      occurredOn: DateTime(2026, 10, 2),
      sourceLabel: 'Reading House',
      actionLabel: 'Your words',
      text: '“I can give a thought time before I answer it.”',
      isQuote: true,
    ),
    DecanMoment(
      id: 'w',
      kind: 'custom_flow',
      sourceId: 'w',
      occurredOn: DateTime(2026, 10, 6),
      sourceLabel: 'Your flow',
      actionLabel: 'Completed',
      text: 'An evening walk',
    ),
    DecanMoment(
      id: 'l',
      kind: 'library_bookmark',
      sourceId: 'l',
      occurredOn: DateTime(2026, 10, 9),
      sourceLabel: 'Library',
      actionLabel: 'Bookmarked',
      text: 'Instruction of Ptahhotep',
    ),
  ];
  const sample =
      'Give a thought time before I answer it. Make a little more room for unhurried walks.';
  const question = 'What would you like to carry forward?';
  void noop() {}

  testWidgets(
    'approved decan visual states fit phone, tablet and text scaling',
    (tester) async {
      for (final face in <String, String>{
        'Inter': 'Inter-Variable.ttf',
        'InterWeb': 'Inter-Regular.ttf',
        'GentiumPlus': 'GentiumPlus-Regular.ttf',
      }.entries) {
        await (FontLoader(
          face.key,
        )..addFont(rootBundle.load('ios/Runner/Fonts/${face.value}'))).load();
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      // FontLoader has no weight descriptors. Register the reference's 400
      // faces last, so this fixture does not accidentally capture semibold.
      await (FontLoader('CormorantGaramond')
            ..addFont(
              rootBundle.load('ios/Runner/Fonts/CormorantGaramond-Regular.ttf'),
            )
            ..addFont(
              rootBundle.load('ios/Runner/Fonts/CormorantGaramond-Italic.ttf'),
            ))
          .load();
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      final input = TextEditingController(text: sample);
      addTearDown(input.dispose);
      Future<void> show(
        String name,
        Widget child, {
        double width = 402,
        double height = 1150,
        double keyboard = 0,
        double scale = 1,
      }) async {
        tester.view.physicalSize = Size(width, height);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, height),
                viewInsets: EdgeInsets.only(bottom: keyboard),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                resizeToAvoidBottomInset: false,
                backgroundColor: DecanReviewStyle.base,
                body: RepaintBoundary(key: key, child: child),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$name at $width / $scale',
        );
        if (Platform.environment['HAW_DECAN_CAPTURE_DIR'] case final String path
            when path.isNotEmpty) {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(path).create(recursive: true);
            await File(
              '$path/$name-${width.toInt()}-$scale.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }

      Widget opening(List<DecanMoment> rows, {bool writing = false}) =>
          DecanReviewOpening(
            moments: rows,
            decanStart: start,
            question: question,
            onChoose: noop,
            onWrite: noop,
            onLeave: noop,
            onOpenMoment: (_) {},
            answerController: writing ? input : null,
            onSave: noop,
          );
      await show('opening', opening(moments));
      expect(find.text('These ten days'), findsOneWidget);
      expect(find.text(question), findsOneWidget);
      expect(find.byType(DecanMomentTile), findsNWidgets(3));
      await show('writing', opening(moments, writing: true));
      await show(
        'writing-keyboard',
        opening(moments, writing: true),
        height: 720,
        keyboard: 300,
      );
      await tester.ensureVisible(find.text('Keep in Journal'));
      await tester.pumpAndSettle();
      expect(
        tester.getBottomRight(find.text('Keep in Journal')).dy,
        lessThanOrEqualTo(420),
      );
      await show('landscape', opening(moments), width: 844, height: 390);
      await tester.ensureVisible(find.text('Leave the question open'));
      await tester.pumpAndSettle();
      expect(
        find.text('Leave the question open').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await show('one', opening(moments.take(1).toList()));
      await show(
        'chooser',
        DecanReviewChooser(
          moments: moments,
          selectedIds: {'r', 'w'},
          onToggle: (_) {},
          onOpen: (_) {},
          ownController: TextEditingController(),
          onOwnChanged: (_) {},
          onKeep: noop,
          onBack: noop,
          onMore: noop,
          onJournal: noop,
        ),
      );
      await show(
        'publish',
        DecanReviewPublish(
          controller: input,
          onChanged: (_) {},
          question: question,
          includeQuestion: true,
          onQuestionChanged: (_) {},
          author: 'Nia',
          handle: 'nia',
          onPublish: noop,
          onBack: noop,
          readingTitle: 'Instruction of Ptahhotep',
          onReadingChanged: (_) {},
        ),
      );
      await show('empty', opening([]));
      expect(
        find.text('You can begin with whatever stayed with you.'),
        findsOneWidget,
      );
      await show(
        'saved',
        DecanReviewSaved(
          response: sample,
          question: question,
          onJournal: noop,
          onPost: noop,
          onDone: noop,
        ),
      );
      await show(
        'journal',
        DecanReviewCanvas(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: noop,
                child: Text('‹ Reflection', style: DecanReviewStyle.ui(12.5)),
              ),
            ),
            const DecanReviewIntro(
              eyebrow: 'Journal',
              title: 'Today',
              subtitle: 'Your writing, kept together.',
              compact: true,
            ),
            const DecanReviewLabel('Earlier today'),
            const SizedBox(height: 14),
            Text(
              'The morning was quiet. I left the window open while I read.',
              style: DecanReviewStyle.serif(
                23,
                color: DecanReviewStyle.soft,
                height: 1.42,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Divider(color: DecanReviewStyle.line, height: 1),
            ),
            DecanJournalContribution(
              response: sample,
              question: question,
              rangeLabel: 'Days 1–10',
              days: const {2, 6, 9},
              onReflection: noop,
              onEdit: noop,
              onPost: noop,
            ),
            const DecanReviewFooter('Private, unless you choose to post.'),
          ],
        ),
      );
      await show(
        'public',
        DecanReviewCanvas(
          privacy: 'Community',
          children: [
            const DecanReviewIntro(
              eyebrow: 'Your profile & feed',
              title: 'A shared reflection',
              subtitle: 'Published by you.',
              compact: true,
            ),
            const DecanPublicReflectionCard(
              author: 'Nia',
              handle: 'nia',
              body: sample,
              question: question,
            ),
            DecanReviewButton('Edit post', onPressed: noop),
            DecanReviewButton(
              'Open private Journal',
              onPressed: noop,
              quiet: true,
            ),
            DecanReviewButton('Remove post', onPressed: noop, quiet: true),
            const DecanReviewFooter('Your Journal keeps its own words.'),
          ],
        ),
      );
      await show(
        'continuation',
        DecanReviewContinuation(
          suggestions: const [
            DecanContinuation(
              id: 'f',
              title: 'Kꜣr',
              reason:
                  'An imaginative practice to explore alongside your reading.',
              flowKey: 'the-kar',
            ),
            DecanContinuation(
              id: 'l',
              title: 'Ma’at',
              reason: 'A reading linked from Instruction of Ptahhotep.',
              libraryId: 'maat',
            ),
          ],
          onOpen: (_) {},
          onDismiss: (_) {},
          onDone: noop,
        ),
      );
      expect(find.text('FROM THE LIBRARY'), findsOneWidget);
      expect(find.textContaining('node'), findsNothing);
      for (final width in [320.0, 768.0]) {
        await show('opening', opening(moments), width: width);
        await show(
          'scaled',
          opening(moments, writing: true),
          width: width,
          scale: 2,
        );
      }
    },
  );
}
