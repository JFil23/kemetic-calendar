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
import 'package:mobile/features/calendar/follow_the_sky/services/follow_sky_day_detail.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('approved eight-board geometry at phone width', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() => FollowSkyDayDetail.catalog());
    tester.view.physicalSize = const Size(1179, 2790);
    tester.view.devicePixelRatio = 3;
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
      color: 0xff5588ff,
      total: 20,
      completed: 12,
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
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      void repaint(RenderObject node) {
        node.markNeedsPaint();
        node.visitChildren(repaint);
      }

      repaint(boundary);
      await tester.pump();
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(capturePath).writeAsBytes(bytes!.buffer.asUint8List());
      });
    }
    expect(find.text('Pages'), findsNothing);
    // Removing visual copy must not erase the selected event/update for readers.
    final inboxSemantics = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .firstWhere((s) => s.properties.label == 'Open Inbox');
    expect(inboxSemantics.properties.onTap, isNotNull);
    expect(inboxSemantics.properties.value, contains('Accepted your invite'));
    expect(inboxSemantics.properties.value, contains('producedbyearth'));
    final studioSemantics = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .firstWhere((s) => s.properties.label == 'Open Flow Studio');
    expect(studioSemantics.properties.value, contains('Writing Practice'));
    expect(studioSemantics.properties.value, contains('Tomorrow · 9 AM'));
    expect(find.text('LATEST BADGE'), findsNothing);
    expect(find.text('LATEST UPDATE'), findsNothing);
    expect(find.text('Evening Reflection'), findsOneWidget);
    expect(find.text('Commons'), findsNothing);
    expect(find.text('Writing Practice'), findsNothing);
    expect(find.text('Tomorrow · 9 AM'), findsNothing);
    expect(find.text('Say no to burnout'), findsNothing);
    expect(find.text('Cosmic Order'), findsNothing);
    expect(tester.getCenter(find.text('bigjfil')).dx, closeTo(393 / 2, .1));
    final searchRect = tester.getRect(find.byType(TextField));
    expect(searchRect.left, 6);
    expect(searchRect.right, 387);
    expect(searchRect.height, 44);
    final input = tester.widget<TextField>(find.byType(TextField));
    expect(input.decoration!.fillColor, const Color(0x600d0b07));
    expect(find.text('𓉐'), findsWidgets);
    expect(find.byIcon(Icons.check), findsWidgets);
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
    final studio = cards[PagesDestination.studio.index];
    final originalStudio = studio.value;
    studio.value = PagesCard(
      PagesDestination.studio,
      state: PagesLoadState.ready,
      flow: PagesFlow(
        id: 'sky',
        name: 'Follow the sky',
        appearance: FlowAppearance(),
        maatKey: 'track-the-sky',
        occurrence: PagesUpcomingEvent(
          flowId: 'sky',
          title: 'Full Moon',
          at: DateTime(2026, 9, 26, 20),
          behavior: {
            'kind': 'track_sky_v2',
            'skyEventId': 'full-moon-2026-09-26',
          },
        ),
        total: 65,
        completed: 1,
      ),
      companionFlows: [writing, math],
      meta: 'Follow the sky',
      upper: PagesSignal('Full Moon', label: 'Next event', detail: '8 PM'),
      lower: PagesSignal('64', detail: 'steps left'),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('follow-sky-renderer-lunarPath')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('pages-studio-built-in-art')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    if (capturePath != null) {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      void repaint(RenderObject node) {
        node.markNeedsPaint();
        node.visitChildren(repaint);
      }

      repaint(boundary);
      await tester.pump();
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          capturePath.replaceFirst('.png', '-sky.png'),
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    studio.value = originalStudio;
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ptah');
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
