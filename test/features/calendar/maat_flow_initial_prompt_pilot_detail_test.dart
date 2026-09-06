import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';
import 'package:mobile/features/calendar/maat_flow_catalog.dart';
import 'package:mobile/features/calendar/maat_flow_identity.dart';
import 'package:mobile/features/calendar/presentation/archived_maat_flow_detail_view.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_detail_page.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_detail_page.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SkyCatalog followSkyCatalog;

  setUpAll(() async {
    followSkyCatalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );
    SharedPreferences.setMockInitialValues(<String, Object>{});
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        anonKey: 'anon-key-0123456789012345678901234567890123456789',
      );
    }
  });

  tearDown(resetMaatFlowJoinedStateForTesting);

  testWidgets('active product details do not use the retired generic prompt', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    for (final key in coreMaatFlowTemplateKeysForTesting()) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _pumpTemplateDetail(tester, key);

      expect(
        find.byKey(kMaatFlowInitialPromptSectionKey),
        findsNothing,
        reason: key,
      );
      expect(find.text('Begin reflection'), findsNothing, reason: key);
      expect(tester.takeException(), isNull, reason: key);
    }
  });

  testWidgets('Follow the Sky V2 detail skips generic initial-prompt layout', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: FollowSkyDetailPage(
          initialCatalog: followSkyCatalog,
          now: DateTime.utc(2026, 9, 1, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FollowSkyDetailPage), findsOneWidget);
    expect(find.byKey(kMaatFlowInitialPromptSectionKey), findsNothing);
    expect(find.text('Begin reflection'), findsNothing);
    expect(find.text('What change are you watching above?'), findsNothing);
    expect(find.text('HOW A TURNING WORKS'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('follow-sky-all-turnings-toggle')),
      findsOneWidget,
    );
    expect(find.text('Carry this course'), findsOneWidget);
  });

  test('absorbed identities are recognized without an active detail', () {
    expect(
      resolveMaatFlowKind(
        behaviorPayload: const <String, dynamic>{'flow_key': 'the-decan-watch'},
      ),
      MaatFlowKind.decanWatch,
    );
    expect(isMaatFlowDiscoverable('the-decan-watch'), isFalse);
    expect(isMaatFlowNewJoinAllowed('the-decan-watch'), isFalse);
    expect(
      CalendarPage.buildCanonicalMaatFlowDetail(
        name: 'The Decan Watch',
        notes: 'maat=the-decan-watch',
      ),
      isNull,
    );
  });

  testWidgets('Dawn House now opens as archived history', (tester) async {
    await _pumpArchivedDetail(
      tester,
      name: 'Dawn House Rite',
      flowKey: 'dawn-house-rite',
    );

    expect(find.byType(ArchivedMaatFlowDetailView), findsOneWidget);
    expect(find.text('This flow is archived'), findsOneWidget);
    expect(find.byKey(kMaatFlowInitialPromptSectionKey), findsNothing);
  });

  testWidgets('Dawn House archive exposes no active configuration controls', (
    tester,
  ) async {
    await _pumpArchivedDetail(
      tester,
      name: 'Dawn House Rite',
      flowKey: 'dawn-house-rite',
    );

    expect(find.textContaining('Join'), findsNothing);
    expect(find.text('Discreet mode'), findsNothing);
    expect(find.byTooltip('About Discreet mode'), findsNothing);
  });

  test('Dawn House remains recognized as archived compatibility', () {
    final entry = maatFlowCatalogEntry(MaatFlowKind.dawnHouseRite);
    expect(entry.status, MaatFlowCatalogStatus.archived);
    expect(entry.isCompatibilitySupported, isTrue);
    expect(entry.isDiscoverable, isFalse);
    expect(entry.isJoinable, isFalse);
  });

  test('Dawn House cannot cross the new-join authority boundary', () async {
    var creates = 0;
    final result = await applyMaatFlowNewJoinPolicy<int>(
      flowKey: 'dawn-house-rite',
      rejectedValue: -1,
      create: () {
        creates += 1;
        return 1;
      },
    );

    expect(result, -1);
    expect(creates, 0);
  });

  testWidgets('Dawn House preserved events still render read-only', (
    tester,
  ) async {
    await _pumpArchivedDetail(
      tester,
      name: 'Dawn House Rite',
      flowKey: 'dawn-house-rite',
      eventsJson: const <dynamic>[
        <String, dynamic>{
          'date': '2026-09-01',
          'title': 'Open the eastern room',
          'completion_status': 'Observed',
        },
      ],
    );

    expect(find.text('Open the eastern room'), findsOneWidget);
    expect(find.text('Observed'), findsOneWidget);
    expect(find.textContaining('Join'), findsNothing);
  });

  testWidgets('The Closing now opens as archived history', (tester) async {
    await _pumpArchivedDetail(
      tester,
      name: 'The Closing',
      flowKey: 'evening-threshold-rite',
    );

    expect(find.byType(ArchivedMaatFlowDetailView), findsOneWidget);
    expect(find.text('This flow is archived'), findsOneWidget);
    expect(find.byKey(kMaatFlowInitialPromptSectionKey), findsNothing);
  });

  testWidgets('The Closing archive exposes no active configuration controls', (
    tester,
  ) async {
    await _pumpArchivedDetail(
      tester,
      name: 'The Closing',
      flowKey: 'evening-threshold-rite',
    );

    expect(find.textContaining('Join'), findsNothing);
    expect(find.text('Discreet mode'), findsNothing);
    expect(find.byTooltip('About Discreet mode'), findsNothing);
  });

  test('archived detail authority owns no active configuration affordance', () {
    final source = File(
      'lib/features/calendar/presentation/archived_maat_flow_detail_view.dart',
    ).readAsStringSync();

    expect(source, contains('Generic, read-only compatibility presentation'));
    expect(source, isNot(contains("title: 'Discreet mode'")));
    expect(source, isNot(contains('About Discreet mode')));
    expect(source, isNot(contains('kMaatFlowInitialPromptSectionKey')));
  });

  test('The Closing remains recognized as archived compatibility', () {
    final entry = maatFlowCatalogEntry(MaatFlowKind.eveningThresholdRite);
    expect(entry.status, MaatFlowCatalogStatus.archived);
    expect(entry.isCompatibilitySupported, isTrue);
    expect(entry.isDiscoverable, isFalse);
    expect(entry.isJoinable, isFalse);
  });

  test('The Closing cannot cross the new-join authority boundary', () async {
    var creates = 0;
    final result = await applyMaatFlowNewJoinPolicy<int>(
      flowKey: 'evening-threshold-rite',
      rejectedValue: -1,
      create: () {
        creates += 1;
        return 1;
      },
    );

    expect(result, -1);
    expect(creates, 0);
  });

  testWidgets('The Closing preserved responses still render read-only', (
    tester,
  ) async {
    await _pumpArchivedDetail(
      tester,
      name: 'The Closing',
      flowKey: 'evening-threshold-rite',
      eventsJson: const <dynamic>[
        <String, dynamic>{
          'date': '2026-09-01',
          'title': 'Settle the house',
          'behavior_payload': <String, dynamic>{
            'responses': <String, dynamic>{
              'What was released?': 'The unfinished argument.',
            },
          },
        },
      ],
    );

    expect(find.text('The unfinished argument.'), findsOneWidget);
    expect(find.textContaining('Join'), findsNothing);
  });

  testWidgets('the four product details use dedicated visual authorities', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    for (final key in coreMaatFlowTemplateKeysForTesting()) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _pumpTemplateDetail(tester, key);

      expect(_activeDetailSurface(key), findsOneWidget, reason: key);
      expect(
        find.byKey(kMaatFlowInitialPromptSectionKey),
        findsNothing,
        reason: key,
      );
      expect(tester.takeException(), isNull, reason: key);
    }
  });

  test('absorbed decan identities remain historical recognition only', () {
    const absorbedKeys = <String>{
      'the-fair-hearing',
      'the-house-of-life',
      'the-boundary-stone',
      'hotep',
      'the-open-mouth',
      'het-heru',
      'the-shore',
      'the-living-pattern',
      'the-true-name',
      'the-living-text',
      'the-khat',
      'the-decan-watch',
      'the-open-hand',
      'the-moon-return',
    };

    final catalogKeys = kMaatFlowCatalog.values
        .where((entry) => entry.status == MaatFlowCatalogStatus.absorbed)
        .map((entry) => entry.kind.flowKey)
        .toSet();
    expect(catalogKeys, absorbedKeys);
    expect(absorbedKeys.every((key) => !isMaatFlowNewJoinAllowed(key)), isTrue);
  });

  test('active details are absent from the archived compatibility set', () {
    expect(
      coreMaatFlowTemplateKeysForTesting().where(
        (key) => kArchivedCompatibilityMaatFlowKinds.any(
          (kind) => kind.flowKey == key,
        ),
      ),
      isEmpty,
    );
    expect(
      coreMaatFlowTemplateKeysForTesting().every(isMaatFlowNewJoinAllowed),
      isTrue,
    );
  });

  test('archived compatibility is exactly nine isolated identities', () {
    expect(kArchivedCompatibilityMaatFlowKinds, hasLength(9));
    expect(
      kArchivedCompatibilityMaatFlowKinds.every(
        (kind) =>
            isMaatFlowCompatibilitySupportedKind(kind) &&
            !isMaatFlowDiscoverableKind(kind) &&
            !isMaatFlowNewJoinAllowedKind(kind),
      ),
      isTrue,
    );
  });

  test('legacy Evening Threshold remains distinct from archived Closing', () {
    expect(
      resolveMaatFlowKind(
        behaviorPayload: const <String, dynamic>{
          'flow_key': 'evening_threshold',
        },
      ),
      MaatFlowKind.eveningThreshold,
    );
    expect(
      maatFlowCatalogEntry(MaatFlowKind.eveningThreshold).status,
      MaatFlowCatalogStatus.legacy,
    );
    expect(
      maatFlowCatalogEntry(MaatFlowKind.eveningThresholdRite).status,
      MaatFlowCatalogStatus.archived,
    );
    expect(isMaatFlowCompatibilitySupported('evening_threshold'), isFalse);
  });

  testWidgets(
    'dedicated active detail survives rebuild and supported viewport change',
    (tester) async {
      _setPhoneViewport(tester);
      await _pumpTemplateDetail(tester, 'the-offering-table');
      expect(find.byType(OfferingTableDetailPage), findsOneWidget);
      expect(find.byKey(kMaatFlowInitialPromptSectionKey), findsNothing);

      tester.view.physicalSize = const Size(430, 932);

      await _pumpTemplateDetail(tester, 'the-offering-table');
      expect(find.byType(OfferingTableDetailPage), findsOneWidget);
      expect(find.byKey(kMaatFlowInitialPromptSectionKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'legacy local state hydrates only through read-only compatibility',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'kept_word_73_prompt_repair': 'Speak plainly.',
        'kept_word_74_prompt_repair': 'Another flow.',
      });
      final prefs = await SharedPreferences.getInstance();

      final responses = await ArchivedMaatFlowLocalStateReader.load(
        flowKey: 'the-kept-word',
        flowId: 73,
        preferences: prefs,
      );

      expect(responses, hasLength(1));
      expect(responses.single.prompt, 'Repair');
      expect(responses.single.response, 'Speak plainly.');
      expect(prefs.getString('kept_word_73_prompt_repair'), 'Speak plainly.');
    },
  );

  testWidgets('joined state does not change the four-flow discovery catalog', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: buildMaatFlowsListPreviewForTesting(
          joinedKeys: const <String>{
            'track-the-sky',
            'the-weighing',
            'the-course',
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Flows'), findsOneWidget);
    expect(find.text('Follow the Sky'), findsOneWidget);
    expect(find.text('The Weighing'), findsNothing);
    expect(find.text('The Course'), findsNothing);
    expect(find.byKey(kMaatFlowInitialPromptSectionKey), findsNothing);
  });

  test(
    'compatibility decoder is read-only and isolated from journal writes',
    () {
      final compatibility = File(
        'lib/features/calendar/presentation/archived_maat_flow_detail_view.dart',
      ).readAsStringSync();
      final reader = _sourceBetween(
        compatibility,
        start: 'abstract final class ArchivedMaatFlowLocalStateReader',
        end: 'class _ArchivedHero',
      );

      expect(reader, contains('SharedPreferences.getInstance()'));
      expect(reader, contains('prefs.get(key)'));
      expect(reader, isNot(contains('setString(')));
      expect(reader, isNot(contains('setBool(')));
      expect(reader, isNot(contains('onWriteJournalResponse')));
    },
  );
}

void _setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _activeDetailSurface(String templateKey) {
  return switch (templateKey) {
    'track-the-sky' => find.byType(FollowSkyDetailPage),
    'the-offering-table' => find.byType(OfferingTableDetailPage),
    'the-reading-house' => find.byType(ReadingHouseDetailPage),
    'the-djed' => find.byType(DjedDetailPage),
    _ => find.byKey(const ValueKey<String>('unsupported-active-detail')),
  };
}

Future<void> _pumpArchivedDetail(
  WidgetTester tester, {
  required String name,
  required String flowKey,
  List<dynamic> eventsJson = const <dynamic>[],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home:
          CalendarPage.buildCanonicalMaatFlowDetail(
            name: name,
            notes: 'maat=$flowKey',
            eventsJson: eventsJson,
          ) ??
          const SizedBox.shrink(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpTemplateDetail(
  WidgetTester tester,
  String templateKey,
) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: buildMaatFlowTemplateDetailPreviewForTesting(
        templateKey: templateKey,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

String _sourceBetween(
  String source, {
  required String start,
  required String end,
}) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNonNegative, reason: start);
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNonNegative, reason: end);
  return source.substring(startIndex, endIndex);
}
