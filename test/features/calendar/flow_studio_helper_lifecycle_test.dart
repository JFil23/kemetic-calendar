import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/onboarding/guided_onboarding_overlay.dart';
import 'package:mobile/features/onboarding/onboarding_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _testUserId = '4d2583da-8de4-49d3-9cd1-37a9a74f55bd';

Future<void> _ensureSupabaseInitialized() async {
  try {
    Supabase.instance.client;
    return;
  } catch (_) {}

  await Supabase.initialize(
    url: 'https://example.supabase.co',
    anonKey: 'anon-key-0123456789012345678901234567890123456789',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _ensureSupabaseInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _recoverTestSession();
    GuidedOnboardingController.instance.clear();
  });

  tearDown(() {
    GuidedOnboardingController.instance.clear();
    OnboardingHelperCompletionService.resetForTesting(
      remoteStore: _FakeRemoteStore(),
    );
  });

  testWidgets(
    "opening /flows defers Ma'at Flows helper hydration out of route build",
    (tester) async {
      await _seedCompletedOnboarding();
      final remoteStore = _FakeRemoteStore();
      OnboardingHelperCompletionService.resetForTesting(
        remoteStore: remoteStore,
      );

      await _pumpFlowStudioRoute(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Flow Studio'), findsOneWidget);
      expect(remoteStore.loadCount, 1);

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(remoteStore.loadCount, 1);
      expect(
        GuidedOnboardingController.instance.target?.helperId,
        OnboardingHelperIds.flowStudioMaatFlows,
      );
    },
  );

  testWidgets("completed Ma'at Flows helper stays hidden on /flows", (
    tester,
  ) async {
    await _seedCompletedOnboarding(
      seenHelpers: const {OnboardingHelperIds.flowStudioMaatFlows},
    );
    final remoteStore = _FakeRemoteStore(
      completedByUser: const {
        _testUserId: {OnboardingHelperIds.flowStudioMaatFlows},
      },
    );
    OnboardingHelperCompletionService.resetForTesting(remoteStore: remoteStore);

    await _pumpFlowStudioRoute(tester);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Flow Studio'), findsOneWidget);
    expect(remoteStore.loadCount, 1);
    expect(GuidedOnboardingController.instance.target, isNull);
  });
}

Future<void> _pumpFlowStudioRoute(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: GuidedOnboardingOverlayHost(
        child: CalendarPage.buildFlowStudioRoutePage(
          routeUri: Uri(path: '/flows'),
        ),
      ),
    ),
  );
}

Future<void> _seedCompletedOnboarding({
  Set<String> seenHelpers = const <String>{},
}) async {
  await OnboardingProgressStorage().save(
    _testUserId,
    const OnboardingProgress().copyWith(
      currentStep: TrueOnboardingStep.complete,
      completedOnboarding: true,
      seenHelpers: seenHelpers,
    ),
  );
}

Future<void> _recoverTestSession() async {
  final expiresAt =
      DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch ~/
      1000;
  await Supabase.instance.client.auth.recoverSession(
    jsonEncode(<String, Object?>{
      'access_token': 'test-access-token-$expiresAt',
      'expires_in': 31536000,
      'refresh_token': 'test-refresh-token',
      'token_type': 'bearer',
      'user': <String, Object?>{
        'id': _testUserId,
        'app_metadata': <String, Object?>{
          'provider': 'email',
          'providers': <String>['email'],
        },
        'user_metadata': <String, Object?>{},
        'aud': 'authenticated',
        'email': 'flow-studio-helper-test@example.com',
        'phone': '',
        'created_at': '2026-01-01T00:00:00.000000Z',
        'email_confirmed_at': '2026-01-01T00:00:00.000000Z',
        'role': 'authenticated',
        'updated_at': '2026-01-01T00:00:00.000000Z',
      },
      'expiresAt': expiresAt,
    }),
  );
}

class _FakeRemoteStore implements OnboardingHelperCompletionRemoteStore {
  _FakeRemoteStore({
    Map<String, Set<String>> completedByUser = const <String, Set<String>>{},
  }) : completedByUser = {
         for (final entry in completedByUser.entries)
           entry.key: OnboardingHelperIds.normalizeCompletedHelperKeys(
             entry.value,
           ),
       };

  final Map<String, Set<String>> completedByUser;
  int loadCount = 0;

  @override
  Future<Set<String>> loadCompletedHelperKeys(String userId) async {
    loadCount += 1;
    return completedByUser[userId] ?? const <String>{};
  }

  @override
  Future<void> markCompleted(
    String userId,
    Iterable<String> completionKeys,
  ) async {
    final existing = completedByUser.putIfAbsent(userId, () => <String>{});
    existing.addAll(
      OnboardingHelperIds.normalizeCompletedHelperKeys(completionKeys),
    );
  }
}
