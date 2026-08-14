import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/features/calendar/calendar_epoch_viewport.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/calendar_scroll_coordinator.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/widgets/month_name_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app:has_seen_onboarding': true,
      'app:onboarding:completed': true,
    });
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'test-anon-key',
      httpClient: _RejectingClient(),
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: false,
      ),
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app:has_seen_onboarding': true,
      'app:onboarding:completed': true,
    });
  });

  testWidgets('production calendar records an aggregate shadow traversal', (
    tester,
  ) async {
    await Supabase.instance.client.auth.recoverSession(_sessionJson());
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pageKey = GlobalKey<CalendarPageState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CalendarPage(key: pageKey)),
      ),
    );
    pageKey.currentState!.debugShowCalendarShellForTesting();
    await tester.pump();
    await tester.pump();

    final scrollView = find.byType(CalendarEpochScrollView).first;
    for (var index = 0; index < 9; index++) {
      await tester.drag(scrollView, const Offset(0, -420));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pump(const Duration(milliseconds: 500));

    final coordinator = pageKey.currentState!.debugCalendarScrollCoordinator;
    final counts = coordinator.divergenceCounts;
    final summary = <String, int>{
      for (final category in CalendarShadowDivergenceCategory.values)
        category.name: counts[category]!,
    };
    debugPrint(
      '[phase3-shadow-summary] committed='
      '${coordinator.debugCommittedSampleCount} '
      'staleGeneration=${coordinator.debugStaleGenerationRejectionCount} '
      'staleSerial=${coordinator.debugStaleScrollSerialRejectionCount} '
      'categories=$summary',
    );

    expect(coordinator.debugCommittedSampleCount, greaterThan(0));
    expect(coordinator.trace, isNotEmpty);
    final activeBannerMonth = coordinator.activeBannerMonth.value;
    final expectedBannerText = getMonthById(
      activeBannerMonth.month,
    ).displayShort;
    final activeBanner = find.byWidgetPredicate(
      (widget) =>
          widget is MonthNameText &&
          widget.key == const Key('scrolling-calendar-month-name') &&
          widget.text == expectedBannerText,
    );
    expect(activeBanner, findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}

String _sessionJson() {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final header = base64Url.encode(utf8.encode('{"alg":"none","typ":"JWT"}'));
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, Object?>{
        'sub': 'bd3f58ef-efdf-4990-b9a6-42ebf82aa8c8',
        'email': 'shadow-smoke@example.com',
        'aud': 'authenticated',
        'role': 'authenticated',
        'iat': now,
        'exp': now + 3600,
      }),
    ),
  );
  return jsonEncode(<String, Object?>{
    'access_token': '$header.$payload.',
    'refresh_token': 'test-refresh-token',
    'expires_in': 3600,
    'expires_at': now + 3600,
    'token_type': 'bearer',
    'user': <String, Object?>{
      'id': 'bd3f58ef-efdf-4990-b9a6-42ebf82aa8c8',
      'email': 'shadow-smoke@example.com',
      'aud': 'authenticated',
      'role': 'authenticated',
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
      'created_at': '2026-01-01T00:00:00.000Z',
    },
  });
}

final class _RejectingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable(const []),
      500,
      request: request,
    );
  }
}
