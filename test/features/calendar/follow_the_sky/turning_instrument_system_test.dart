import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';
import 'package:mobile/features/calendar/maat_flow_response_journal_blocks.dart';
import 'package:mobile/features/journal/journal_v2_document_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SkyCatalog catalog;

  setUpAll(() {
    catalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );
  });

  test('all 65 observing nights resolve to exactly one sealed family', () {
    const resolver = InstrumentFamilyResolver();
    final nights = catalog.materializableEvents
        .map(catalog.observingNight)
        .toList(growable: false);

    expect(nights, hasLength(65));
    final resolved = nights.map(resolver.resolve).toList(growable: false);
    expect(resolved, hasLength(65));
    expect(resolved, everyElement(isA<SkyInstrumentFamily>()));
    expect(resolved.toSet(), <SkyInstrumentFamily>{
      SkyInstrumentFamily.lunarPath,
      SkyInstrumentFamily.meteorWindow,
      SkyInstrumentFamily.opposition,
      SkyInstrumentFamily.elongation,
      SkyInstrumentFamily.conjunction,
      SkyInstrumentFamily.solarThreshold,
      SkyInstrumentFamily.solarEclipse,
    });
  });

  test('merged lunar eclipse resolves once through its Full Moon anchor', () {
    const resolver = InstrumentFamilyResolver();
    final anchor = catalog.byId('full-moon-2026-08-28')!;
    final night = catalog.observingNight(anchor);

    expect(night.companion?.id, 'lunar-eclipse-2026-08-28');
    expect(resolver.resolve(night), SkyInstrumentFamily.lunarPath);
    expect(
      catalog.materializableEvents.where((event) => event.id == anchor.id),
      hasLength(1),
    );
  });

  test(
    'provider accepts arbitrary IANA place and returns typed lunar data',
    () async {
      final night = catalog.observingNight(
        catalog.byId('full-moon-2026-08-28')!,
      );
      final data = await const CatalogSkyInstrumentDataProvider().resolve(
        night: night,
        place: const ObservingPlace(
          latitude: 30.0444,
          longitude: 31.2357,
          ianaTimeZone: 'Africa/Cairo',
          label: 'Cairo',
          source: ObservingPlaceSource.manual,
        ),
      );

      expect(data, isA<LunarPathData>());
      expect(data.visibility.isLocal, isFalse);
      expect(data.visibility.isTimeFallback, isFalse);
      expect(data.visibility.summary, contains('Cairo'));
      expect(data.visibility.summary, contains('sky position unavailable'));
      final lunar = data as LunarPathData;
      expect(lunar.eclipseMarkers, isEmpty);
      expect(lunar.moonSamples, isEmpty);
      expect(lunar.rise, isNull);
    },
  );

  test(
    'invalid IANA zone fails closed instead of claiming local time',
    () async {
      final night = catalog.observingNight(
        catalog.byId('full-moon-2026-08-28')!,
      );
      final data = await const CatalogSkyInstrumentDataProvider().resolve(
        night: night,
        place: const ObservingPlace(
          latitude: 30.0444,
          longitude: 31.2357,
          ianaTimeZone: 'Not/A_Time_Zone',
          label: 'Unknown place',
          source: ObservingPlaceSource.manual,
        ),
      );

      expect(data.visibility.isLocal, isFalse);
      expect(data.visibility.isTimeFallback, isTrue);
      expect(data.visibility.summary, contains('using UTC'));
    },
  );

  test(
    'absolute viewing timeline crosses midnight without day-minute math',
    () {
      final timeline = SkyViewingTimeline(
        start: DateTime(2026, 8, 28, 19),
        end: DateTime(2026, 8, 29, 6),
      );

      expect(timeline.durationMinutes, 11 * 60);
      expect(timeline.timeAtOffset(6 * 60), DateTime(2026, 8, 29, 1));
      expect(timeline.offsetFor(DateTime(2026, 8, 29, 3, 30)), 8 * 60 + 30);
    },
  );

  test('TurningRecord round-trips encounter snapshots and completion', () {
    final record = TurningRecord(
      id: 'record-1',
      clientEventId: 'event-1',
      skyEventId: 'sky-1',
      intentionSnapshot: 'Stay with what changes.',
      reflectionText: 'Clouds opened for a moment.',
      photoObjectPath: 'user/event/photo.jpg',
      completion: TurningCompletion.partly,
      startedAt: DateTime.utc(2026, 8, 28, 3),
      lastEditedAt: DateTime.utc(2026, 8, 28, 4),
      completedAt: DateTime.utc(2026, 8, 28, 4),
      scheduledTimeSnapshot: DateTime.utc(2026, 8, 28, 2),
    );

    final restored = TurningRecord.fromJson(record.toJson());
    expect(restored.id, record.id);
    expect(restored.intentionSnapshot, record.intentionSnapshot);
    expect(restored.reflectionText, record.reflectionText);
    expect(restored.photoObjectPath, record.photoObjectPath);
    expect(restored.completion, TurningCompletion.partly);
    expect(restored.scheduledTimeSnapshot, record.scheduledTimeSnapshot);
  });

  test(
    'saved reflection projects idempotently and Skipped preserves prose',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final preferences = await SharedPreferences.getInstance();
      final client = SupabaseClient('http://localhost', 'anon-key');
      const projector = TurningJournalProjector();
      final record = TurningRecord(
        id: 'record-2',
        clientEventId: 'event-2',
        skyEventId: 'sky-2',
        intentionSnapshot: null,
        reflectionText: "Couldn't get outside. Exhausted after work.",
        photoObjectPath: 'user/event/photo.jpg',
        completion: TurningCompletion.skipped,
        startedAt: DateTime.utc(2026, 8, 28, 3),
        lastEditedAt: DateTime.utc(2026, 8, 28, 4),
        completedAt: DateTime.utc(2026, 8, 28, 4),
        scheduledTimeSnapshot: DateTime.utc(2026, 8, 28, 2),
      );
      final repository = TurningRecordRepository(
        client,
        preferences: preferences,
      );
      final saved = await repository.save(record);
      final restored = await repository.load(record.clientEventId);
      expect(restored, isNotNull);
      expect(restored!.reflectionText, record.reflectionText);
      expect(restored.completion, TurningCompletion.skipped);
      expect(restored.photoObjectPath, record.photoObjectPath);
      final projection = projector.project(
        record: restored,
        localDate: DateTime(2026, 8, 28),
      );

      var document = JournalDocument.fromPlainText('Earlier entry.');
      document = MaatJournalResponseBlockUtils.upsertPlainUserText(
        document,
        projection,
      );
      document = MaatJournalResponseBlockUtils.upsertPlainUserText(
        document,
        projection,
      );

      expect(
        RegExp(
          RegExp.escape(saved.reflectionText),
        ).allMatches(document.toPlainText()),
        hasLength(1),
      );
      final metadata = MaatJournalResponseBlockUtils.extractSourceMetadata(
        document,
        projection.sourceId,
      );
      expect(metadata['completion'], 'skipped');
      expect(metadata['photo_object_path'], restored.photoObjectPath);
      expect(metadata['intention_snapshot'], isNull);
      expect(
        metadata['scheduled_time_snapshot'],
        restored.scheduledTimeSnapshot.toUtc().toIso8601String(),
      );
      client.dispose();
    },
  );

  test('photo metadata survives before any reflection is written', () {
    const sourceId = 'follow-sky-turning:event-3';
    final document = MaatJournalResponseBlockUtils.upsertPlainUserText(
      JournalDocument.fromPlainText(''),
      const MaatJournalResponseBlock(
        sourceId: sourceId,
        text: '',
        sourceMetadata: <String, dynamic>{
          'kind': 'follow_sky_turning',
          'photo_object_path': 'user/event/photo.jpg',
        },
      ),
    );

    expect(
      MaatJournalResponseBlockUtils.extractSourceMetadata(
        document,
        sourceId,
      )['photo_object_path'],
      'user/event/photo.jpg',
    );
  });

  test(
    'failed remote save remains pending and a new session retries it',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final preferences = await SharedPreferences.getInstance();
      final failingHttp = _TurningRecordHttpClient(failWrites: true);
      final failingClient = SupabaseClient(
        'https://example.supabase.test',
        'anon-key',
        httpClient: failingHttp,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      await failingClient.auth.recoverSession(_sessionJson());
      final record = TurningRecord(
        id: 'record-pending',
        clientEventId: 'event-pending',
        skyEventId: 'sky-pending',
        intentionSnapshot: 'Look carefully.',
        reflectionText: 'Seen offline.',
        startedAt: DateTime.utc(2026, 8, 28, 3),
        lastEditedAt: DateTime.utc(2026, 8, 28, 4),
        scheduledTimeSnapshot: DateTime.utc(2026, 8, 28, 2),
      );

      final first = TurningRecordRepository(
        failingClient,
        preferences: preferences,
      );
      final saved = await first.saveWithStatus(record);
      expect(saved.cloudSynced, isFalse);
      expect(await first.isPendingSync(record.clientEventId), isTrue);
      expect(failingHttp.writeCalls, 1);
      failingClient.dispose();

      final succeedingHttp = _TurningRecordHttpClient(failWrites: false);
      final succeedingClient = SupabaseClient(
        'https://example.supabase.test',
        'anon-key',
        httpClient: succeedingHttp,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      await succeedingClient.auth.recoverSession(_sessionJson());
      final nextSession = TurningRecordRepository(
        succeedingClient,
        preferences: preferences,
      );
      final retried = await nextSession.load(record.clientEventId);
      expect(retried?.reflectionText, record.reflectionText);
      expect(retried?.id, 'remote-record');
      expect(succeedingHttp.writeCalls, 1);
      expect(await nextSession.isPendingSync(record.clientEventId), isFalse);
      succeedingClient.dispose();
    },
  );

  test('vertical slice contains no decorative sky-geometry painter', () {
    final source = File(
      'lib/features/calendar/follow_the_sky/presentation/widgets/'
      'follow_sky_observation_panel.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('_SkyInstrumentPainter')));
    expect(source, isNot(contains('_drawArcBody')));
    expect(source, contains('Moonrise, highest point, moonset'));
    expect(source, contains('No visual sky geometry is shown'));
  });

  test('photo retake confirms the new reference before old deletion', () async {
    final calls = <String>[];
    final record = _photoRecord('old.jpg');

    final result = await const FollowSkyPhotoReplacementCoordinator().replace(
      previousObjectPath: record.photoObjectPath,
      uploadNew: () async {
        calls.add('upload:new.jpg');
        return 'new.jpg';
      },
      persistNewReference: (objectPath) async {
        calls.add('persist:$objectPath');
        return TurningRecordSaveResult(
          record: record.copyWith(photoObjectPath: objectPath),
          cloudSynced: true,
        );
      },
      deleteObject: (objectPath) async => calls.add('delete:$objectPath'),
    );

    expect(result.record.photoObjectPath, 'new.jpg');
    expect(calls, <String>[
      'upload:new.jpg',
      'persist:new.jpg',
      'delete:old.jpg',
    ]);
  });

  test(
    'failed remote photo reference update preserves the old object',
    () async {
      final calls = <String>[];
      final record = _photoRecord('old.jpg');

      final result = await const FollowSkyPhotoReplacementCoordinator().replace(
        previousObjectPath: record.photoObjectPath,
        uploadNew: () async {
          calls.add('upload:new.jpg');
          return 'new.jpg';
        },
        persistNewReference: (objectPath) async {
          calls.add('persist:$objectPath');
          return TurningRecordSaveResult(
            record: record.copyWith(photoObjectPath: objectPath),
            cloudSynced: false,
          );
        },
        deleteObject: (objectPath) async => calls.add('delete:$objectPath'),
      );

      expect(result.cloudSynced, isFalse);
      expect(calls, <String>['upload:new.jpg', 'persist:new.jpg']);
    },
  );

  test('Follow Sky uses a narrow result adapter over the void move API', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();

    expect(source, contains('Future<void> _moveEventInDayView('));
    expect(source, contains('Future<bool> _moveFollowSkyEventInDayView('));
    expect(source, contains('DateTime? targetLocalDate'));
    expect(source, isNot(contains('Future<bool> _moveEventInDayView(')));
  });
}

const _userId = '27d63169-a28a-4550-a0a0-8fee0e8e7b95';

TurningRecord _photoRecord(String photoObjectPath) => TurningRecord(
  id: 'photo-record',
  clientEventId: 'photo-event',
  skyEventId: 'full-moon-2026-08-28',
  intentionSnapshot: null,
  reflectionText: 'Moon behind cloud.',
  photoObjectPath: photoObjectPath,
  startedAt: DateTime.utc(2026, 8, 28, 3),
  lastEditedAt: DateTime.utc(2026, 8, 28, 4),
  scheduledTimeSnapshot: DateTime.utc(2026, 8, 28, 2),
);

class _TurningRecordHttpClient extends http.BaseClient {
  _TurningRecordHttpClient({required this.failWrites});

  final bool failWrites;
  int writeCalls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path != '/rest/v1/follow_sky_turning_records' ||
        request.method != 'POST') {
      return _jsonResponse(request, <String, Object?>{}, statusCode: 404);
    }
    writeCalls += 1;
    final requestBody = await request.finalize().transform(utf8.decoder).join();
    if (failWrites) {
      return _jsonResponse(request, <String, Object?>{
        'message': 'offline',
      }, statusCode: 503);
    }
    final payload = Map<String, dynamic>.from(jsonDecode(requestBody) as Map);
    return _jsonResponse(request, <String, Object?>{
      ...payload,
      'id': 'remote-record',
      'user_id': _userId,
    });
  }

  http.StreamedResponse _jsonResponse(
    http.BaseRequest request,
    Object? body, {
    int statusCode = 200,
  }) => http.StreamedResponse(
    Stream<List<int>>.value(utf8.encode(jsonEncode(body))),
    statusCode,
    request: request,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

String _sessionJson() {
  final expiresAt =
      DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch ~/
      1000;
  return jsonEncode(<String, Object?>{
    'access_token': 'test-access-token-$expiresAt',
    'expires_in': 31536000,
    'refresh_token': 'test-refresh-token',
    'token_type': 'bearer',
    'user': <String, Object?>{
      'id': _userId,
      'app_metadata': <String, Object?>{
        'provider': 'email',
        'providers': <String>['email'],
      },
      'user_metadata': <String, Object?>{},
      'aud': 'authenticated',
      'email': 'turning-test@example.com',
      'phone': '',
      'created_at': '2026-01-01T00:00:00.000000Z',
      'email_confirmed_at': '2026-01-01T00:00:00.000000Z',
      'role': 'authenticated',
      'updated_at': '2026-01-01T00:00:00.000000Z',
    },
    'expiresAt': expiresAt,
  });
}
