import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flow_appearance.dart';
import 'package:mobile/data/insight_post_model.dart';
import 'package:mobile/features/profile/posted_flow_artifact.dart';
import 'package:mobile/features/profile/profile_insight_post_tile.dart';

import '../../support/maat_flow_visual_test_fonts.dart';

const excerpt =
    'Djehuty is what keeps reality from becoming whatever the loudest person says happened.';
final post = InsightPost(
  id: 'visual-insight',
  userId: 'visual-author',
  insightEntryId: 'visual-entry',
  nodeId: 'djehuty',
  nodeTitle: 'Djehuty',
  nodeGlyph: '𓅝',
  bodyText: 'insight test for posting',
  entryDate: DateTime(2026, 7, 8),
  createdAt: DateTime(2026, 9, 24),
  updatedAt: DateTime(2026, 9, 24),
);

Future<void> capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['HAW_INSIGHT_LAYOUT_CAPTURE_DIR'];
  if (directory == null) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('insight-layout-capture')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(loadMaatFlowVisualTestFonts);
  for (final kind in ['library', 'decan']) {
    final renderedPost = kind == 'library'
        ? post
        : InsightPost.fromJson({
            ...post.toJson(),
            'source_kind': 'decan',
            'source_reflection_id': 'review',
            'node_slug': '',
            'node_title': 'Decan reflection',
            'node_glyph': null,
            'question_text': 'What would you like to carry forward?',
          });
    final displayedExcerpt = kind == 'library'
        ? excerpt
        : renderedPost.questionText!;
    for (final width in [360.0, 390.0, 844.0]) {
      for (final textScale in [1.0, 2.0]) {
        testWidgets('$kind insight composition at $width with $textScale text', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, textScale == 1 ? 900 : 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          var opened = 0;
          var removed = 0;
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData.dark().copyWith(
                textTheme: ThemeData.dark().textTheme.apply(
                  fontFamily: 'GentiumPlus',
                ),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
              home: Scaffold(
                backgroundColor: const Color(0xFF0B0906),
                body: RepaintBoundary(
                  key: const ValueKey('insight-layout-capture'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 30, 18, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'POSTS',
                          style: TextStyle(
                            color: Color(0xFFB89A55),
                            fontFamily: 'Inter',
                            fontSize: 10,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ProfileInsightPostTile(
                          post: renderedPost,
                          nodeExcerpt: excerpt,
                          authorDisplayName: 'BigJFil',
                          authorHandle: 'bigjfil',
                          authorAvatarUrl: null,
                          authorAvatarGlyphIds: const [],
                          relationshipLabel: 'You',
                          postedDateLabel: 'Rekh-Nedjes 9',
                          entryDateLabel: 'Paopi 8 · 2026',
                          onOpenAuthor: () {},
                          onReadMore: () => opened++,
                          onRemove: () => removed++,
                        ),
                        const SizedBox(height: 18),
                        const PostedFlowArtifact(
                          name: 'Dawn House Rite',
                          color: 0xFFAA723B,
                          notes:
                              'The Dawn House Rite is grounded in one of the clearest Egyptian sacred time-patterns.',
                          appearance: FlowAppearance.empty,
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
          final insightCard = find.byKey(
            const ValueKey('posted-insight-artifact'),
          );
          final flowCard = find.byKey(const ValueKey('posted-flow-artifact'));
          expect(tester.getSize(insightCard), tester.getSize(flowCard));
          expect(
            tester.getSize(insightCard).height,
            236 + 84 * (textScale - 1),
          );
          expect(
            tester.getBottomLeft(find.text(displayedExcerpt)).dy,
            lessThan(tester.getTopLeft(insightCard).dy),
          );
          expect(
            tester.getTopLeft(find.text('Remove')).dy,
            greaterThan(tester.getBottomLeft(insightCard).dy),
          );
          expect(find.text('Posted Insight'), findsNothing);
          expect(find.text(post.bodyText), findsOneWidget);
          expect(find.text('Read more').hitTestable(), findsOneWidget);
          await capture(
            tester,
            '$kind-insight-${width.toInt()}-${textScale.toInt()}x',
          );
          await tester.tap(find.text('Read more'));
          await tester.tap(
            find.byKey(
              const ValueKey('open-profile-insight-post-visual-insight'),
            ),
          );
          await tester.tap(find.text('Remove'));
          expect(opened, 2);
          expect(removed, 1);
        });
      }
    }
  }
}
