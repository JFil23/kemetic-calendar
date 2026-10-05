import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:mobile/features/pages/pages_board.dart';
import 'package:mobile/features/pages/pages_layout.dart';
import 'package:mobile/features/pages/pages_models.dart';
import 'package:mobile/main.dart' show MyApp;
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/widgets/utility_sheet_route_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/pages/pages_resource_test.dart' show session;
import '../support/maat_flow_visual_test_fonts.dart';

const _captureKey = ValueKey('ipad-root-capture');
const _probeKey = ValueKey('ipad-text-scaler-probe');
const _sheetKey = ValueKey('ipad-detail-content');
const _heroKey = ValueKey('ipad-detail-hero');

// A nonlinear accessibility setting must pass through unchanged; sampling only
// one font size and rebuilding a linear scaler loses the user's size curve.
class _NonlinearTextScaler extends TextScaler {
  const _NonlinearTextScaler();

  @override
  double scale(double fontSize) => fontSize * (fontSize <= 16 ? 1.6 : 1.3);

  @override
  double get textScaleFactor => 1.6;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadMaatFlowVisualTestFonts();
    SharedPreferences.setMockInitialValues({});
    AppRestorationService.debugUserIdResolver = () => null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'com.llfbandit.app_links/messages',
      'com.llfbandit.app_links/events',
      'receive_sharing_intent/messages',
      'receive_sharing_intent/events-media',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
        if (name.startsWith('receive_sharing_intent/') &&
            name.contains('/events') &&
            call.method == 'listen') {
          scheduleMicrotask(
            () => messenger.handlePlatformMessage(name, null, (_) {}),
          );
        }
        return null;
      });
    }
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.kemetic.calendar/device_import_v1'),
      (call) async => switch (call.method) {
        'deviceId' => 'tablet-layout-fixture',
        'permissionStatus' => 'notDetermined',
        _ => null,
      },
    );
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'fixture-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final body = request.url.path.endsWith('/external_calendar')
            ? '{"available":false,"connection":null,"sources":[]}'
            : request.url.path.endsWith('get_together_inbox') ||
                  request.url.path.endsWith('get_commons_together_home_cards')
            ? '{}'
            : '[]';
        return http.Response(
          body,
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await Supabase.instance.client.auth.recoverSession(session());
  });

  tearDownAll(() async {
    AppRestorationService.debugUserIdResolver = null;
    await Supabase.instance.dispose();
  });

  const sizes = <String, Size>{
    'phone-375x667': Size(375, 667),
    'phone-390x844': Size(390, 844),
    'phone-430x932': Size(430, 932),
    'phone-844x390': Size(844, 390),
    'split-599x1024': Size(599, 1024),
    'split-600x1024': Size(600, 1024),
    'ipad-768x1024': Size(768, 1024),
    'ipad-820x1180': Size(820, 1180),
    'ipad-1024x768': Size(1024, 768),
    'ipad-1180x820': Size(1180, 820),
  };

  for (final entry in sizes.entries) {
    testWidgets('real app preserves Pages geometry at ${entry.key}', (
      tester,
    ) async {
      final cards = _cards().map(ValueNotifier.new).toList();
      final router = _router(
        PagesLayout(
          cards: cards,
          profileName: 'BigJFil',
          profileHandle: 'bigjfil',
          profileGlyphIds: const ['i', 'receive', 'aset'],
          onOpen: (_) {},
          onProfile: () {},
          onNewNote: () {},
          onSearchResult: (_) {},
          searchRecords: () => const [],
        ),
      );
      await _pumpApp(tester, router, entry.value);
      await _capture(tester, 'pages-${entry.key}');
      final errors = tester.takeException();
      final actualScale = MediaQuery.textScalerOf(
        tester.element(find.byKey(_probeKey)),
      );
      final captionBounds = <(Rect, Rect)>[];
      for (final tile in find.byType(PagesTile).evaluate()) {
        final card = (tile.widget as PagesTile).card;
        final caption = find.descendant(
          of: find.byWidget(tile.widget),
          matching: find.text(card.meta),
        );
        captionBounds.add((
          tester.getRect(find.byWidget(tile.widget)),
          tester.getRect(caption),
        ));
      }
      await _closeApp(tester, router);
      for (final card in cards) {
        card.dispose();
      }
      expect(errors, isNull, reason: 'Pages must fit the real app text scale');
      expect(actualScale.scale(16), 16);
      for (final (tile, caption) in captionBounds) {
        expect(caption.bottom, lessThanOrEqualTo(tile.bottom + .01));
      }
    });

    testWidgets(
      'real app keeps default detail content visible at ${entry.key}',
      (tester) async {
        final router = _router(_detail());
        await _pumpApp(tester, router, entry.value);
        await _capture(tester, 'detail-${entry.key}');
        final errors = tester.takeException();
        final compactLandscape =
            entry.value.width > entry.value.height && entry.value.height < 600;
        if (compactLandscape) {
          // The authored hero retains its readable content height. On a
          // short phone, the same scroll view must bring the body into view.
          final titleBounds = tester.getRect(find.text('Follow the Sky'));
          expect(titleBounds.top, greaterThanOrEqualTo(0));
          expect(titleBounds.bottom, lessThan(entry.value.height));
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -350),
          );
          await tester.pump(const Duration(milliseconds: 500));
          await _capture(tester, 'detail-${entry.key}-scrolled');
          expect(tester.takeException(), isNull);
        }
        final sheet = find.byKey(_sheetKey);
        final sheetTop = sheet.evaluate().isEmpty
            ? double.infinity
            : tester.getTopLeft(sheet).dy;
        final heroHeight = tester.getSize(find.byKey(_heroKey)).height;
        await _closeApp(tester, router);
        expect(errors, isNull);
        expect(sheetTop, lessThan(entry.value.height * .75));
        expect(
          heroHeight,
          lessThanOrEqualTo(
            compactLandscape
                ? MaatFlowDetailGeometry.heroHeight
                : entry.value.height,
          ),
        );
      },
    );
  }

  testWidgets('live rotation and Split View retain the same root and scale', (
    tester,
  ) async {
    final router = _router(const Scaffold(body: Text('Resize')));
    await _pumpApp(tester, router, const Size(820, 1180));
    final rootState = tester.state(find.byType(MyApp));
    for (final size in const [
      Size(1180, 820),
      Size(599, 1024),
      Size(600, 1024),
      Size(820, 1180),
    ]) {
      await _pumpApp(tester, router, size);
      expect(tester.state(find.byType(MyApp)), same(rootState));
      final media = MediaQuery.of(tester.element(find.byKey(_probeKey)));
      expect(media.size, size);
      expect(media.textScaler.scale(16), 16);
      expect(tester.takeException(), isNull);
    }
    await _closeApp(tester, router);
  });

  for (final scaler in const <TextScaler>[
    TextScaler.linear(1.3),
    TextScaler.linear(2),
    _NonlinearTextScaler(),
  ]) {
    testWidgets('real tablet app preserves accessibility scaler $scaler', (
      tester,
    ) async {
      final router = _router(const Scaffold(body: Text('Accessibility')));
      await _pumpApp(tester, router, const Size(820, 1180), scaler: scaler);
      final actual = MediaQuery.textScalerOf(
        tester.element(find.byKey(_probeKey)),
      );
      await _closeApp(tester, router);
      expect(tester.takeException(), isNull);
      for (final fontSize in <double>[11, 16, 24, 36]) {
        expect(actual.scale(fontSize), scaler.scale(fontSize));
      }
    });
  }
}

GoRouter _router(Widget child) => GoRouter(
  initialLocation: '/tablet-layout-fixture',
  routes: [
    GoRoute(
      path: '/tablet-layout-fixture',
      builder: (_, _) => KeyedSubtree(key: _probeKey, child: child),
    ),
  ],
);

Future<void> _pumpApp(
  WidgetTester tester,
  GoRouter router,
  Size size, {
  TextScaler scaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Optional comparison input replays the removed tablet multiplier. The same
  // assertions remain active, so a prior-scale capture is an expected failure.
  final replayPriorScale =
      Platform.environment['HAW_IPAD_REPLAY_PRIOR_SCALE'] == '1' &&
      size.shortestSide >= 600;
  final inheritedScaler = replayPriorScale
      ? TextScaler.linear(scaler.scale(16) / 16 * 1.5)
      : scaler;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: inheritedScaler),
      child: RepaintBoundary(
        key: _captureKey,
        child: MyApp(router: router, calendarLinkEnvironment: 'staging'),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _closeApp(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 3));
  await tester.runAsync(() async {
    final client = Supabase.instance.client;
    await client.removeAllChannels();
    await client.realtime.disconnect();
    client.realtime.reconnectTimer.reset();
  });
  router.dispose();
}

Future<void> _capture(WidgetTester tester, String name) async {
  final output = Platform.environment['HAW_IPAD_CAPTURE_DIR'];
  if (output == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  await tester.runAsync(() async {
    await Directory(output).create(recursive: true);
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

List<PagesCard> _cards() => [
  PagesCard(
    PagesDestination.calendar,
    state: PagesLoadState.ready,
    meta: '6 today',
    primary: const PagesSignal('Rekh-Nedjes', detail: 'Peret 2026'),
    calendarDate: DateTime(2026, 9, 26),
    weekdays: const ['S', 'M', 'T', 'W', 'T', 'F', 'S', 'S', 'M', 'T'],
    days: List.generate(30, (i) => PagesCalendarDay(i + 1, today: i == 10)),
  ),
  for (final destination in PagesDestination.values.skip(1))
    PagesCard(
      destination,
      state: PagesLoadState.ready,
      meta: switch (destination) {
        PagesDestination.feed => 'Question of the day',
        PagesDestination.planner => '0% aligned',
        PagesDestination.journal => 'No badges today',
        PagesDestination.studio => '9/28 · 7:30 am · Spanish Practice',
        PagesDestination.inbox => 'Accepted your invitation',
        PagesDestination.calendars => '6 calendars',
        _ => 'Continue · Ptah, 8%',
      },
      primary: PagesSignal(
        destination == PagesDestination.inbox ? 'producedbyearth' : 'Ptah',
        detail: 'Practice together',
        progress: destination == PagesDestination.planner ? 0 : null,
        glyph: '𓁰',
      ),
      upper: const PagesSignal('Reading House', detail: 'Today'),
      lower: const PagesSignal('Daily practice', detail: 'Tomorrow'),
    ),
];

Widget _detail() => UtilitySheetRouteScaffold(
  semanticLabel: 'Flow detail fixture',
  showRouteChrome: false,
  onClose: () {},
  child: MaatFlowDetailShell(
    theme: const MaatFlowDetailTheme(
      pageBackground: Color(0xFF050504),
      sheetBackground: Color(0xFF080706),
      sheetBorder: Color(0x2ED4AE43),
      accent: Color(0xFFD4AE43),
      primaryText: Color(0xFFC8C4BC),
      secondaryText: Color(0xFF9E9A94),
      mutedText: Color(0xFF6A6660),
      separator: Color(0xFF2A2415),
      glow: Color(0xFFA4B1FF),
    ),
    scaleHeroWithText: true,
    hero: const ColoredBox(
      key: _heroKey,
      color: Color(0xFF0C1023),
      child: Center(
        child: Text(
          'Follow the Sky',
          style: TextStyle(fontFamily: 'CormorantGaramond', fontSize: 36),
        ),
      ),
    ),
    sheetKey: _sheetKey,
    sheet: const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Carry the sky into your day', style: TextStyle(fontSize: 24)),
          SizedBox(height: 16),
          Text(
            'Watch the changing light, moon and visible planets. '
            'Choose a turning and protect time to observe.',
            style: TextStyle(fontSize: 18),
          ),
          SizedBox(height: 500),
        ],
      ),
    ),
  ),
);
