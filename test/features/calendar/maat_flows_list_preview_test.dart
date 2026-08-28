import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';

void main() {
  setUp(EndFlowVisibilityStore.instance.debugReset);
  tearDown(() {
    EndFlowVisibilityStore.instance.debugReset();
    resetMaatFlowJoinedStateForTesting();
  });

  test(
    'Ma’at joined accounting recognizes active Follow the sky rows by name',
    () {
      expect(
        maatFlowTemplateMatchesActiveFlowForTesting(
          templateKey: 'track-the-sky',
          flowName: 'Follow the sky',
        ),
        isTrue,
      );
      expect(
        maatFlowTemplateMatchesActiveFlowForTesting(
          templateKey: 'track-the-sky',
          flowName: 'Follow the sky',
          active: false,
        ),
        isFalse,
      );
      expect(
        maatFlowTemplateMatchesActiveFlowForTesting(
          templateKey: 'track-the-sky',
          flowName: 'Follow the sky',
          isHidden: true,
        ),
        isFalse,
      );
    },
  );

  test('Ma’at joined accounting keeps explicit metadata authoritative', () {
    expect(
      maatFlowTemplateMatchesActiveFlowForTesting(
        templateKey: 'track-the-sky',
        flowName: 'Follow the sky',
        flowNotes: 'maat=the-weighing',
      ),
      isFalse,
    );
    expect(
      maatFlowTemplateMatchesActiveFlowForTesting(
        templateKey: 'the-weighing',
        flowName: 'Follow the sky',
        flowNotes: 'maat=the-weighing',
      ),
      isTrue,
    );
  });

  test('ended filing rows do not keep Ma’at templates joined', () {
    expect(
      maatFlowFilingSnapshotMarksInstanceActiveForTesting(
        visibleInActiveList: false,
      ),
      isFalse,
    );
    expect(
      maatFlowFilingSnapshotMarksInstanceActiveForTesting(
        visibleInActiveList: true,
      ),
      isTrue,
    );
  });

  test('Ma’at joined accounting always applies the visibility overlay', () {
    EndFlowVisibilityStore.instance.markPending(1);
    expect(
      maatFlowFilingSnapshotMarksInstanceActiveForTesting(
        visibleInActiveList: true,
      ),
      isFalse,
    );

    EndFlowVisibilityStore.instance.removePending(1);
    expect(
      maatFlowFilingSnapshotMarksInstanceActiveForTesting(
        visibleInActiveList: true,
      ),
      isTrue,
    );

    EndFlowVisibilityStore.instance.markCommitted(1);
    expect(
      maatFlowFilingSnapshotMarksInstanceActiveForTesting(
        visibleInActiveList: true,
      ),
      isFalse,
    );
  });

  testWidgets('Ma’at product catalog renders exactly the 13 core templates', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 16000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const expectedTitles = <String, String>{
      'track-the-sky': 'Follow the Sky',
      'dawn-house-rite': 'Dawn House Rite',
      'evening-threshold-rite': 'The Closing',
      'the-offering-table': 'The Offering Table',
      'the-weighing': 'The Weighing',
      'the-kept-word': 'The Kept Word',
      'the-djed': 'The Djed',
      'the-tending': 'The Tending',
      'the-first-arrangement': 'The First Arrangement',
      'the-clearing': 'The Clearing',
      'the-reading-house': 'The Reading House',
      'the-wag': 'The Wag',
      'the-days-outside-the-year': 'The Days Outside the Year',
    };

    expect(knownMaatFlowTemplateKeysForTesting(), hasLength(33));
    expect(
      coreMaatFlowTemplateKeysForTesting().toSet(),
      expectedTitles.keys.toSet(),
    );
    expect(coreMaatFlowTemplateTitlesForTesting(), expectedTitles);
    expect(knownMaatFlowCategoryForTesting('the-moon-return'), isNotNull);
    expect(knownMaatFlowCategoryForTesting('the-course'), isNotNull);
    expect(knownMaatFlowCategoryForTesting('the-decan-watch'), isNotNull);

    await tester.pumpWidget(
      MaterialApp(home: buildMaatFlowsListPreviewForTesting()),
    );
    await tester.pump();

    for (final key in expectedTitles.keys) {
      expect(
        find.byKey(maatFlowCatalogCardKeyForTesting(key)),
        findsOneWidget,
        reason: key,
      );
    }
    for (final key in <String>[
      'the-course',
      'the-moon-return',
      'the-decan-watch',
      'the-open-hand',
      'evening_threshold',
    ]) {
      expect(
        find.byKey(maatFlowCatalogCardKeyForTesting(key)),
        findsNothing,
        reason: key,
      );
    }
    expect(find.byKey(kMaatFlowCategoryDailyRhythmTabKey), findsOneWidget);
    expect(find.byKey(kMaatFlowCategoryInnerWorkTabKey), findsOneWidget);
    expect(find.byKey(kMaatFlowCategoryLivingInMaatTabKey), findsOneWidget);
  });

  testWidgets('Ma’at flows list groups joined flows above waiting flows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(786, 1566);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: buildMaatFlowsListPreviewForTesting(
          joinedKeys: const <String>{'the-weighing', 'track-the-sky'},
          completionCounts: const <String, (int total, int remaining)>{
            'the-weighing': (12, 7),
            'track-the-sky': (10, 4),
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final exception = tester.takeException();
    if (exception is FlutterError) {
      for (final diagnostic in exception.diagnostics) {
        debugPrint(diagnostic.toStringDeep());
      }
    }
    expect(exception, isNull);
    expect(find.text("Ma'at Flows"), findsOneWidget);
    expect(find.text('NOT YET JOINED'), findsOneWidget);
    expect(find.text('DAILY RHYTHM'), findsOneWidget);
    expect(find.text('INNER WORK'), findsOneWidget);
    expect(find.text("LIVING IN MA'AT"), findsOneWidget);
    expect(find.text('5 of 12'), findsOneWidget);
    expect(find.text('6 of 10'), findsOneWidget);
    expect(find.text('3 of 10'), findsNothing);
    expect(find.text('30%'), findsNothing);
    expect(find.text('The Weighing'), findsOneWidget);
    expect(find.text('Follow the Sky'), findsOneWidget);
    expect(find.text('Dawn House Rite'), findsOneWidget);
  });

  testWidgets(
    'Ma’at flow cards show the complete description and grow when it wraps',
    (tester) async {
      const description =
          'Major turnings in the sky carry a meaning. Attach your own intention to that meaning.';
      tester.view.physicalSize = const Size(760, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: buildMaatFlowsListPreviewForTesting(
            joinedKeys: const <String>{'track-the-sky'},
          ),
        ),
      );
      await tester.pump();

      final descriptionFinder = find.text(description);
      expect(descriptionFinder, findsOneWidget);
      final descriptionText = tester.widget<Text>(descriptionFinder);
      expect(descriptionText.maxLines, isNull);
      expect(descriptionText.overflow, isNull);

      final cardFinder = find
          .ancestor(of: descriptionFinder, matching: find.byType(InkWell))
          .first;
      final wideCardHeight = tester.getSize(cardFinder).height;

      tester.view.physicalSize = const Size(393, 1000);
      await tester.pump();

      expect(find.text(description), findsOneWidget);
      final narrowCardHeight = tester.getSize(cardFinder).height;
      expect(narrowCardHeight, greaterThan(wideCardHeight));
    },
  );

  testWidgets('Ma’at not-yet-joined category tabs filter and toggle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: buildMaatFlowsListPreviewForTesting(),
      ),
    );
    await tester.pump();

    expect(find.text('Dawn House Rite'), findsOneWidget);
    expect(find.text('Follow the Sky'), findsOneWidget);
    expect(find.text('The Weighing'), findsOneWidget);

    await tester.tap(find.byKey(kMaatFlowCategoryInnerWorkTabKey));
    await tester.pumpAndSettle();

    expect(find.text('The Weighing'), findsOneWidget);
    expect(find.text('Dawn House Rite'), findsNothing);
    expect(find.text('Follow the Sky'), findsNothing);

    await tester.tap(find.byKey(kMaatFlowCategoryInnerWorkTabKey));
    await tester.pumpAndSettle();

    expect(find.text('Dawn House Rite'), findsOneWidget);
    expect(find.text('Follow the Sky'), findsOneWidget);
    expect(find.text('The Weighing'), findsOneWidget);
  });

  testWidgets(
    'Ma’at joined card without counts shows active, not fake progress',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: buildMaatFlowsListPreviewForTesting(
            joinedKeys: const <String>{'the-weighing', 'track-the-sky'},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('active'), findsWidgets);
      expect(find.text('3 of 10'), findsNothing);
      expect(find.text('30%'), findsNothing);
    },
  );

  testWidgets('Ma’at flows back button delegates to route close handler', (
    tester,
  ) async {
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: buildMaatFlowsListPreviewForTesting(
          onClose: () {
            closed = true;
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();

    expect(closed, isTrue);
  });

  testWidgets('Ma’at flows back button pops the nested Flow Studio route', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Navigator(
          key: navigatorKey,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const Center(child: Text('Flow Studio hub')),
          ),
        ),
      ),
    );
    await tester.pump();

    unawaited(
      navigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => buildMaatFlowsListPreviewForTesting(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text("Ma'at Flows"), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Flow Studio hub'), findsOneWidget);
    expect(find.text("Ma'at Flows"), findsNothing);
  });

  testWidgets(
    'Ma’at flows back button closes the sheet when it is the first nested route',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    useRootNavigator: true,
                    isScrollControlled: true,
                    builder: (_) => SizedBox(
                      height: 700,
                      child: Navigator(
                        onGenerateRoute: (_) => MaterialPageRoute<void>(
                          builder: (_) => buildMaatFlowsListPreviewForTesting(),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open Ma’at flows'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open Ma’at flows'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("Ma'at Flows"), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("Ma'at Flows"), findsNothing);
      expect(find.text('Open Ma’at flows'), findsOneWidget);
    },
  );

  testWidgets('Ma’at flows plus button delegates to create flow handler', (
    tester,
  ) async {
    var createCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: buildMaatFlowsListPreviewForTesting(
          onCreateNew: () {
            createCount += 1;
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('New flow'));
    await tester.pump();

    expect(createCount, 1);
  });

  testWidgets('The Weighing detail lays out its overview body', (tester) async {
    tester.view.physicalSize = const Size(768, 1536);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: buildMaatFlowTemplateDetailPreviewForTesting(),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Sit with what is true.'), findsOneWidget);
    expect(find.text('THREE-DECAN ARC'), findsOneWidget);
    expect(find.text('Join Flow'), findsOneWidget);
  });

  testWidgets(
    'active template detail reflects joined state and disables join',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: buildMaatFlowTemplateDetailPreviewForTesting(
            templateKey: 'the-course',
            joinedStartDate: DateTime(2026, 9, 1),
          ),
        ),
      );

      expect(find.text('Joined'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Joined'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNull);
    },
  );

  testWidgets(
    'The Course ignores a second join tap while the first is pending',
    (tester) async {
      final pendingJoin = Completer<int>();
      var joinCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: buildMaatFlowTemplateDetailPreviewForTesting(
            templateKey: 'the-course',
            onJoin: () {
              joinCalls += 1;
              return pendingJoin.future;
            },
          ),
        ),
      );

      final joinButton = find.text('Join Flow');
      await tester.tap(joinButton);
      await tester.tap(joinButton);
      await tester.pump();

      expect(joinCalls, 1);
      expect(find.text('Joining…'), findsOneWidget);
    },
  );

  testWidgets(
    'join result does not impersonate the persisted active instance',
    (tester) async {
      Future<int?> joinTemplate(String key) async {
        return key == 'dawn-house-rite' ? 441 : null;
      }

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: buildMaatFlowsListPreviewForTesting(
            onPickTemplate: joinTemplate,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('active'), findsNothing);
      await tester.tap(find.text('Dawn House Rite'));
      await tester.pumpAndSettle();
      expect(find.text('active'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: buildMaatFlowsListPreviewForTesting(
            joinedKeys: const <String>{'dawn-house-rite'},
            onPickTemplate: joinTemplate,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('active'), findsOneWidget);
      expect(find.text('NOT YET JOINED'), findsOneWidget);
    },
  );
}
