import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/settings/settings_page.dart';
import 'package:mobile/features/settings/settings_prefs.dart';
import 'package:mobile/features/settings/us_holiday_seeder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/theme/app_theme.dart';
import '../../support/maat_flow_visual_test_fonts.dart';
import '../pages/pages_resource_test.dart' show session, uid;
import '../onboarding/haw_onboarding_recovery_test.dart'
    show RejectingPreferences;
// Exercise rejected platform writes rather than only the preferences memory cache.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

const otherId = '27d63169-a28a-4550-a0a0-8fee0e8e7b96';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final rows = <String, List<Map<String, dynamic>>>{};
  final writes = <http.Request>[];
  var rejectWrite = false;
  var rejectRead = false;
  Completer<void>? delayedRead;
  setUpAll(() async {
    await loadMaatFlowVisualTestFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.test',
      anonKey: 'fixture',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        http.Response reply(Object? body, [int status = 200]) => http.Response(
          jsonEncode(body),
          status,
          request: r,
          headers: {'content-type': 'application/json'},
        );
        final token =
            (r.headers['authorization'] ?? r.headers['Authorization'])
                ?.split(' ')
                .last
                .split('.') ??
            [];
        final account =
            r.url.queryParameters['user_id']?.replaceFirst('eq.', '') ??
            (token.length == 3
                ? jsonDecode(
                        utf8.decode(
                          base64Url.decode(base64Url.normalize(token[1])),
                        ),
                      )['sub']
                      as String
                : uid);
        if (r.url.path.endsWith('/user_events')) {
          if (r.method == 'POST') {
            writes.add(r);
            if (rejectWrite) {
              return reply({'code': '503', 'message': 'unavailable'}, 503);
            }
            final row = Map<String, dynamic>.from(jsonDecode(r.body) as Map)
              ..['id'] = 'holiday-${writes.length}';
            (rows[account] ??= []).removeWhere(
              (e) => e['client_event_id'] == row['client_event_id'],
            );
            rows[account]!.add(row);
            return reply(row);
          }
          if (r.url.queryParameters.containsKey('client_event_id') &&
              r.url.queryParameters['client_event_id']!.startsWith('like.')) {
            final snapshot = List<Map<String, dynamic>>.from(
              rows[account] ?? [],
            );
            await delayedRead?.future;
            if (rejectRead) {
              return reply({'code': '503', 'message': 'unavailable'}, 503);
            }
            return reply(snapshot);
          }
          return reply(null);
        }
        if (r.url.path.endsWith(
          '/delete_user_events_by_client_id_prefix_semantic',
        )) {
          writes.add(r);
          final count = rows[account]?.length ?? 0;
          rows[account] = [];
          return reply(count);
        }
        return reply(
          r.url.path.endsWith('/external_calendar')
              ? {'available': false, 'connection': null, 'sources': []}
              : [],
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() async {
    rows.clear();
    writes.clear();
    rejectWrite = false;
    rejectRead = false;
    delayedRead = null;
    SharedPreferences.setMockInitialValues({
      SettingsPrefs.usHolidaysEnabledKey: true,
    });
    await Supabase.instance.client.auth.recoverSession(session());
  });
  Finder holiday() =>
      find.widgetWithText(SwitchListTile, 'Add U.S. holidays as notes');
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: RepaintBoundary(
          key: const ValueKey('settings-capture'),
          child: const SettingsPage(),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  }

  Map<String, dynamic> note() => {
    'id': 'saved-holiday',
    'user_id': uid,
    'client_event_id': 'holiday:us:2026-10-12:holiday',
    'title': 'Holiday',
    'starts_at': '2026-10-12T09:00:00Z',
    'all_day': true,
  };
  testWidgets(
    'holiday display follows account notes across a mounted account change and restart',
    (tester) async {
      rows[uid] = [note()];
      expect(await UsHolidaySeeder.isEnabled(), isTrue);
      await mount(tester);
      expect(tester.widget<SwitchListTile>(holiday()).value, isTrue);
      await Supabase.instance.client.auth.recoverSession(
        session().replaceAll(uid, otherId),
      );
      await settle(tester);
      expect(tester.widget<SwitchListTile>(holiday()).value, isFalse);
      expect(writes, isEmpty);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          SettingsPrefs.usHolidaysEnabledKey,
        ),
        isTrue,
      );
      await close(tester);
      await mount(tester);
      expect(tester.widget<SwitchListTile>(holiday()).value, isFalse);
      await close(tester);
    },
  );
  testWidgets(
    'late previous-account holiday reads never replace the new account state',
    (tester) async {
      rows[uid] = [note()];
      final old = Completer<void>();
      delayedRead = old;
      await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
      await tester.pump();
      delayedRead = null;
      await Supabase.instance.client.auth.recoverSession(
        session().replaceAll(uid, otherId),
      );
      await settle(tester);
      expect(tester.widget<SwitchListTile>(holiday()).value, isFalse);
      old.complete();
      await settle(tester);
      expect(tester.widget<SwitchListTile>(holiday()).value, isFalse);
      await close(tester);
    },
  );
  testWidgets(
    'pending holiday read leaves the other Settings controls available',
    (tester) async {
      final read = Completer<void>();
      delayedRead = read;
      await mount(tester);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Loading holiday notes...'), findsOneWidget);
      expect(find.text('Terms'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(holiday()).onChanged, isNull);
      read.complete();
      await settle(tester);
      expect(tester.widget<SwitchListTile>(holiday()).onChanged, isNotNull);
      await close(tester);
    },
  );

  testWidgets(
    'unavailable holiday read is not displayed as enabled legacy state',
    (tester) async {
      rejectRead = true;
      await mount(tester);
      expect(tester.widget<SwitchListTile>(holiday()).onChanged, isNull);
      expect(
        find.text('Could not load holiday notes. Reopen Settings to retry.'),
        findsOneWidget,
      );
      await close(tester);
      rejectRead = false;
      await mount(tester);
      expect(tester.widget<SwitchListTile>(holiday()).onChanged, isNotNull);
      await close(tester);
    },
  );
  testWidgets(
    'holiday notes save without the obsolete device preference writer',
    (tester) async {
      await mount(tester);
      final original = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = RejectingPreferences({})
        ..throwFailure = true;
      addTearDown(() => SharedPreferencesStorePlatform.instance = original);
      tester.widget<SwitchListTile>(holiday()).onChanged!(true);
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(tester.widget<SwitchListTile>(holiday()).value, isTrue);
      expect(tester.widget<SwitchListTile>(holiday()).onChanged, isNotNull);
      expect(rows[uid], hasLength(22));
      await close(tester);
    },
  );
  testWidgets(
    'failed holiday writes release busy state and retry their deterministic notes',
    (tester) async {
      await mount(tester);
      rejectWrite = true;
      tester.widget<SwitchListTile>(holiday()).onChanged!(true);
      await settle(tester);
      expect(tester.widget<SwitchListTile>(holiday()).value, isFalse);
      expect(tester.widget<SwitchListTile>(holiday()).onChanged, isNotNull);
      expect(find.text('Applying holiday notes...'), findsNothing);
      rejectWrite = false;
      tester.widget<SwitchListTile>(holiday()).onChanged!(true);
      await settle(tester);
      expect(rows[uid], hasLength(22));
      expect(tester.widget<SwitchListTile>(holiday()).value, isTrue);
      tester.widget<SwitchListTile>(holiday()).onChanged!(false);
      await settle(tester);
      expect(rows[uid], isEmpty);
      expect(tester.widget<SwitchListTile>(holiday()).value, isFalse);
      await close(tester);
    },
  );
  for (final width in [320.0, 820.0]) {
    testWidgets(
      'existing Settings holiday unavailable row fits $width at enlarged text',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        rejectRead = true;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: RepaintBoundary(
              key: const ValueKey('settings-capture'),
              child: const SettingsPage(),
            ),
          ),
        );
        await settle(tester);
        await tester.ensureVisible(holiday());
        await settle(tester);
        expect(tester.takeException(), isNull);
        final path = Platform.environment['HAW_HOLIDAY_CAPTURE_DIR'];
        if (path != null) {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('settings-capture')),
            );
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(path).create(recursive: true);
            await File(
              '$path/holiday-unavailable-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await close(tester);
      },
    );
  }
}
