import 'dart:convert';
import 'package:mobile/data/commons_models.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flow_appearance.dart';
import 'package:mobile/features/pages/pages_layout.dart';
import 'package:mobile/features/pages/pages_board.dart';
import 'package:mobile/features/pages/pages_models.dart';

void main() {
  testWidgets('approved eight-board geometry at phone width', (tester) async {
    tester.view.physicalSize = const Size(1179, 2790);
    tester.view.devicePixelRatio = 3;
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
    final math = PagesFlow(
      id: 'math',
      name: 'Daily Math Visuals: 90-Day Visual Math Ladder',
      appearance: FlowAppearance(signKind: FlowSignKind.palmCount),
      color: 0xffad8146,
      start: DateTime(2026, 9, 20),
      end: DateTime(2026, 12, 18),
      total: 88,
      completed: 6,
    );
    const writing = PagesFlow(
      id: 'writing',
      name: 'Spanish Practice',
      appearance: FlowAppearance(signKind: FlowSignKind.shen),
      color: 4280516568,
      total: 20,
      completed: 6,
    );
    final cards = <PagesCard>[
      PagesCard(
        PagesDestination.calendar,
        state: PagesLoadState.ready,
        primary: const PagesSignal('Rekh-Nedjes', detail: 'Peret 2026'),
        calendarDate: DateTime(2026, 9, 26),
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
      PagesCard(
        PagesDestination.feed,
        state: PagesLoadState.ready,
        flow: math,
        question: const CommonsQuestion(
          id: 'preview',
          question: 'Is my seeing coarsening?',
        ),
        meta: 'Question of the day',
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
        meta: '0% aligned',
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
        meta: 'No badges today',
        primary: PagesSignal(
          'Evening Reflection',
          status: '✓',
          detail: '8 PM',
          color: 0xff8186dc,
        ),
        upper: PagesSignal('Rekh-Nedjes 11', label: 'Today', detail: '✓ Saved'),
        week: [false, true, false, false, true, false, true],
      ),
      const PagesCard(
        PagesDestination.studio,
        state: PagesLoadState.ready,
        meta: '9/28 · 7:30 am · Spanish Practice',
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
        meta: 'Accepted your invitation',
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
        meta: 'Continue · Ptah, 8%',
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
        theme: AppTheme.dark,
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
            profileHandle: 'bigjfil',
            profileGlyphIds: const ['i', 'receive', 'aset'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final capturePath = Platform.environment['HAW_PAGES_CAPTURE_PATH'];
    if (capturePath != null) {
      await expectLater(find.byKey(key), matchesGoldenFile(capturePath));
    }
    expect(find.text('Pages'), findsNothing);
    expect(tester.getCenter(find.text('bigjfil')).dx, lessThan(100));
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Reminders'), findsOneWidget);
    expect(find.text('Flows'), findsOneWidget);
    final searchRect = tester.getRect(find.byType(TextField).first);
    expect(searchRect.left, 6);
    expect(searchRect.right, 387);
    expect(searchRect.height, 44);
    final input = tester.widget<TextField>(find.byType(TextField).first);
    expect(input.decoration!.fillColor, const Color(0x600d0b07));
    expect(find.text('𓉐'), findsWidgets);
    expect(find.text('No badges yet'), findsOneWidget);
    expect(find.text('CALENDAR'), findsOneWidget);
    expect(find.text('FLOW STUDIO'), findsOneWidget);
    for (final card in cards.map((notifier) => notifier.value)) {
      if (card.meta.isEmpty) continue;
      final caption = find.text(card.meta);
      expect(caption, findsOneWidget);
      final text = tester.widget<Text>(caption);
      expect(text.style!.fontSize, 11.2);
      expect(text.style!.color, const Color(0xffa39d92));
    }

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
    expect(secondRow.top - left.bottom, closeTo(3, .001));
    // Only the pane viewport scrolls; header and search retain their bounds.
    tester.view.physicalSize = const Size(1179, 1950);
    await tester.pumpAndSettle();
    final headerBefore = tester.getRect(find.text('bigjfil'));
    final searchBefore = tester.getRect(find.byType(TextField).first);
    final panesBefore = tester.getTopLeft(find.byType(PagesTile).first).dy;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('bigjfil')), headerBefore);
    expect(tester.getRect(find.byType(TextField).first), searchBefore);
    expect(
      tester.getTopLeft(find.byType(PagesTile).first).dy,
      lessThan(panesBefore),
    );
    final paneViewport = tester.getRect(find.byType(CustomScrollView));
    expect(paneViewport.top, searchBefore.bottom);
    await tester.enterText(find.byType(TextField).first, 'Ptah');
    await tester.pump();
    expect(find.text('Showing what’s already loaded'), findsOneWidget);
    expect(find.byType(PagesTile), findsNothing);
    expect(find.text('Ptah'), findsWidgets);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    for (final width in [320.0, 430.0, 844.0]) {
      tester.view.physicalSize = Size(width * 3, 852 * 3);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
    await tester.pumpWidget(const SizedBox());
    for (final card in cards) {
      card.dispose();
    }
  });
}
