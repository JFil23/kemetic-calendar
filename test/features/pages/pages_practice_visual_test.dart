import 'package:mobile/features/pages/pages_layout.dart';
import 'package:mobile/features/pages/pages_models.dart';
import 'package:mobile/features/pages/pages_board.dart';
import 'package:mobile/features/pages/pages_feed_rotation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/commons_models.dart';
import 'package:mobile/features/profile/commons_practice_card.dart';

CommonsPracticeRoom practiceFixture({bool privateNames = false}) =>
    CommonsPracticeRoom.fromJson({
      'id': 'room',
      'title': '10-Day Spanish Practice Flow',
      'calendar_id': 'calendar',
      'created_by': 'owner',
      'source_flow_id': 10,
      'status': 'active',
      'visibility': 'public',
      'join_policy': 'owner_approval',
      'member_count': 3,
      'viewer_can_request_join': true,
      'public_members': privateNames
          ? []
          : [
              {
                'user_id': 'a',
                'display_name': 'Reader',
                'avatar_glyphs': ['sun'],
              },
              {
                'user_id': 'b',
                'display_name': 'Writer',
                'avatar_glyphs': ['maat'],
              },
            ],
    });

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final f in fonts) {
      final loader = FontLoader(f['family']);
      for (final a in f['fonts']) {
        loader.addFont(rootBundle.load(a['asset']));
      }
      await loader.load();
    }
  });
  testWidgets(
    'Commons practice pane preserves identity, privacy and compact scale',
    (tester) async {
      for (final width in [150.0, 186.5, 205.0]) {
        for (final privateNames in [false, true]) {
          final key = GlobalKey();
          var taps = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.dark,
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: width,
                    height: width / 1.49,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => taps++,
                      child: RepaintBoundary(
                        key: key,
                        child: CommonsPracticeCard(
                          room: practiceFixture(privateNames: privateNames),
                          pane: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Public group flow'), findsOneWidget);
          expect(find.text('10-Day Spanish Practice Flow'), findsOneWidget);
          expect(find.text('Practice Together'), findsOneWidget);
          expect(
            find.text(
              privateNames ? '3 practicing · names kept private' : '3 members',
            ),
            findsOneWidget,
          );
          expect(find.byType(TextButton), findsNothing);
          await tester.tap(find.byType(GestureDetector).first);
          expect(taps, 1);
          expect(
            tester.takeException(),
            isNull,
            reason: '$width / private=$privateNames',
          );
          final dir = Platform.environment['HAW_PANES_CAPTURE_DIR'];
          if (width == 186.5 && !privateNames && dir != null) {
            unawaited(tester.binding.reassembleApplication());
            await tester.pumpAndSettle();
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            void repaint(RenderObject node) {
              node.markNeedsPaint();
              node.visitChildren(repaint);
            }

            repaint(boundary);
            await tester.pump();
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 3);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              Directory(dir).createSync(recursive: true);
              File(
                '$dir/feed-practice.png',
              ).writeAsBytesSync(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
      }
    },
  );
  testWidgets(
    'Feed updates wait for touch release and keep canonical navigation',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cards = [
        for (final d in PagesDestination.values) ValueNotifier(PagesCard(d)),
      ];
      final feed = cards[PagesDestination.feed.index];
      feed.value = const PagesCard(
        PagesDestination.feed,
        state: PagesLoadState.ready,
        question: CommonsQuestion(id: 'today', question: 'Today’s reflection'),
      );
      PagesDestination? opened;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: PagesLayout(
            cards: cards,
            onOpen: (d) => opened = d.destination,
            onProfile: () {},
            onNewNote: () {},
            onSearchResult: (_) {},
            searchRecords: () => [],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PagesTile).at(1)),
      );
      feed.value = PagesCard(
        PagesDestination.feed,
        state: PagesLoadState.ready,
        feedDisplay: PagesFeedDisplay.practice,
        practice: practiceFixture(),
      );
      await tester.pump();
      expect(find.text('Today’s reflection'), findsOneWidget);
      expect(find.byType(CommonsPracticeCard), findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(CommonsPracticeCard), findsOneWidget);
      expect(opened, PagesDestination.feed);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      for (final card in cards) {
        card.dispose();
      }
    },
  );
  testWidgets('full Commons card retains its canonical actions and roster', (
    tester,
  ) async {
    var likes = 0, joins = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 361,
              height: 318,
              child: CommonsPracticeCard(
                room: practiceFixture(),
                onLike: () => likes++,
                likeCount: 4,
                viewerAction: TextButton(
                  onPressed: () => joins++,
                  child: const Text('Practice Together'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reader, Writer · + 1 private'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('commons_group_like_room')));
    await tester.tap(find.text('Practice Together'));
    expect(likes, 1);
    expect(joins, 1);
    expect(tester.takeException(), isNull);
  });
}
