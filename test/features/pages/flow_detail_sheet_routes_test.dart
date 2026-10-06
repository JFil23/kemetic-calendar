import 'dart:async';
import 'dart:math' as math;
import '../../support/maat_flow_visual_test_fonts.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:mobile/data/share_models.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/main.dart' show createAppRouterForTesting;
import 'package:mobile/widgets/utility_sheet_route_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  void mockAppLinks() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'com.llfbandit.app_links/messages',
      'com.llfbandit.app_links/events',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (_) async => null,
      );
    }
  }

  setUpAll(() async {
    // Supabase begins its deep-link listener during initialization.
    mockAppLinks();
    await loadMaatFlowVisualTestFonts();
    // Decode the real bundled catalog outside widget tests' fake async zones.
    await rootBundle.loadString(
      'assets/follow_the_sky/sky_catalog_v2_graphics_v1.json',
    );
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'fixture-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(mockAppLinks);

  const links = <(String, String, String)>[
    ('/shared-flow/by-flow/:flowId', '/shared-flow/by-flow/42', '/pages'),
    ('/shared-flow/:shareId', '/shared-flow/missing-share', '/inbox'),
    ('/flow-post/:postId', '/flow-post/missing-post', '/profile/me'),
  ];
  for (final link in links) {
    for (final restored in [false, true]) {
      testWidgets('${link.$1} is a sheet, restored=$restored', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final appRouter = createAppRouterForTesting();
        final actualRoute = appRouter.configuration.routes
            .whereType<GoRoute>()
            .singleWhere((route) => route.path == link.$1);
        final router = GoRouter(
          initialLocation: restored ? link.$2 : '/pages',
          routes: [
            for (final path in ['/pages', '/inbox', '/profile/me'])
              GoRoute(
                path: path,
                builder: (_, _) => Scaffold(body: Text('Underlying $path')),
              ),
            actualRoute,
          ],
        );
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        if (!restored) {
          unawaited(
            router.push<void>(
              link.$2,
              extra: const {'fallbackLocation': '/pages'},
            ),
          );
        }
        await tester.pumpAndSettle();
        expect(find.byType(UtilitySheetRouteScaffold), findsOneWidget);
        expect(find.byTooltip('Close Flow details'), findsOneWidget);
        final material = find
            .descendant(
              of: find.byType(UtilitySheetRouteScaffold),
              matching: find.byType(ClipRRect),
            )
            .first;
        final bounds = tester.getRect(material);
        expect(bounds.top, greaterThan(0));
        expect(bounds.bottom, 844);
        expect(bounds.width, 390);
        if (!restored) {
          // A full-page opaque route would remove this from the visible tree.
          expect(find.text('Underlying /pages'), findsOneWidget);
        }
        await tester.tap(find.byKey(utilitySheetRouteCloseButtonKey));
        await tester.pumpAndSettle();
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          restored ? link.$3 : '/pages',
        );
        expect(find.byType(UtilitySheetRouteScaffold), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        appRouter.dispose();
      });
    }
  }
  for (final flow in <(String, String)>[
    ('track-the-sky', 'Follow the Sky'),
    ('offering-table', 'The Offering Table'),
    ('reading-house', 'The Reading House'),
    ('the-djed', 'The Djed'),
    ('the-kar', 'The Kꜣr'),
  ]) {
    for (final viewport in const [
      (Size(375, 667), false, false),
      (Size(390, 844), false, false),
      (Size(430, 932), false, false),
      (Size(844, 390), false, false),
      (Size(599, 1024), false, false),
      (Size(600, 1024), false, false),
      (Size(768, 1024), false, false),
      (Size(820, 1180), false, false),
      (Size(1024, 768), false, false),
      (Size(1024, 580), false, false),
      (Size(1366, 1024), false, false),
      (Size(1024, 768), true, false),
      (Size(375, 667), false, true),
    ]) {
      final size = viewport.$1;
      final withSafeArea = viewport.$2;
      final withBoldText = viewport.$3;
      final safeAreaLabel = withSafeArea ? ' with safe area' : '';
      final boldTextLabel = withBoldText ? ' with bold text' : '';
      testWidgets(
        '${flow.$1} renders in one sheet at $size$safeAreaLabel$boldTextLabel',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          if (withSafeArea) {
            const insets = FakeViewPadding(top: 24, bottom: 20);
            tester.view.padding = insets;
            tester.view.viewPadding = insets;
          }
          addTearDown(tester.view.reset);
          final appRouter = createAppRouterForTesting();
          final actualRoute = appRouter.configuration.routes
              .whereType<GoRoute>()
              .singleWhere((route) => route.path == '/shared-flow/:shareId');
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const Scaffold(body: Text('Background')),
              ),
              actualRoute,
            ],
          );
          await tester.pumpWidget(
            RepaintBoundary(
              key: const ValueKey('capture'),
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                routerConfig: router,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(boldText: withBoldText),
                  child: child!,
                ),
              ),
            ),
          );
          unawaited(
            router.push<void>(
              '/shared-flow/${flow.$1}-${size.width.toInt()}',
              extra: InboxShareItem(
                shareId: '${flow.$1}-${size.width.toInt()}',
                kind: InboxShareKind.flow,
                recipientId: 'recipient',
                senderId: 'sender',
                payloadId: '42',
                title: flow.$2,
                createdAt: DateTime.utc(2026, 9, 1),
                payloadJson: {
                  'name': flow.$2,
                  'notes': 'maat=${flow.$1}',
                  'color': 4283289825,
                  'rules': <dynamic>[],
                  'events': <dynamic>[],
                },
              ),
            ),
          );
          // Follow the Sky can keep animating; advance the route and hydration
          // without requiring every instrument animation to become idle.
          for (var frame = 0; frame < 40; frame++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 25)),
            );
            await tester.pump(const Duration(milliseconds: 250));
            if (find.byType(MaatFlowDetailShell).evaluate().isNotEmpty) break;
          }
          await tester.pump(const Duration(milliseconds: 250));
          expect(find.byType(UtilitySheetRouteScaffold), findsOneWidget);
          expect(
            find.byType(MaatFlowDetailShell),
            findsOneWidget,
            reason: find
                .byType(Text)
                .evaluate()
                .map((element) => (element.widget as Text).data)
                .join(' | '),
          );
          final bounds = tester.getRect(find.byType(MaatFlowDetailShell));
          expect(bounds.top, greaterThan(44));
          // Flow routes share the available width up to 640 points, while
          // retaining the existing phone/tablet outer insets.
          expect(
            bounds.width,
            math.min(640, size.width - (size.shortestSide >= 600 ? 48 : 0)),
          );
          expect(bounds.bottom, lessThanOrEqualTo(size.height));
          expect(find.text('Background'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            for (final element in find.byType(Image).evaluate()) {
              await precacheImage((element.widget as Image).image, element);
            }
          });
          await tester.pump();
          final captureName =
              '${flow.$1}-${size.width.toInt()}x${size.height.toInt()}${withSafeArea ? '-safe-area' : ''}${withBoldText ? '-bold-text' : ''}';
          await _capture(tester, captureName);
          final shortLandscape = size.width > size.height && size.height < 500;
          await _expectHeroIdentityVisible(
            tester,
            flow: flow.$1,
            viewport: size,
            scrollToRead: shortLandscape,
            captureName: captureName,
          );
          if (shortLandscape || size == const Size(1024, 580)) {
            await _expectBodyReachableAboveFixedDock(tester);
            await _capture(tester, '$captureName-body-scrolled');
          }
          await tester.pumpWidget(const SizedBox());
          router.dispose();
          appRouter.dispose();
        },
      );
    }
  }
}

Future<void> _expectHeroIdentityVisible(
  WidgetTester tester, {
  required String flow,
  required Size viewport,
  required bool scrollToRead,
  required String captureName,
}) async {
  final shellFinder = find.byType(MaatFlowDetailShell);
  final shell = tester.widget<MaatFlowDetailShell>(shellFinder);
  final shellBounds = tester.getRect(shellFinder);
  // Normal-height layouts must expose the existing painted sheet immediately.
  // A short landscape can begin before that sliver is built; its preceding
  // measured spacer still provides the same surface boundary.
  if (!scrollToRead) expect(_sheetSurface(tester), findsOneWidget);
  late Finder heroFinder;
  late Finder titleFinder;
  late Finder glyphFinder;
  Finder? subtitleFinder;
  if (flow == 'offering-table') {
    // Offering Table has its own authored hero instead of the shared hero.
    heroFinder = find.byKey(const ValueKey('offering-table-hero'));
    titleFinder = find.descendant(
      of: heroFinder,
      matching: find.text('The Offering\nTable'),
    );
    glyphFinder = find.byKey(const ValueKey('offering-table-hero-glyph'));
    subtitleFinder = find.descendant(
      of: heroFinder,
      matching: find.text('Feed what needs to be fed.'),
    );
  } else {
    heroFinder = find.byType(MaatFlowDetailHero);
    expect(heroFinder, findsOneWidget);
    final hero = tester.widget<MaatFlowDetailHero>(heroFinder);
    titleFinder = find.descendant(
      of: heroFinder,
      matching: find.text(hero.title),
    );
    if (hero.subtitle.isNotEmpty) {
      subtitleFinder = find.descendant(
        of: heroFinder,
        matching: find.text(hero.subtitle),
      );
    }
    // Check the whole glyph disc, including its transformed position, rather
    // than just the smaller glyph text painted at its center.
    glyphFinder = find.descendant(
      of: heroFinder,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints ==
                const BoxConstraints.tightFor(width: 52, height: 52),
      ),
    );
  }
  expect(heroFinder, findsOneWidget);
  expect(titleFinder, findsOneWidget);
  expect(glyphFinder, findsOneWidget);
  expect(
    tester.getRect(titleFinder).overlaps(tester.getRect(glyphFinder)),
    isFalse,
    reason: '$flow at $viewport: the hero title must not overlap its glyph',
  );
  final backFinder = find.byTooltip('Back');
  expect(backFinder, findsOneWidget);
  for (final subject in [
    (name: 'full hero title', finder: titleFinder),
    (name: 'hero glyph disc', finder: glyphFinder),
    if (subtitleFinder != null)
      (name: 'full hero subtitle', finder: subtitleFinder),
  ]) {
    expect(subject.finder, findsOneWidget);
    final reason = '$flow at $viewport: ${subject.name}';
    if (scrollToRead) {
      await _scrollSubjectAboveDock(tester, subject.finder);
      await _capture(
        tester,
        '$captureName-${subject.name.replaceAll(' ', '-')}-scrolled',
      );
    }
    final bounds = tester.getRect(subject.finder);
    final heroBounds = tester.getRect(heroFinder);
    final backBounds = tester.getRect(backFinder);
    expect(bounds.top, greaterThanOrEqualTo(heroBounds.top), reason: reason);
    expect(bounds.bottom, lessThanOrEqualTo(heroBounds.bottom), reason: reason);
    expect(bounds.left, greaterThanOrEqualTo(shellBounds.left), reason: reason);
    expect(bounds.right, lessThanOrEqualTo(shellBounds.right), reason: reason);
    expect(
      bounds.bottom,
      // Djed's authored subtitle has a one-pixel overlap at the reference
      // size. Preserve that treatment while rejecting tablet-sized occlusion.
      lessThanOrEqualTo(
        _sheetTop(tester) + (subject.name == 'full hero subtitle' ? 2 : 0.01),
      ),
      reason: '$reason must not be covered by the sheet surface',
    );
    expect(
      bounds.overlaps(backBounds),
      isFalse,
      reason: '$reason must not overlap Back',
    );
    if (scrollToRead) {
      final dock = tester.getRect(find.byWidget(shell.bottomDock!));
      expect(bounds.top, greaterThanOrEqualTo(shellBounds.top), reason: reason);
      expect(
        bounds.bottom,
        lessThanOrEqualTo(dock.top),
        reason: '$reason must be fully readable above the fixed action dock',
      );
      // Decorative hero text can sit behind the scroll hit layer. Assert
      // painted visibility, not whether the text itself receives a tap.
      for (final opacity in tester.widgetList<Opacity>(
        find.ancestor(of: subject.finder, matching: find.byType(Opacity)),
      )) {
        expect(
          opacity.opacity,
          greaterThan(0),
          reason: '$reason must remain painted',
        );
      }
    }
  }
}

Future<void> _expectBodyReachableAboveFixedDock(WidgetTester tester) async {
  final shellFinder = find.byType(MaatFlowDetailShell);
  final shell = tester.widget<MaatFlowDetailShell>(shellFinder);
  final shellBounds = tester.getRect(shellFinder);
  _scrollPosition(tester).jumpTo(0);
  await tester.pump();
  final dockFinder = find.byWidget(shell.bottomDock!);
  final sheetTopBefore = _sheetTop(tester);
  final dockBefore = tester.getRect(dockFinder);

  await tester.drag(find.byKey(shell.scrollKey), const Offset(0, -300));
  // Follow the Sky's instrument animations may remain active. Give the scroll
  // enough frames to settle without requiring unrelated animations to stop.
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 100));

  expect(_sheetSurface(tester), findsOneWidget);
  final sheetAfter = tester.getRect(_sheetSurface(tester));
  expect(sheetAfter.top, lessThan(sheetTopBefore));
  expect(
    sheetAfter.top,
    lessThan(dockBefore.top),
    reason: 'The body must scroll into the visible region above the dock.',
  );
  expect(sheetAfter.bottom, greaterThan(shellBounds.top));
  expect(
    tester.getRect(dockFinder),
    dockBefore,
    reason: 'The primary action must stay fixed while the body scrolls.',
  );
  expect(tester.takeException(), isNull);
}

Finder _sheetSurface(WidgetTester tester) {
  final shellFinder = find.byType(MaatFlowDetailShell);
  final shell = tester.widget<MaatFlowDetailShell>(shellFinder);
  return find.descendant(
    of: shellFinder,
    matching: find.byWidgetPredicate(
      (widget) => widget is Container && identical(widget.child, shell.sheet),
    ),
  );
}

double _sheetTop(WidgetTester tester) {
  final surface = _sheetSurface(tester);
  if (surface.evaluate().isNotEmpty) return tester.getRect(surface).top;
  final shell = tester.widget<MaatFlowDetailShell>(
    find.byType(MaatFlowDetailShell),
  );
  final scroll = tester.widget<CustomScrollView>(find.byKey(shell.scrollKey));
  final spacer = scroll.slivers.first as SliverToBoxAdapter;
  return tester.getRect(find.byWidget(spacer.child!)).bottom;
}

ScrollPosition _scrollPosition(WidgetTester tester) {
  final shell = tester.widget<MaatFlowDetailShell>(
    find.byType(MaatFlowDetailShell),
  );
  return tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(shell.scrollKey),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position;
}

Future<void> _scrollSubjectAboveDock(
  WidgetTester tester,
  Finder subject,
) async {
  final shellFinder = find.byType(MaatFlowDetailShell);
  final shell = tester.widget<MaatFlowDetailShell>(shellFinder);
  _scrollPosition(tester).jumpTo(0);
  await tester.pump();
  for (var attempt = 0; attempt < 8; attempt++) {
    final bounds = tester.getRect(subject);
    final viewport = tester.getRect(shellFinder);
    final dock = tester.getRect(find.byWidget(shell.bottomDock!));
    final back = tester.getRect(find.byTooltip('Back'));
    if (bounds.top >= viewport.top &&
        bounds.bottom <= dock.top &&
        !bounds.overlaps(back)) {
      return;
    }
    final backOccupiesColumn =
        bounds.left < back.right && bounds.right > back.left;
    final readableTop = math.max(
      viewport.top + 4,
      backOccupiesColumn ? back.bottom + 4 : viewport.top + 4,
    );
    final targetTop = (readableTop + dock.top - 4 - bounds.height) / 2;
    final drag = (targetTop - bounds.top).clamp(-200.0, 200.0);
    await tester.drag(find.byKey(shell.scrollKey), Offset(0, drag));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['FLOW_SHEET_CAPTURE_DIR'];
  if (directory == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
