import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/settings/settings_page.dart';
import 'package:mobile/core/theme/app_theme.dart';
import '../../support/maat_flow_visual_test_fonts.dart';
import '../pages/pages_resource_test.dart' show session;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    for (final name in ['messages', 'events']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('com.llfbandit.app_links/$name'),
            (_) async => null,
          );
    }
    await Supabase.initialize(
      url: 'https://example.supabase.test',
      anonKey: 'fixture',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (r) async => http.Response(
          '[]',
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    await Supabase.instance.client.auth.recoverSession(session());
    await loadMaatFlowVisualTestFonts();
  });
  tearDownAll(() async => Supabase.instance.dispose());

  for (final width in [320.0, 402.0, 768.0]) {
    testWidgets('reflection action fits Settings at $width', (tester) async {
      tester.view.physicalSize = Size(width, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
          GoRoute(path: '/', builder: (_, _) => const Scaffold()),
        ],
      );
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            routerConfig: router,
          ),
        ),
      );
      for (var i = 0; i < 15; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      await Scrollable.ensureVisible(
        tester.element(find.text('Decan reflection')),
        alignment: .15,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Show reflection badge'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Show reflection badge'),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
      final output = Platform.environment['HAW_SETTINGS_CAPTURE'];
      if (output != null) {
        final rendered =
            boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await rendered.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(output).create(recursive: true);
          await File(
            '$output/settings-${width.toInt()}.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      router.dispose();
    });
  }
}
