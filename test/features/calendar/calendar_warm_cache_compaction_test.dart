import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = '27d63169-a28a-4550-a0a0-8fee0e8e7b95';
const _cacheKey = 'calendar:warm_start:v1:$_userId';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
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

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app:has_seen_onboarding': true,
      'app:onboarding:completed': true,
    });
    await Supabase.instance.client.auth.recoverSession(_sessionJson());
  });

  Future<CalendarPageState> pumpCalendar(WidgetTester tester) async {
    final key = GlobalKey<CalendarPageState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CalendarPage(key: key)),
      ),
    );
    await tester.pump();
    expect(key.currentState, isNotNull);
    return key.currentState!;
  }

  testWidgets(
    'oversized authoritative snapshot compacts and selected day survives restart',
    (tester) async {
      final state = await pumpCalendar(tester);
      final center = DateUtils.dateOnly(DateTime.now());
      final largeDetail = List<String>.filled(6000, 'x').join();

      for (var offset = -100; offset <= 100; offset++) {
        final day = center.add(Duration(days: offset));
        final kemetic = KemeticMath.fromGregorian(day);
        expect(
          state.debugAddNote(
            kemetic.kYear,
            kemetic.kMonth,
            kemetic.kDay,
            offset == 0 ? 'selected survives compact' : 'cache load $offset',
            largeDetail,
            clientEventId: 'warm-cache-$offset',
            notify: false,
          ),
          isTrue,
        );
      }

      await state.debugPersistWarmStartCacheForTesting(_userId);
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(_cacheKey);
      expect(encoded, isNotNull);
      expect(encoded!.length, lessThanOrEqualTo(850000));

      final cached = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
      expect(cached['snapshotSchemaVersion'], 2);
      expect(cached['compactionLevel'], isNot('full'));
      final selected = KemeticMath.fromGregorian(center);
      final selectedKey =
          '${selected.kYear}-${selected.kMonth}-${selected.kDay}';
      final selectedRows = (cached['notes'] as Map)[selectedKey] as List;
      expect(
        selectedRows.whereType<Map>().map((row) => row['clientEventId']),
        contains('warm-cache-0'),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));

      final restored = await pumpCalendar(tester);
      for (var attempt = 0; attempt < 50; attempt++) {
        await tester.pump(const Duration(milliseconds: 20));
        if (restored
            .notesForDayForTesting(
              selected.kYear,
              selected.kMonth,
              selected.kDay,
            )
            .any((note) => note.clientEventId == 'warm-cache-0')) {
          break;
        }
      }
      expect(
        restored
            .notesForDayForTesting(
              selected.kYear,
              selected.kMonth,
              selected.kDay,
            )
            .map((note) => note.clientEventId),
        contains('warm-cache-0'),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets(
    'server-current viewport checkpoint preserves compacted outer buckets',
    (tester) async {
      final state = await pumpCalendar(tester);
      final center = DateUtils.dateOnly(DateTime.now());
      final largeDetail = List<String>.filled(6000, 'x').join();

      for (var offset = -100; offset <= 100; offset++) {
        final day = center.add(Duration(days: offset));
        final kemetic = KemeticMath.fromGregorian(day);
        expect(
          state.debugAddNote(
            kemetic.kYear,
            kemetic.kMonth,
            kemetic.kDay,
            'checkpoint seed $offset',
            largeDetail,
            clientEventId: 'checkpoint-seed-$offset',
            notify: false,
          ),
          isTrue,
        );
      }

      await state.debugPersistWarmStartCacheForTesting(_userId);
      final prefs = await SharedPreferences.getInstance();
      final beforeEncoded = prefs.getString(_cacheKey);
      expect(beforeEncoded, isNotNull);
      final before = Map<String, dynamic>.from(
        jsonDecode(beforeEncoded!) as Map,
      );
      final beforeNotes = Map<String, dynamic>.from(before['notes'] as Map);
      final centerKemetic = KemeticMath.fromGregorian(center);
      final centerKey =
          '${centerKemetic.kYear}-${centerKemetic.kMonth}-${centerKemetic.kDay}';
      final outsideEntry = beforeNotes.entries.firstWhere(
        (entry) => entry.key != centerKey,
      );
      final outsideBefore = jsonEncode(outsideEntry.value);

      expect(
        state.debugAddNote(
          centerKemetic.kYear,
          centerKemetic.kMonth,
          centerKemetic.kDay,
          'fresh viewport note',
          'fresh',
          clientEventId: 'checkpoint-fresh-visible',
          notify: false,
        ),
        isTrue,
      );
      await state.debugPersistServerCurrentViewportCacheForTesting(_userId);

      final afterEncoded = prefs.getString(_cacheKey);
      expect(afterEncoded, isNotNull);
      expect(afterEncoded!.length, lessThanOrEqualTo(850000));
      final after = Map<String, dynamic>.from(jsonDecode(afterEncoded) as Map);
      final afterNotes = Map<String, dynamic>.from(after['notes'] as Map);
      expect(after['compactionLevel'], startsWith('viewport_checkpoint:'));
      expect(jsonEncode(afterNotes[outsideEntry.key]), outsideBefore);
      expect(
        (afterNotes[centerKey] as List).whereType<Map>().map(
          (row) => row['clientEventId'],
        ),
        contains('checkpoint-fresh-visible'),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    },
  );
}

String _sessionJson() {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final header = base64Url.encode(utf8.encode('{"alg":"none","typ":"JWT"}'));
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, Object?>{
        'sub': _userId,
        'email': 'warm-cache@example.com',
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
      'id': _userId,
      'email': 'warm-cache@example.com',
      'aud': 'authenticated',
      'role': 'authenticated',
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
      'created_at': '2026-01-01T00:00:00.000Z',
    },
  });
}

class _RejectingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.value(
        utf8.encode(jsonEncode(<String, Object?>{'message': 'offline'})),
      ),
      503,
      request: request,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }
}
