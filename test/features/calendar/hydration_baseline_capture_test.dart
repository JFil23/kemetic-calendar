import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Deterministic hydration snapshot from the debug day-sheet smoke seed.
///
/// Regenerate with:
/// `UPDATE_HYDRATION_BASELINE=1 flutter test test/features/calendar/hydration_baseline_capture_test.dart`
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app:has_seen_onboarding': true,
      'app:onboarding:completed': true,
    });
  });

  testWidgets('debug smoke seed matches checked-in hydration baseline', (
    tester,
  ) async {
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'test-anon-key',
      httpClient: _RejectingClient(),
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: false,
      ),
    );

    final key = GlobalKey<CalendarPageState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarPage(key: key, debugDaySheetSmokeOnLaunch: true),
        ),
      ),
    );
    // initState installs smoke fixtures synchronously before first frame work.
    await tester.pump();

    final state = key.currentState;
    expect(state, isNotNull);
    final encoded = state!.debugCanonicalHydrationBaselineJson(
      userId: 'baseline-user',
    );
    expect(encoded.contains('"flows"'), isTrue);
    expect(encoded.contains('"notes"'), isTrue);
    // Smoke seed installs multiple notes/flows — empty placeholder must be gone.
    expect(encoded.contains('"flows": []'), isFalse);
    expect(RegExp(r'"notes": \{\s*\}').hasMatch(encoded), isFalse);

    final fixture = File(
      'test/features/calendar/fixtures/hydration_baseline.json',
    );
    final update = Platform.environment['UPDATE_HYDRATION_BASELINE'] == '1';
    if (update) {
      fixture.writeAsStringSync('$encoded\n');
    }

    expect(
      fixture.readAsStringSync().trim(),
      encoded.trim(),
      reason: update
          ? 'fixture rewritten; re-run without UPDATE_HYDRATION_BASELINE'
          : 'run with UPDATE_HYDRATION_BASELINE=1 to refresh the fixture',
    );
  });
}

class _RejectingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable(const []),
      500,
      request: request,
    );
  }
}
