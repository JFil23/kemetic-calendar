import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';
import 'package:mobile/features/calendar/maat_flow_catalog.dart';
import 'package:mobile/features/calendar/maat_flow_identity.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_detail_page.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_detail_page.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
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

  test('active detail coordinator has no 33-flow visual dispatcher', () {
    final source = File(
      'lib/features/calendar/calendar_active_maat_flows.dart',
    ).readAsStringSync();

    expect(source, contains('class _MaatFlowTemplateDetailPageState'));
    expect(source, contains('Widget _buildFollowSky()'));
    expect(source, contains('Widget _buildOfferingTable()'));
    expect(source, contains('Widget _buildReadingHouse()'));
    expect(source, contains('Widget _buildDjed()'));
    expect(source, isNot(contains('Widget _buildTheWeighingScaffold')));
    expect(source, isNot(contains('Widget _buildWagScaffold')));
  });

  test('all identities resolve while only four own active details', () {
    expect(MaatFlowKind.values, hasLength(33));
    expect(
      knownMaatFlowTemplateKeysForTesting(),
      hasLength(
        MaatFlowKind.values.length - kArchivedCompatibilityMaatFlowKinds.length,
      ),
    );
    expect(coreMaatFlowTemplateKeysForTesting().toSet(), <String>{
      'track-the-sky',
      'the-offering-table',
      'the-reading-house',
      'the-djed',
    });
    for (final kind in MaatFlowKind.values) {
      final key = kind.flowKey;
      expect(
        resolveMaatFlowKind(
          behaviorPayload: <String, dynamic>{'flow_key': key},
        ),
        isNotNull,
        reason: key,
      );
      expect(
        isMaatFlowNewJoinAllowed(key),
        coreMaatFlowTemplateKeysForTesting().contains(key),
        reason: key,
      );
    }
    for (final kind in kArchivedCompatibilityMaatFlowKinds) {
      expect(
        knownMaatFlowTemplateKeysForTesting(),
        isNot(contains(kind.flowKey)),
        reason: kind.flowKey,
      );
    }
  });

  testWidgets('Follow the Sky V11 detail replaces Course-era Ma’at shell', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpFlow(tester, 'track-the-sky');

    expect(find.byType(FollowSkyDetailPage), findsOneWidget);
    expect(_eventRows(), findsNothing);
    expect(find.byKey(kMaatFlowInitialPromptSectionKey), findsNothing);
    expect(find.text('Here they are.'), findsOneWidget);
    expect(find.text('HOW A TURNING WORKS'), findsOneWidget);
    expect(find.text('Carry this course'), findsOneWidget);
    expect(find.text('ONE THING TO CARRY'), findsNothing);
    expect(find.text('NEXT TURNING'), findsNothing);
    expect(find.text('Join Flow'), findsNothing);
    expect(
      find.text("Sky · the year's turnings, in Kemetic time"),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('each active detail renders its dedicated surface immediately', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    for (final key in coreMaatFlowTemplateKeysForTesting()) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _pumpFlow(tester, key);

      expect(
        _activeDetailSurface(key),
        findsOneWidget,
        reason: '$key must not fall back to the retired generic event list',
      );
      expect(tester.takeException(), isNull, reason: key);
    }
  });

  testWidgets('the four-flow discovery uses the approved card geometry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: buildMaatFlowsListPreviewForTesting()),
    );
    await tester.pump();

    final follow = find.byKey(
      const ValueKey<String>('maat-flow-discovery-card-track-the-sky'),
    );
    final offering = find.byKey(
      const ValueKey<String>('maat-flow-discovery-card-the-offering-table'),
    );
    expect(follow, findsOneWidget);
    expect(offering, findsOneWidget);
    expect(tester.getSize(follow).width, closeTo(366, 1));
    expect(
      tester.getTopLeft(follow).dy,
      lessThan(tester.getTopLeft(offering).dy),
    );
    expect(find.text('NOT YET JOINED'), findsNothing);
    expect(find.text('JOINED'), findsNothing);
  });

  testWidgets(
    'archived histories stay reachable without restoring active event lists',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home:
              CalendarPage.buildCanonicalMaatFlowDetail(
                name: 'Dawn House Rite',
                notes: 'maat=dawn-house-rite',
                eventsJson: const <dynamic>[
                  <String, dynamic>{
                    'date': '2026-09-01',
                    'title': 'Open the eastern room',
                  },
                ],
              ) ??
              const SizedBox.shrink(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('This flow is archived'), findsOneWidget);
      expect(find.text('Open the eastern room'), findsOneWidget);
      expect(_eventRows(), findsNothing);
      expect(find.textContaining('Join'), findsNothing);
    },
  );

  test('catalog preserves the explicit four-plus-nine boundary', () {
    expect(
      kMaatFlowCatalog.values.where(
        (entry) => entry.status == MaatFlowCatalogStatus.core,
      ),
      hasLength(4),
    );
    expect(
      kMaatFlowCatalog.values.where(
        (entry) => entry.status == MaatFlowCatalogStatus.archived,
      ),
      hasLength(9),
    );
    expect(
      kMaatFlowCatalog.values.where(
        (entry) =>
            entry.status != MaatFlowCatalogStatus.core &&
            entry.status != MaatFlowCatalogStatus.archived,
      ),
      hasLength(20),
    );
  });

  test(
    'blocked identities cannot cross the new-join side-effect boundary',
    () async {
      for (final kind in MaatFlowKind.values.where(
        (kind) => !isMaatFlowNewJoinAllowedKind(kind),
      )) {
        var creates = 0;
        final result = await applyMaatFlowNewJoinPolicy<int>(
          flowKey: kind.flowKey,
          rejectedValue: -1,
          create: () {
            creates += 1;
            return 1;
          },
        );
        expect(result, -1, reason: kind.flowKey);
        expect(creates, 0, reason: kind.flowKey);
      }
    },
  );

  testWidgets(
    'discovery taps report only the selected active product identity',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: buildMaatFlowsListPreviewForTesting(
            onPickTemplate: (key) async {
              selected = key;
              return null;
            },
          ),
        ),
      );
      await tester.pump();

      final followButton = find.byKey(
        const ValueKey<String>('maat-flow-discovery-open-track-the-sky'),
      );
      await tester.ensureVisible(followButton);
      await tester.tap(followButton);
      await tester.pump();

      expect(selected, 'track-the-sky');
      expect(
        find.byKey(
          const ValueKey<String>('maat-flow-discovery-detail-track-the-sky'),
        ),
        findsNothing,
      );
      expect(find.text('Carry this flow'), findsNothing);
      expect(isMaatFlowNewJoinAllowed(selected!), isTrue);
    },
  );

  testWidgets('discovery does not synthesize legacy joined/progress chrome', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: buildMaatFlowsListPreviewForTesting(
          joinedKeys: const <String>{'track-the-sky', 'the-weighing'},
          completionCounts: const <String, (int total, int remaining)>{
            'track-the-sky': (10, 4),
            'the-weighing': (9, 2),
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('JOINED'), findsNothing);
    expect(find.text('NOT YET JOINED'), findsNothing);
    expect(find.text('6 of 10'), findsNothing);
    expect(find.text('The Weighing'), findsNothing);
  });

  testWidgets('leaving and reopening preserves the four-flow catalog', (
    tester,
  ) async {
    Future<void> pumpCatalog() async {
      await tester.pumpWidget(
        MaterialApp(home: buildMaatFlowsListPreviewForTesting()),
      );
      await tester.pump();
    }

    await pumpCatalog();
    final before = coreMaatFlowTemplateKeysForTesting();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await pumpCatalog();

    expect(coreMaatFlowTemplateKeysForTesting(), before);
    expect(
      find.byKey(
        const ValueKey<String>('maat-flow-discovery-card-track-the-sky'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the last active product remains reachable on a short viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: buildMaatFlowsListPreviewForTesting()),
    );
    await tester.pump();

    final djed = find.byKey(
      const ValueKey<String>('maat-flow-discovery-card-the-djed'),
    );
    await tester.scrollUntilVisible(
      djed,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(djed, findsOneWidget);
    expect(find.text('Join Flow'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow discovery cards preserve their complete product copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: buildMaatFlowsListPreviewForTesting()),
    );
    await tester.pump();

    expect(
      find.text(
        'The sky keeps moving. What you’re working toward moves with it.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Declare your intention before the day asks anything of you.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test('unknown snapshots remain outside canonical Ma’at routing', () {
    expect(
      CalendarPage.buildCanonicalMaatFlowDetail(
        name: 'A private custom practice',
        notes: 'mode=custom',
      ),
      isNull,
    );
    expect(
      resolveMaatFlowKind(
        flowName: 'A private custom practice',
        flowNotes: 'mode=custom',
      ),
      isNull,
    );
  });

  testWidgets('opening another active flow selects its own dedicated surface', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    await _pumpFlow(tester, 'the-reading-house');
    expect(find.byType(ReadingHouseDetailPage), findsOneWidget);
    expect(find.byType(DjedDetailPage), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pumpFlow(tester, 'the-djed');
    expect(find.byType(DjedDetailPage), findsOneWidget);
    expect(find.byType(ReadingHouseDetailPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('My Flows lead card and keyed row behavior remain unchanged', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: buildMyFlowDetailPreviewForTesting(saved: true),
      ),
    );
    await tester.pumpAndSettle();

    final leadCard = find.byKey(
      const ValueKey<String>('my_flow_day_card_71:preview-71-0'),
    );
    await _scrollUntilBuilt(tester, leadCard);
    final secondTap = find.byKey(
      const ValueKey<String>('my_flow_day_tap_71:preview-71-1'),
    );
    await _scrollUntilBuilt(tester, secondTap);
    await tester.ensureVisible(secondTap);
    await tester.pumpAndSettle();
    await tester.tap(secondTap);
    await tester.pumpAndSettle();
    expect(find.text('DAY 2'), findsOneWidget);

    await tester.tap(secondTap);
    await tester.pumpAndSettle();
    expect(find.text('DAY 2'), findsNothing);
  });
}

Finder _eventRows() => find.byWidgetPredicate(
  (widget) => _hasValueKeyPrefix(widget, 'maat_flow_event_row_'),
);

Finder _activeDetailSurface(String templateKey) {
  return switch (templateKey) {
    'track-the-sky' => find.byType(FollowSkyDetailPage),
    'the-offering-table' => find.byType(OfferingTableDetailPage),
    'the-reading-house' => find.byType(ReadingHouseDetailPage),
    'the-djed' => find.byType(DjedDetailPage),
    _ => find.byKey(const ValueKey<String>('unsupported-active-detail')),
  };
}

bool _hasValueKeyPrefix(Widget widget, String prefix) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith(prefix);
}

Future<void> _pumpFlow(
  WidgetTester tester,
  String templateKey, {
  bool emptyEvents = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: buildMaatFlowTemplateDetailPreviewForTesting(
        templateKey: templateKey,
        emptyEvents: emptyEvents,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

void _setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _scrollUntilBuilt(WidgetTester tester, Finder target) async {
  for (var attempt = 0; attempt < 12 && target.evaluate().isEmpty; attempt++) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -360));
    await tester.pumpAndSettle();
  }
  expect(target, findsOneWidget);
}
