import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/the_kar/the_kar.dart';
import 'package:mobile/widgets/keyboard_aware.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/maat_flow_visual_test_fonts.dart';

const _captureKarVisuals = bool.fromEnvironment('CAPTURE_KAR_VISUALS');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    const appLinksMessages = MethodChannel('com.llfbandit.app_links/messages');
    const appLinksEvents = MethodChannel('com.llfbandit.app_links/events');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(appLinksMessages, (_) async => null);
    messenger.setMockMethodCallHandler(appLinksEvents, (_) async {
      scheduleMicrotask(
        () =>
            messenger.handlePlatformMessage(appLinksEvents.name, null, (_) {}),
      );
      return null;
    });
    await loadMaatFlowVisualTestFonts();
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

  test('the six authored netjer images are exact mockup extractions', () {
    const expectedHashes = <String, String>{
      'djehuty.png':
          'e7ef97ad04a16d3efbe470d843107a8a645f77d1ee855259efd276d095bfc546',
      'maat.png':
          'cb210a2540706fbc3a6883e97f93755863ef3216aafa8d58fbe896ee717a4420',
      'sekhmet.png':
          '26d9eafed2e7a8285d8b1840df4e02d56f30a7b2be17d508660d522160795891',
      'hetheru.png':
          '8d9696b60845ba66c349a6547c9c4374438b2337715d7543cdbbb219182e7907',
      'khepri.png':
          '61e86934ce5f6aeae5e1c4e70398287a221964ac1fbc7789b90a6a2f9c835658',
      'ptah.png':
          '461b59ead49cd28babebf3f8ecef5ea8c884e76be16c6a9064bb847803cb46db',
    };
    expect(KarNetjer.values.map((value) => value.name), <String>[
      'Djehuty',
      'Maat',
      'Sekhmet',
      'Het-Heru',
      'Khepri',
      'Ptah',
    ]);
    for (final entry in expectedHashes.entries) {
      final bytes = File('assets/the_kar/${entry.key}').readAsBytesSync();
      expect(sha256.convert(bytes).toString(), entry.value, reason: entry.key);
    }
  });

  testWidgets('Discovery taps Kꜣr into the existing shared detail host', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(home: buildMaatFlowsListPreviewForTesting()),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(
      const ValueKey<String>('maat-flow-discovery-card-the-kar'),
    );
    await tester.scrollUntilVisible(
      card,
      460,
      scrollable: find.byType(Scrollable).first,
    );
    final visiblePoint = tester.getTopLeft(card) + const Offset(20, 20);
    expect(visiblePoint.dy, inInclusiveRange(0, 843));
    await tester.tapAt(visiblePoint);
    await tester.pumpAndSettle();

    expect(find.byType(KarDetailSurface), findsOneWidget);
    expect(find.byKey(kMaatFlowDetailSurfaceHostKey), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('kar-shared-sheet')),
      findsOneWidget,
    );
    expect(find.byType(ModalBottomSheetRoute), findsNothing);
    expect(find.byKey(const ValueKey<String>('kar-back')), findsOneWidget);
  });

  test('Kꜣr owns no competing page or modal presentation', () {
    final source = Directory('lib/features/calendar/the_kar')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(source, isNot(contains('class KarDetailPage')));
    expect(source, isNot(contains('showModalBottomSheet')));
    expect(source, isNot(contains('Navigator.push')));
    expect(source, contains('MaatFlowDetailShell('));
  });

  testWidgets('Save keeps a draft and Place commits it from the detail sheet', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    final repository = MemoryKarRepository(
      initial: <KarNetjer, KarShrine>{KarNetjer.djehuty: _activeShrine()},
    );
    await _pumpDetail(tester, repository);

    final arrival = find.byKey(const ValueKey<String>('kar-arrival-card'));
    await _reveal(tester, arrival);
    await tester.tap(arrival);
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey<String>('kar-describe-field'));
    await _reveal(tester, field);
    await tester.enterText(field, 'A dark robe covered in handwritten notes.');
    final save = find.byKey(const ValueKey<String>('kar-save-draft'));
    await _reveal(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    var stored = await repository.loadOrCreate(KarNetjer.djehuty);
    expect(stored.activeCycle!.placements.first.activeVersion, isNull);
    expect(stored.drafts, hasLength(1));

    final place = find.byKey(const ValueKey<String>('kar-place-draft'));
    await _reveal(tester, place);
    await tester.tap(place);
    await tester.pumpAndSettle();

    stored = await repository.loadOrCreate(KarNetjer.djehuty);
    expect(stored.drafts, isEmpty);
    expect(
      stored.activeCycle!.placements.first.activeVersion!.content,
      'A dark robe covered in handwritten notes.',
    );
    expect(find.byType(KeyboardAwareEditableSurface), findsOneWidget);
  });

  testWidgets('capture offers authored Describe and Draw modes', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    final repository = MemoryKarRepository(
      initial: <KarNetjer, KarShrine>{KarNetjer.djehuty: _activeShrine()},
    );
    await _pumpDetail(tester, repository);
    final arrival = find.byKey(const ValueKey<String>('kar-arrival-card'));
    await _reveal(tester, arrival);
    await tester.tap(arrival);
    await tester.pumpAndSettle();

    final draw = find.text('Draw');
    await _reveal(tester, draw);
    expect(find.text('Describe'), findsOneWidget);
    await tester.tap(draw);
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('kar-drawing-pad')),
      findsOneWidget,
    );
    expect(find.text('Bad drawings welcome.'), findsOneWidget);
  });

  testWidgets('recall hides the cue and artifact until the reader asks', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    final repository = MemoryKarRepository(
      initial: <KarNetjer, KarShrine>{
        KarNetjer.djehuty: _place(
          _activeShrine(),
          stageIndex: 0,
          content: 'A blue robe, circular room, and silver pipe.',
        ),
      },
    );
    await _pumpDay(tester, repository: repository, flowId: 91, stageIndex: 0);

    expect(find.text('It’s here'), findsOneWidget);
    expect(find.text('I have a piece'), findsOneWidget);
    expect(find.text('Not yet'), findsOneWidget);
    expect(find.text(KarNetjer.djehuty.partials.first), findsNothing);
    expect(
      find.text('A blue robe, circular room, and silver pipe.'),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey<String>('kar-return-piece')));
    await tester.pump();
    expect(find.text(KarNetjer.djehuty.partials.first), findsOneWidget);
    expect(
      find.text('A blue robe, circular room, and silver pipe.'),
      findsNothing,
    );

    await tester.tap(find.text('Show me'));
    await tester.pump();
    expect(
      find.text('A blue robe, circular room, and silver pipe.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Day 30 walk stays in the same sheet and ignores older-cycle scenes',
    (tester) async {
      _setPhoneViewport(tester);
      var old = _place(
        _activeShrine(),
        stageIndex: 0,
        content: 'An earlier threshold that must stay behind.',
      );
      old = old.completeWalk(
        now: DateTime.utc(2026, 10, 9),
        outcomes: const <String>['recalled', 'open', 'open', 'open', 'open'],
      );
      final current = old.beginCycle(
        cycleId: 'cycle-2',
        anchorDate: DateTime(2026, 11, 1),
        flowId: 92,
      );
      final repository = MemoryKarRepository(
        initial: <KarNetjer, KarShrine>{KarNetjer.djehuty: current},
      );
      await _pumpDay(tester, repository: repository, flowId: 92, stageIndex: 5);

      expect(
        find.byKey(const ValueKey<String>('kar-begin-walk')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey<String>('kar-begin-walk')));
      await tester.pump();

      expect(find.byType(KarDayBehaviorSurface), findsOneWidget);
      expect(find.byType(ModalBottomSheetRoute), findsNothing);
      expect(find.text('This place is open.'), findsOneWidget);
      expect(
        find.text('An earlier threshold that must stay behind.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'completed history can be selected and replaced without erasing its first version',
    (tester) async {
      _setPhoneViewport(tester);
      var completed = _place(
        _activeShrine(),
        stageIndex: 0,
        content: 'First completed threshold.',
      );
      completed = completed.completeWalk(
        now: DateTime.utc(2026, 10, 9),
        outcomes: const <String>['recalled', 'open', 'open', 'open', 'open'],
      );
      final repository = MemoryKarRepository(
        initial: <KarNetjer, KarShrine>{KarNetjer.djehuty: completed},
      );
      await _pumpDetail(tester, repository);

      final history = find.byKey(
        const ValueKey<String>('kar-history-cycle-cycle-1'),
      );
      await _reveal(tester, history);
      await tester.tap(history);
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey<String>('kar-describe-field'));
      await _reveal(tester, field);
      await tester.enterText(field, 'Replacement after completion.');
      await _reveal(
        tester,
        find.byKey(const ValueKey<String>('kar-save-draft')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('kar-save-draft')));
      await tester.pumpAndSettle();
      await _reveal(
        tester,
        find.byKey(const ValueKey<String>('kar-place-draft')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('kar-place-draft')));
      await tester.pumpAndSettle();

      final stored = await repository.loadOrCreate(KarNetjer.djehuty);
      final versions = stored.cycles.single.placements.first.versions;
      expect(versions, hasLength(2));
      expect(versions.first.content, 'First completed threshold.');
      expect(versions.last.content, 'Replacement after completion.');
      expect(versions.last.supersedesId, versions.first.id);
    },
  );

  testWidgets('Kꜣr detail visual evidence at the reference viewport', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    var completed = _activeShrine();
    for (var stage = 0; stage < 5; stage++) {
      completed = _place(
        completed,
        stageIndex: stage,
        content: 'Earlier reference scene ${stage + 1}.',
      );
    }
    completed = completed.completeWalk(
      now: DateTime.utc(2026, 1, 30),
      outcomes: const <String>[
        'recalled',
        'recalled',
        'recalled',
        'recalled',
        'recalled',
      ],
    );
    var shrine = completed.beginCycle(
      cycleId: 'cycle-2',
      anchorDate: DateTime(2026, 2, 1),
      flowId: 92,
    );
    for (var stage = 0; stage < 3; stage++) {
      shrine = _place(
        shrine,
        stageIndex: stage,
        content: 'Reference scene ${stage + 1}.',
      );
    }
    final repository = MemoryKarRepository(
      initial: <KarNetjer, KarShrine>{KarNetjer.djehuty: shrine},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: buildMaatFlowsListPreviewForTesting(
          joinedKeys: const <String>{kKarFlowKey},
          karRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final card = find.byKey(
      const ValueKey<String>('maat-flow-discovery-card-the-kar'),
    );
    await tester.scrollUntilVisible(
      card,
      460,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tapAt(tester.getTopLeft(card) + const Offset(20, 20));
    await tester.pumpAndSettle();
    final detailContext = tester.element(find.byType(KarDetailSurface));
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/the_kar/hero.png'),
        detailContext,
      );
      for (final netjer in KarNetjer.values) {
        await precacheImage(AssetImage(netjer.asset), detailContext);
      }
    });
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('kar-hero-layer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('kar-shared-sheet')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('kar-back')), findsOneWidget);
    if (_captureKarVisuals) {
      await expectLater(
        find.byKey(const ValueKey<String>('kar-detail-surface')),
        matchesGoldenFile('/tmp/kar-detail-flutter.png'),
      );
    }
  });
}

KarShrine _activeShrine() => KarShrine(
  id: 'kar-user-djehuty',
  netjer: KarNetjer.djehuty,
  revision: 0,
  cycles: const <KarCycle>[],
).beginCycle(cycleId: 'cycle-1', anchorDate: DateTime(2026, 9, 10), flowId: 91);

KarShrine _place(
  KarShrine shrine, {
  required int stageIndex,
  required String content,
}) {
  final cycle = shrine.activeCycle!;
  return shrine
      .saveDraft(
        cycleId: cycle.id,
        stageIndex: stageIndex,
        draft: KarDraft(
          kind: 'description',
          content: content,
          savedAt: DateTime.utc(2026, 9, 10),
        ),
      )
      .placeDraft(
        cycleId: cycle.id,
        stageIndex: stageIndex,
        versionId: 'entry-${cycle.id}-$stageIndex',
        now: DateTime.utc(2026, 9, 10, 12),
      );
}

Future<void> _pumpDetail(
  WidgetTester tester,
  MemoryKarRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: KarDetailSurface(
          repository: repository,
          onJoin:
              ({
                required netjer,
                required cycleId,
                required cycleSequence,
                required startDate,
              }) async => 91,
          clock: () => DateTime(2026, 9, 10),
        ),
      ),
    ),
  );
  await tester.pump();
  final context = tester.element(find.byType(KarDetailSurface));
  await tester.runAsync(() async {
    await precacheImage(const AssetImage('assets/the_kar/hero.png'), context);
    for (final netjer in KarNetjer.values) {
      await precacheImage(AssetImage(netjer.asset), context);
    }
  });
  await tester.pumpAndSettle();
}

Future<void> _pumpDay(
  WidgetTester tester, {
  required MemoryKarRepository repository,
  required int flowId,
  required int stageIndex,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: KarDayBehaviorSurface(
          repository: repository,
          netjer: KarNetjer.djehuty,
          flowId: flowId,
          stageIndex: stageIndex,
          clock: () => DateTime(2026, 10, 9),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    360,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void _setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
