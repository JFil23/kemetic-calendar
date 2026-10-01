import 'dart:async';
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
  setUpAll(() async {
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
    for (final size in [const Size(390, 844), const Size(1024, 768)]) {
      testWidgets('${flow.$1} renders in one sheet at $size', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
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
        // Match the existing Flow Studio sheet's phone/tablet side insets.
        expect(bounds.width, size.width - (size.shortestSide >= 600 ? 48 : 0));
        expect(bounds.bottom, lessThanOrEqualTo(size.height));
        expect(find.text('Background'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          for (final element in find.byType(Image).evaluate()) {
            await precacheImage((element.widget as Image).image, element);
          }
        });
        await tester.pump();
        final captureDir = Platform.environment['FLOW_SHEET_CAPTURE_DIR'];
        if (captureDir != null) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('capture')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(captureDir).create(recursive: true);
            await File(
              '$captureDir/${flow.$1}-${size.width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        appRouter.dispose();
      });
    }
  }
}
