import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:mobile/features/calendar/calendar_epoch_viewport.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/calendar_scroll_coordinator.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/widgets/month_name_text.dart';
import 'package:mobile/widgets/pronounce_icon_button.dart';
import 'package:mobile/services/speech/speech_catalog.g.dart';
import 'package:mobile/services/speech/speech_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/controlled_speech_playback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDirectory;
  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'calendar_speech_scroll.',
    );
    Hive.init(hiveDirectory.path);
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

  tearDownAll(() async {
    await Supabase.instance.dispose();
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app:has_seen_onboarding': true,
      'app:onboarding:completed': true,
    });
  });

  testWidgets(
    'calendar scrolls across months while the original pronunciation finishes',
    (tester) async {
      await Supabase.instance.client.auth.recoverSession(_sessionJson());
      tester.view.physicalSize = const Size(390, 844);
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

      final audio = ControlledSpeechPlayback()..install();
      final speech = SpeechService.instance;
      await audio.tapAndStart(
        tester,
        find.byKey(const Key('scrolling-calendar-month-speech')),
      );
      final originalUtterance = speech.activeUtteranceId.value;
      final originalMonth = pageKey
          .currentState!
          .debugCalendarScrollCoordinator
          .activeBannerMonth
          .value;
      final scrollView = find.byType(CalendarEpochScrollView).first;
      for (var index = 0; index < 12; index++) {
        await tester.drag(scrollView, Offset(0, index < 9 ? -420 : 420));
        await tester.pump(const Duration(milliseconds: 300));
        expect(speech.activeUtteranceId.value, originalUtterance);
        expect(speech.isSpeaking.value, isTrue);
        expect(audio.interrupted, isEmpty);
        expect(audio.resumed, hasLength(1));
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
      final speechButton = tester.widget<PronounceIconButton>(
        find.byKey(const Key('scrolling-calendar-month-speech')),
      );
      expect(
        speechClipIds[speechButton.speakText],
        'month-${activeBannerMonth.month.toString().padLeft(2, '0')}',
      );

      expect(activeBannerMonth, isNot(originalMonth));
      await audio.finish(tester);
      await tester.pump();
      expect(speech.isSpeaking.value, isFalse);
      expect(speech.activeUtteranceId.value, isNull);
      expect(audio.resumed, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    },
  );
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
