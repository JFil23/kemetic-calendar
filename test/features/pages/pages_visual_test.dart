import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flow_appearance.dart';
import 'package:mobile/features/pages/pages_layout.dart';
import 'package:mobile/features/pages/pages_board.dart';
import 'package:mobile/features/pages/pages_models.dart';

void main() {
  testWidgets('approved eight-board geometry at phone width', (tester) async {
    tester.view.physicalSize = const Size(393, 930);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final f in [
      ('CormorantGaramond', 'CormorantGaramond-Regular.ttf'),
      ('GentiumPlus', 'GentiumPlus-Regular.ttf'),
      ('Inter', 'Inter-Variable.ttf'),
      (
        'Noto Sans Egyptian Hieroglyphs',
        'NotoSansEgyptianHieroglyphs-Regular.ttf',
      ),
    ]) {
      await (FontLoader(
        f.$1,
      )..addFont(rootBundle.load('ios/Runner/Fonts/${f.$2}'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    const math = PagesFlow(
      id: 'math',
      name: 'Daily Math Visuals: 90-Day Visual Math Ladder',
      appearance: FlowAppearance(signKind: FlowSignKind.palmCount),
      color: 0xffff6b6b,
      total: 88,
      completed: 6,
    );
    const writing = PagesFlow(
      id: 'writing',
      name: 'Spanish Practice',
      appearance: FlowAppearance(signKind: FlowSignKind.shen),
      color: 0xff5588ff,
      total: 20,
      completed: 12,
    );
    final cards = <PagesCard>[
      PagesCard(
        PagesDestination.calendar,
        state: PagesLoadState.ready,
        primary: const PagesSignal('Paopi', detail: 'Akhet 2'),
        meta: '6 today',
        weekdays: const ['S', 'M', 'T', 'W', 'T', 'F', 'S', 'S', 'M', 'T'],
        days: List.generate(
          30,
          (i) => PagesCalendarDay(
            i + 1,
            today: i == 10,
            past: i < 10,
            colors: i % 4 == 0 ? [0xff89ba77, 0xff9674cf] : [],
          ),
        ),
      ),
      const PagesCard(
        PagesDestination.feed,
        state: PagesLoadState.ready,
        flow: math,
        meta: 'Your shared flow · 3 days ago',
        upper: PagesSignal(
          'Latest shared flow',
          label: 'Your flows',
          glyphIds: ['i', 'receive', 'aset'],
        ),
        lower: PagesSignal(
          'Find a group',
          label: 'Commons',
          detail: 'Practice together',
          color: 0xff3fa98a,
        ),
      ),
      const PagesCard(
        PagesDestination.planner,
        state: PagesLoadState.ready,
        meta: '0% aligned · no to-dos',
        primary: PagesSignal('', progress: 0),
        upper: PagesSignal('Say no to burnout'),
        lower: PagesSignal(
          'Cold compress',
          label: 'Nutrition',
          detail: 'Tomorrow · 8 AM',
        ),
      ),
      const PagesCard(
        PagesDestination.journal,
        state: PagesLoadState.ready,
        meta: '1 badge · 3 days this week',
        primary: PagesSignal('Evening Reflection', color: 0xff6344d3),
        upper: PagesSignal('Paopi 11', label: 'Today', detail: '✓ Saved'),
        week: [false, true, false, false, true, false, true],
      ),
      const PagesCard(
        PagesDestination.studio,
        state: PagesLoadState.ready,
        meta: 'Spanish Practice · 60%',
        flow: writing,
        upper: PagesSignal(
          'Writing Practice',
          label: 'Next event',
          detail: 'Tomorrow · 9 AM',
          color: 0xff8199bd,
        ),
        lower: PagesSignal('8', detail: 'steps left', color: 0xff8199bd),
      ),
      const PagesCard(
        PagesDestination.inbox,
        state: PagesLoadState.ready,
        meta: 'All caught up',
        primary: PagesSignal(
          'producedbyearth',
          detail: 'Accepted your invite',
          glyphIds: ['i', 'receive', 'aset'],
        ),
        upper: PagesSignal('L.', detail: 'Followed you', glyphIds: ['sun']),
        lower: PagesSignal('Reading House', glyph: '𓉐', color: 0xff3fa98a),
      ),
      const PagesCard(
        PagesDestination.calendars,
        state: PagesLoadState.ready,
        meta: '6 calendars',
        primary: PagesSignal(
          'BigJFil’s',
          detail: '3 members',
          people: [
            PagesPerson('BigJFil', glyphIds: ['i', 'receive', 'aset']),
            PagesPerson('L.', glyphIds: ['sun']),
            PagesPerson('Member', glyphIds: ['maat']),
          ],
          color: 0xff8e7cff,
        ),
        upper: PagesSignal('Reading House', glyph: '𓉐', color: 0xff3fa98a),
        calendars: [
          (color: 0xff8e7cff, visible: true),
          (color: 0xff3fa98a, visible: true),
          (color: 0xffd4649b, visible: true),
          (color: 0xffccac44, visible: false),
          (color: 0xff61adbd, visible: true),
          (color: 0xff957269, visible: false),
        ],
      ),
      const PagesCard(
        PagesDestination.library,
        state: PagesLoadState.ready,
        meta: 'Continue reading · 8%',
        primary: PagesSignal(
          'Ptah',
          glyph: '𓁰',
          progress: 8,
          detail: '8% read',
        ),
        upper: PagesSignal('Cosmic Order', label: 'Complete'),
        lower: PagesSignal('Ma’at', progress: 12),
      ),
    ].map(ValueNotifier.new).toList();
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: PagesLayout(
            cards: cards,
            onOpen: (_) {},
            onProfile: () {},
            onNewNote: () {},
            onSearchResult: (_) {},
            searchRecords: () => [
              const PagesSearchRecord('Ptah', 'Library', '/nodes/ptah'),
            ],
            profileName: 'BigJFil',
            profileGlyphIds: const ['i', 'receive', 'aset'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final capturePath = Platform.environment['HAW_PAGES_CAPTURE_PATH'];
    if (capturePath != null) {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(capturePath).writeAsBytes(bytes!.buffer.asUint8List());
      });
    }
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Flow Studio'), findsOneWidget);
    final tiles = find.byType(PagesTile);
    final left = tester.getRect(tiles.at(0));
    final right = tester.getRect(tiles.at(1));
    expect(left.left, 6);
    expect(right.left - left.right, 8);
    final board = find
        .descendant(of: tiles.at(0), matching: find.byType(AspectRatio))
        .first;
    final rect = tester.getRect(board);
    expect(rect.width / rect.height, closeTo(1.49, .001));
    final secondRow = tester.getRect(tiles.at(2));
    expect(secondRow.top - left.bottom, closeTo(22, .001));
    await tester.enterText(find.byType(TextField), 'Ptah');
    await tester.pump();
    expect(find.text('Showing what’s already loaded'), findsOneWidget);
    expect(find.byType(PagesTile), findsNothing);
    expect(find.text('Ptah'), findsWidgets);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    for (final width in [320.0, 430.0, 844.0]) {
      tester.view.physicalSize = Size(width, 852);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
    await tester.pumpWidget(const SizedBox());
    for (final card in cards) {
      card.dispose();
    }
  });
}
